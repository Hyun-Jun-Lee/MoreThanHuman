"""BILLING_TEST_POSTGRES_URL은 버려도 되는 격리 테스트 DB만 지정해요."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import os
from threading import Barrier
from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel
from domains.conversation.repository import ConversationRepository, ConversationSlotsFull
from domains.grammar import models as grammar_models
from domains.language_snacks import models as snack_models  # noqa: F401
from shared.billing_models import TurnReservationModel, CreditLotModel, PurchaseDeliveryModel
from shared.credit_ledger import CreditLedger, CreditsExhausted
from domains.billing.service import BillingService


@pytest.fixture
def pg():
    url = os.getenv('BILLING_TEST_POSTGRES_URL')
    if not url:
        pytest.skip('isolated PostgreSQL not configured')
    schema = 'billing_test_' + uuid4().hex
    admin = create_engine(url)
    with admin.begin() as connection:
        connection.execute(text(f'CREATE SCHEMA {schema}'))
    engine = create_engine(url, connect_args={'options': f'-csearch_path={schema}'})
    Base.metadata.create_all(engine)
    user_id = str(uuid4())
    with Session(engine) as db:
        db.add(ProfileModel(id=user_id, name='Test'))
        db.commit()
    yield engine, user_id
    engine.dispose()
    with admin.begin() as connection:
        connection.execute(text(f'DROP SCHEMA {schema} CASCADE'))
    admin.dispose()


def race(operation):
    barrier = Barrier(2)
    def run(index):
        barrier.wait(timeout=5)
        return operation(index)
    with ThreadPoolExecutor(max_workers=2) as pool:
        return list(pool.map(run, range(2)))


def test_last_credit_has_one_winner(pg):
    engine, user_id = pg
    with Session(engine) as db:
        ledger = CreditLedger(db)
        profile = ledger.lock(user_id)
        ledger.ensure_trial(profile).revoked_at = datetime.utcnow()
        ledger.grant_turns(profile, 1, source='manual', source_key='one')
        db.commit()
    def operation(index):
        with Session(engine) as db:
            ledger = CreditLedger(db)
            try:
                ledger.reserve(ledger.lock(user_id), str(index))
                db.commit()
                return 'won'
            except CreditsExhausted:
                db.rollback()
                return 'empty'
    assert sorted(race(operation)) == ['empty', 'won']
    with Session(engine) as db:
        assert db.query(TurnReservationModel).filter_by(status='reserved').count() == 1


def test_last_slot_has_one_winner(pg):
    engine, user_id = pg
    def operation(index):
        with Session(engine) as db:
            try:
                ConversationRepository(db).create_with_access(
                    ConversationModel(id=str(uuid4()), user_id=user_id), enabled=True)
                return 'won'
            except ConversationSlotsFull:
                return 'full'
    assert sorted(race(operation)) == ['full', 'won']


def test_duplicate_purchase_has_one_delivery(pg):
    engine, user_id = pg
    tx = SimpleNamespace(transactionId='one', productId='com.morethanhuman.curitalk.turns.5',
                         appAccountToken=user_id, environment='Sandbox', revocationDate=None)
    gateway = SimpleNamespace(decode_transaction=lambda _: tx)
    def operation(index):
        with Session(engine) as db:
            return BillingService(db, gateway).verify_purchase(user_id, 'signed')['remaining_turns']
    assert race(operation) == [15, 15]
    with Session(engine) as db:
        assert db.query(PurchaseDeliveryModel).count() == 1
        assert db.query(CreditLotModel).filter_by(source='apple').count() == 1


@pytest.mark.parametrize('outcome', ['commit', 'release'])
def test_refund_racing_with_reserved_turn(pg, outcome):
    engine, user_id = pg
    with Session(engine) as db:
        ledger = CreditLedger(db)
        profile = ledger.lock(user_id)
        ledger.ensure_trial(profile).revoked_at = datetime.utcnow()
        ledger.grant_turns(profile, 5, source='apple', source_key='one')
        ledger.reserve(profile, 'message')
        db.commit()
    def operation(index):
        with Session(engine) as db:
            ledger = CreditLedger(db)
            profile = ledger.lock(user_id)
            if index == 0:
                ledger.revoke_lot(profile, db.query(CreditLotModel).filter_by(source='apple').one())
            else:
                getattr(ledger, outcome)(user_id, 'message')
            db.commit()
    race(operation)
    with Session(engine) as db:
        ledger = CreditLedger(db)
        assert ledger.balance(ledger.lock(user_id))['remaining_turns'] == 0
        row = db.query(TurnReservationModel).one()
        assert row.status == 'committed' if outcome == 'commit' else row.status in {'released', 'revoked'}

def test_purchase_racing_account_deletion_cannot_survive_or_replay(pg):
    from domains.auth.deletion import AccountDeletionService
    from shared.billing_tombstones import find_tombstone

    engine, user_id = pg
    tx = SimpleNamespace(transactionId='deletion-race', productId='com.morethanhuman.curitalk.turns.5',
                         appAccountToken=user_id, environment='Sandbox', revocationDate=None)
    gateway = SimpleNamespace(decode_transaction=lambda _: tx)
    def operation(index):
        with Session(engine) as db:
            if index == 0:
                return BillingService(db, gateway).verify_purchase(user_id, 'signed')['terminal']
            deletion = AccountDeletionService(db, None)
            deletion.start(user_id)
            deletion._purge_profile(user_id)
            return True

    assert race(operation) == [True, True]
    with Session(engine) as db:
        assert db.get(ProfileModel, user_id) is None
        assert db.query(PurchaseDeliveryModel).count() == 0
        assert db.query(CreditLotModel).count() == 0
        assert find_tombstone(db, 'account', user_id)
        assert BillingService(db, gateway).terminalize_purchase('signed')['delivery_status'] == 'deleted'


def test_slot_refund_racing_first_text_is_serialized(pg):
    engine, user_id = pg
    with Session(engine) as db:
        ledger = CreditLedger(db)
        profile = ledger.lock(user_id)
        db.add(PurchaseDeliveryModel(transaction_id='slot-race', user_id=user_id,
            product_id='com.morethanhuman.curitalk.slots.plus.1', environment='Sandbox',
            resource_kind='slots', quantity=1, status='granted'))
        ledger.reserve(profile, 'message')
        db.commit()

    def operation(index):
        with Session(engine) as db:
            ledger = CreditLedger(db)
            ledger.lock(user_id)
            if index == 0:
                db.get(PurchaseDeliveryModel, 'slot-race').status = 'revoked'
            else:
                ledger.commit(user_id, 'message')
            db.commit()
    race(operation)
    with Session(engine) as db:
        ledger = CreditLedger(db)
        balance = ledger.balance(ledger.lock(user_id))
        assert balance['slot_limit'] == 1
        assert balance['remaining_turns'] == 9
        assert db.get(PurchaseDeliveryModel, 'slot-race').status == 'revoked'

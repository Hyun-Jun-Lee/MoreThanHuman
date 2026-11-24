from types import SimpleNamespace
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation import models
from domains.grammar import models as grammar_models
from domains.billing.service import BillingService, PurchaseOwnedByAnotherAccount
from domains.billing.apple import PRODUCTS
from shared.billing_models import CreditLotModel, PurchaseDeliveryModel, PurchaseNotificationModel
from shared.billing_tombstones import remember, find_tombstone
from shared.credit_ledger import CreditLedger


@pytest.fixture
def setup():
    engine = create_engine('sqlite://')
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        user = ProfileModel(id=str(uuid4()), name='Member')
        db.add(user)
        db.commit()
        tx = SimpleNamespace(transactionId='one', appAccountToken=user.id, quantity=1,
            productId='com.morethanhuman.curitalk.turns.5', environment='Sandbox', revocationDate=None)
        notification = SimpleNamespace(notificationUUID='notice', notificationType='REFUND',
                                       data=SimpleNamespace(signedTransactionInfo='jws'))
        gateway = SimpleNamespace(decode_transaction=lambda _: tx, decode_notification=lambda _: notification)
        yield db, user, tx, notification, BillingService(db, gateway)
    engine.dispose()


@pytest.mark.parametrize('sku,expected', list(PRODUCTS.items()))
def test_repeat_and_duplicate_delivery(setup, sku, expected):
    db, user, tx, _, service = setup
    tx.productId = sku
    first = service.verify_purchase(user.id, 'jws')
    second = service.verify_purchase(user.id, 'jws')
    assert first == second
    tx.transactionId = 'two'
    result = service.verify_purchase(user.id, 'jws')
    resource, amount = expected
    assert result['slot_limit'] == (1 + 2 * amount if resource == 'slots' else 1)
    assert result['remaining_turns'] == (10 + 2 * amount if resource == 'turns' else 10)
    assert db.query(PurchaseDeliveryModel).count() == 2


def test_refund_before_delivery_and_duplicate_notification(setup):
    db, user, tx, notice, service = setup
    service.process_notification('notice')
    service.process_notification('notice')
    assert service.verify_purchase(user.id, 'jws')['remaining_turns'] == 10
    assert db.query(PurchaseDeliveryModel).one().status == 'refund-before-delivery'
    assert db.query(PurchaseNotificationModel).count() == 1


def test_refund_revokes_only_remaining_credit(setup):
    db, user, tx, _, service = setup
    service.verify_purchase(user.id, 'jws')
    ledger = CreditLedger(db)
    ledger.ensure_trial(user).revoked_at = __import__('datetime').datetime.utcnow()
    ledger.reserve(user, 'first')
    ledger.commit(user.id, 'first')
    db.commit()
    service.process_notification('notice')
    assert service.entitlement(user.id)['remaining_turns'] == 0
    assert db.query(PurchaseDeliveryModel).one().status == 'revoked'


def test_account_conflict_keeps_original_owner(setup):
    db, user, tx, _, service = setup
    other = ProfileModel(id=str(uuid4()), name='Other')
    db.add(other)
    db.commit()
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.verify_purchase(other.id, 'jws')
    assert db.query(PurchaseDeliveryModel).count() == 0
    assert service.verify_purchase(user.id, 'jws')['remaining_turns'] == 15


def test_deleted_account_terminal_without_bearer_and_replay_after_rotation(setup, monkeypatch):
    db, user, tx, _, service = setup
    remember(db, 'account', user.id, 'deleted')
    db.commit()
    assert service.terminalize_purchase('jws') == {'delivery_status': 'deleted', 'terminal': True}
    assert service.verify_purchase(str(uuid4()), 'jws')['terminal']
    assert db.query(PurchaseDeliveryModel).count() == 0
    from config import get_settings
    settings = get_settings()
    monkeypatch.setattr(settings, 'billing_hmac_keys', {**settings.billing_hmac_keys, 'next': 'n' * 32})
    monkeypatch.setattr(settings, 'billing_hmac_current_key', 'next')
    assert find_tombstone(db, 'transaction', tx.transactionId)
    assert service.terminalize_purchase('jws')['terminal']


def test_active_account_cannot_terminalize(setup):
    _, _, _, _, service = setup
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.terminalize_purchase('jws')


def test_consumption_request_is_audit_only(setup):
    db, user, _, notice, service = setup
    notice.notificationType = 'CONSUMPTION_REQUEST'
    service.process_notification('notice')
    assert db.query(PurchaseDeliveryModel).count() == 0
    assert db.query(CreditLotModel).count() == 0
    assert db.query(PurchaseNotificationModel).one().notification_type == 'CONSUMPTION_REQUEST'

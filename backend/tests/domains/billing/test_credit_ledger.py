from datetime import datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation import models  # noqa: F401
from domains.grammar import models as grammar_models  # noqa: F401
from shared.credit_ledger import CreditLedger, CreditsExhausted
from shared.billing_models import CreditLotModel, PurchaseDeliveryModel, TurnReservationModel


@pytest.fixture
def ledger():
    engine = create_engine('sqlite:///:memory:')
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        profile = ProfileModel(id=str(uuid4()), name='Learner')
        db.add(profile)
        db.commit()
        yield CreditLedger(db), profile
    engine.dispose()


def test_trial_issued_once_and_exhausted_across_conversations(ledger):
    service, profile = ledger
    for index in range(10):
        service.ensure_trial(profile)
        service.reserve(profile, str(index))
        service.commit(profile.id, str(index))
    assert service.balance(profile)['remaining_turns'] == 0
    assert service.db.query(CreditLotModel).count() == 1
    with pytest.raises(CreditsExhausted):
        service.reserve(profile, 'eleven')


def test_release_retry_and_duplicate_commit(ledger):
    service, profile = ledger
    service.reserve(profile, 'message')
    assert service.balance(profile)['remaining_turns'] == 9
    service.release(profile.id, 'message')
    assert service.balance(profile)['remaining_turns'] == 10
    service.reserve(profile, 'message')
    service.commit(profile.id, 'message')
    service.commit(profile.id, 'message')
    assert service.balance(profile)['remaining_turns'] == 9


def test_refund_reserved_credit_commits_or_revokes_without_return(ledger):
    service, profile = ledger
    service.ensure_trial(profile).revoked_at = datetime.utcnow()
    lot = service.grant_turns(profile, 5, source='apple', source_key='tx')
    service.reserve(profile, 'success')
    service.reserve(profile, 'failure')
    service.revoke_lot(profile, lot)
    service.commit(profile.id, 'success')
    service.release(profile.id, 'failure')
    assert service.balance(profile)['remaining_turns'] == 0
    assert [r.status for r in service.db.query(TurnReservationModel).order_by(TurnReservationModel.request_key)] == ['revoked', 'committed']


def test_expiry_returns_credit_but_late_completion_is_rejected(ledger):
    service, profile = ledger
    reservation = service.reserve(profile, 'message')
    reservation.deadline_at = datetime.utcnow() - timedelta(seconds=1)
    assert service.balance(profile)['remaining_turns'] == 10
    with pytest.raises(ValueError):
        service.commit(profile.id, 'message')


def test_first_text_marks_all_previously_granted_slots_once(ledger):
    service, profile = ledger
    for tx in ['one', 'two']:
        service.db.add(PurchaseDeliveryModel(transaction_id=tx, user_id=profile.id,
            product_id='slots', environment='Sandbox', resource_kind='slots', quantity=1, status='granted'))
    service.reserve(profile, 'message')
    service.commit(profile.id, 'message')
    rows = service.db.query(PurchaseDeliveryModel).all()
    assert all(row.first_used_at for row in rows)
    first = rows[0].first_used_at
    service.reserve(profile, 'next')
    service.commit(profile.id, 'next')
    assert rows[0].first_used_at == first


def test_guest_and_admin_receive_no_trial(ledger):
    service, profile = ledger
    profile.is_guest = True
    assert service.ensure_trial(profile) is None
    profile.is_guest = False
    profile.is_admin = True
    assert service.ensure_trial(profile) is None
    assert service.balance(profile)['remaining_turns'] is None

def test_trial_is_spent_before_paid_lots_in_fifo_order(ledger):
    service, profile = ledger
    older = service.grant_turns(profile, 1, source='apple', source_key='older')
    newer = service.grant_turns(profile, 1, source='manual', source_key='newer')
    trial = service.ensure_trial(profile)
    for index in range(12):
        reservation = service.reserve(profile, str(index))
        assert reservation.lot_id == (trial.id if index < 10 else older.id if index == 10 else newer.id)
        service.commit(profile.id, str(index))


def test_retained_tombstone_keys_cannot_be_removed(ledger, monkeypatch):
    from shared.billing_tombstones import remember, validate_key_versions, TombstoneKeysMissing
    from config import get_settings
    service, profile = ledger
    remember(service.db, 'user', profile.id, 'deleted')
    service.db.commit()
    settings = get_settings()
    monkeypatch.setattr(settings, 'billing_hmac_keys', {'new': 'new-independent-key-with-at-least-32-bytes'})
    monkeypatch.setattr(settings, 'billing_hmac_current_key', 'new')
    with pytest.raises(TombstoneKeysMissing):
        validate_key_versions(service.db)

from uuid import uuid4
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from database import Base
from domains.auth.models import ProfileModel
from domains.conversation import models
from domains.grammar import models as grammar_models
from domains.admin.service import AdminEntitlementService
from shared.billing_models import ManualResourceGrantModel
from shared.credit_ledger import CreditLedger


@pytest.fixture
def setup():
    engine = create_engine('sqlite://')
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        user = ProfileModel(id=str(uuid4()), name='Member')
        db.add(user)
        db.commit()
        yield db, user, AdminEntitlementService(db)
    engine.dispose()


def test_manual_grants_are_independent_idempotent_and_revocable(setup):
    db, user, service = setup
    slots, turns = str(uuid4()), str(uuid4())
    service.put_manual(user.id, slots, 'slots', 3)
    service.put_manual(user.id, slots, 'slots', 3)
    result = service.put_manual(user.id, turns, 'turns', 5)
    assert result['effective']['slot_limit'] == 4
    assert result['effective']['remaining_turns'] == 15
    assert db.query(ManualResourceGrantModel).count() == 2
    with pytest.raises(ValueError):
        service.put_manual(user.id, slots, 'turns', 5)
    service.delete_manual(user.id, slots)
    result = service.delete_manual(user.id, turns)
    assert result['effective']['slot_limit'] == 1
    assert result['effective']['remaining_turns'] == 10
    assert all(g['revoked_at'] for g in service.history(user.id, limit=20, offset=0)['results'])


def test_admin_unlimited_and_guest_cannot_receive_grants(setup):
    db, user, service = setup
    user.is_admin = True
    db.commit()
    assert service.entitlement_detail(user)['effective']['remaining_turns'] is None
    with pytest.raises(ValueError):
        service.put_manual(user.id, str(uuid4()), 'turns', 5)
    user.is_admin = False
    user.is_guest = True
    db.commit()
    with pytest.raises(ValueError):
        service.put_manual(user.id, str(uuid4()), 'slots', 1)


def test_user_search_and_bad_quantities(setup):
    _, user, service = setup
    assert service.list_users(q=user.id, is_admin=None, limit=20, offset=0)['total_count'] == 1
    with pytest.raises(ValueError):
        service.put_manual(user.id, str(uuid4()), 'turns', -1)

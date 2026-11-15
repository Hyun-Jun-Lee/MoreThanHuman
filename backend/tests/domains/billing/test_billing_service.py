from datetime import datetime, timedelta
from dataclasses import replace
from uuid import uuid4
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import AccountDeletionModel, ProfileModel
from domains.conversation.enums import ConversationType
from domains.conversation.models import ConversationModel
from domains.billing.apple import VerifiedSubscription
from domains.billing.service import BillingService, PurchaseOwnedByAnotherAccount
from shared.subscription import AppleSubscriptionModel, entitlement_for_user


class FakeGateway:
    def __init__(self, purchase):
        self.purchase = purchase
        self.calls = 0
        self.supplied_original = None
        self.rebindings = []

    def set_app_account_token(self, original, user_id):
        self.rebindings.append((original, user_id))

    def decode_transaction(self, _signed):
        return SimpleNamespace(
            originalTransactionId=self.supplied_original or self.purchase.original_transaction_id,
            appAccountToken=self.purchase.app_account_token,
        )

    def current_subscription(self, _original):
        self.calls += 1
        return self.purchase

    def decode_notification(self, _signed):
        return SimpleNamespace(
            notificationUUID="one-notification",
            data=SimpleNamespace(signedTransactionInfo="signed-transaction"),
        )


def _db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    ids = [str(uuid4()), str(uuid4())]
    db.add_all(ProfileModel(id=value, email=f"{value}@example.com", name="Learner") for value in ids)
    db.commit()
    return db, ids


def _purchase(user_id, product="Advance", status="active", expiry=None):
    return VerifiedSubscription(
        original_transaction_id="100000001",
        transaction_id="100000002",
        app_account_token=user_id,
        product_id=product,
        environment="Sandbox",
        status=status,
        expires_at=expiry or datetime.utcnow() + timedelta(days=20),
        grace_expires_at=None,
    )


@pytest.fixture
def enabled_access(monkeypatch):
    monkeypatch.setattr("domains.billing.service.get_settings", lambda: SimpleNamespace(
        conversation_access_enabled=True,
    ))


def _add_conversations(db, user_id, count):
    conversations = [ConversationModel(
        id=str(uuid4()), user_id=user_id, conversation_type=ConversationType.FREE_CHAT,
        slot_active=index == 0,
    ) for index in range(count)]
    db.add_all(conversations)
    db.get(ProfileModel, user_id).slot_limit_snapshot = 1
    db.commit()
    return conversations


def _active_count(db, user_id):
    return db.query(ConversationModel).filter_by(user_id=user_id, slot_active=True).count()


def test_purchase_grants_only_verified_current_plan_and_is_idempotent():
    db, (owner, _) = _db()
    gateway = FakeGateway(_purchase(owner))
    service = BillingService(db, gateway)
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 5
    gateway.purchase = _purchase(owner, product="Plus")
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 10
    assert db.query(AppleSubscriptionModel).count() == 1
    assert db.get(ProfileModel, owner).slot_limit_snapshot is None


def test_purchase_reconciles_slots_on_upgrade_and_revocation(enabled_access):
    db, (owner, _) = _db()
    _add_conversations(db, owner, 3)
    gateway = FakeGateway(_purchase(owner))
    service = BillingService(db, gateway)

    service.verify_purchase(owner, "signed")
    assert _active_count(db, owner) == 3
    assert db.get(ProfileModel, owner).slot_limit_snapshot == 5

    gateway.purchase = replace(gateway.purchase, status="revoked")
    service.verify_purchase(owner, "signed")
    assert _active_count(db, owner) == 1
    assert db.get(ProfileModel, owner).slot_limit_snapshot == 1


def test_purchase_and_slot_changes_roll_back_together(enabled_access, monkeypatch):
    db, (owner, _) = _db()
    _add_conversations(db, owner, 2)
    service = BillingService(db, FakeGateway(_purchase(owner)))

    def fail_reconciliation(_repository, _profile):
        raise RuntimeError("slot reconciliation failed")

    monkeypatch.setattr("domains.conversation.repository.ConversationRepository._reconcile_slots_locked",
                        fail_reconciliation)
    with pytest.raises(RuntimeError, match="slot reconciliation failed"):
        service.verify_purchase(owner, "signed")
    assert db.query(AppleSubscriptionModel).count() == 0
    assert _active_count(db, owner) == 1
    assert db.get(ProfileModel, owner).slot_limit_snapshot == 1


def test_existing_purchase_cannot_be_restored_to_another_account():
    db, (owner, other) = _db()
    gateway = FakeGateway(_purchase(None))
    service = BillingService(db, gateway)
    service.verify_purchase(owner, "signed")
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.verify_purchase(other, "signed")
    assert db.query(AppleSubscriptionModel).one().user_id == owner


def test_explicit_restore_rebinds_only_deleted_owner_entitlement():
    db, (old_owner, new_owner) = _db()
    gateway = FakeGateway(_purchase(old_owner))
    service = BillingService(db, gateway)
    service.verify_purchase(old_owner, "signed")
    db.add(AccountDeletionModel(user_id=old_owner, receipt_hash="a" * 64,
                                status="completed"))
    db.query(AppleSubscriptionModel).filter_by(user_id=old_owner).delete()
    db.query(ProfileModel).filter_by(id=old_owner).delete()
    db.commit()
    assert service.restore_purchase(new_owner, "signed")["plan"] == "advance"
    assert db.query(AppleSubscriptionModel).one().user_id == new_owner
    assert gateway.rebindings == [("100000001", new_owner)]
    service.process_notification("signed-notification")
    assert db.query(AppleSubscriptionModel).one().user_id == new_owner


def test_restore_reconciles_new_owner_slots(enabled_access):
    db, (old_owner, new_owner) = _db()
    _add_conversations(db, new_owner, 2)
    db.add(AccountDeletionModel(user_id=old_owner, receipt_hash="c" * 64,
                                status="completed"))
    db.commit()
    service = BillingService(db, FakeGateway(_purchase(old_owner)))

    assert service.restore_purchase(new_owner, "signed")["slot_limit"] == 5
    assert _active_count(db, new_owner) == 2
    assert db.get(ProfileModel, new_owner).slot_limit_snapshot == 5


def test_restore_does_not_rebind_if_slot_reconciliation_fails(enabled_access, monkeypatch):
    db, (old_owner, new_owner) = _db()
    _add_conversations(db, new_owner, 2)
    db.add(AccountDeletionModel(user_id=old_owner, receipt_hash="d" * 64,
                                status="completed"))
    db.commit()
    gateway = FakeGateway(_purchase(old_owner))

    def fail_reconciliation(_repository, _profile):
        raise RuntimeError("slot reconciliation failed")

    monkeypatch.setattr("domains.conversation.repository.ConversationRepository._reconcile_slots_locked",
                        fail_reconciliation)
    with pytest.raises(RuntimeError, match="slot reconciliation failed"):
        BillingService(db, gateway).restore_purchase(new_owner, "signed")
    assert db.query(AppleSubscriptionModel).count() == 0
    assert gateway.rebindings == []
    assert _active_count(db, new_owner) == 1


def test_explicit_restore_rejects_active_owner_and_expired_purchase():
    db, (owner, other) = _db()
    gateway = FakeGateway(_purchase(owner))
    service = BillingService(db, gateway)
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.restore_purchase(other, "signed")
    db.add(AccountDeletionModel(user_id=owner, receipt_hash="b" * 64,
                                status="processing"))
    db.commit()
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.restore_purchase(other, "signed")
    gateway.purchase = _purchase(None, expiry=datetime.utcnow() - timedelta(days=1))
    with pytest.raises(ValueError):
        service.restore_purchase(other, "signed")


def test_expired_or_revoked_purchase_does_not_grant_slots():
    db, (owner, _) = _db()
    gateway = FakeGateway(_purchase(owner, expiry=datetime.utcnow() - timedelta(seconds=1)))
    service = BillingService(db, gateway)
    assert service.verify_purchase(owner, "signed")["plan"] == "free"
    gateway.purchase = _purchase(owner, status="revoked")
    service.verify_purchase(owner, "signed")
    assert entitlement_for_user(db, owner)["turn_limit"] == 15


def test_notification_requery_is_idempotent_and_keeps_account_binding():
    db, (owner, _) = _db()
    gateway = FakeGateway(_purchase(owner))
    service = BillingService(db, gateway)
    service.process_notification("signed-notification")
    service.process_notification("signed-notification")
    assert gateway.calls == 1
    assert db.query(AppleSubscriptionModel).one().user_id == owner


def test_group_plan_change_replaces_old_original_transaction_without_double_entitlement(enabled_access):
    db, (owner, other) = _db()
    _add_conversations(db, owner, 6)
    gateway = FakeGateway(_purchase(owner, product="Plus"))
    service = BillingService(db, gateway)
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 10
    assert _active_count(db, owner) == 6
    gateway.supplied_original = "100000001"
    gateway.purchase = VerifiedSubscription(
        original_transaction_id="100000003",
        transaction_id="100000004",
        app_account_token=owner,
        product_id="Advance",
        environment="Sandbox",
        status="active",
        expires_at=datetime.utcnow() + timedelta(days=20),
        grace_expires_at=None,
    )
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 5
    assert _active_count(db, owner) == 5
    assert db.get(ProfileModel, owner).slot_limit_snapshot == 5
    assert db.query(AppleSubscriptionModel).filter_by(original_transaction_id="100000001").one().status == "expired"
    gateway.purchase = replace(gateway.purchase, app_account_token=None)
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.verify_purchase(other, "signed")

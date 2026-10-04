from datetime import datetime, timedelta
from dataclasses import replace
from uuid import uuid4
from types import SimpleNamespace

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel  # noqa: F401 - mapper 등록
from domains.billing.apple import VerifiedSubscription
from domains.billing.service import BillingService, PurchaseOwnedByAnotherAccount
from shared.subscription import AppleSubscriptionModel, entitlement_for_user


class FakeGateway:
    def __init__(self, purchase):
        self.purchase = purchase
        self.calls = 0
        self.supplied_original = None

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


def test_purchase_grants_only_verified_current_plan_and_is_idempotent():
    db, (owner, _) = _db()
    gateway = FakeGateway(_purchase(owner))
    service = BillingService(db, gateway)
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 5
    gateway.purchase = _purchase(owner, product="Plus")
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 10
    assert db.query(AppleSubscriptionModel).count() == 1


def test_existing_purchase_cannot_be_restored_to_another_account():
    db, (owner, other) = _db()
    gateway = FakeGateway(_purchase(None))
    service = BillingService(db, gateway)
    service.verify_purchase(owner, "signed")
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.verify_purchase(other, "signed")
    assert db.query(AppleSubscriptionModel).one().user_id == owner


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


def test_group_plan_change_replaces_old_original_transaction_without_double_entitlement():
    db, (owner, other) = _db()
    gateway = FakeGateway(_purchase(owner, product="Plus"))
    service = BillingService(db, gateway)
    assert service.verify_purchase(owner, "signed")["slot_limit"] == 10
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
    assert db.query(AppleSubscriptionModel).filter_by(original_transaction_id="100000001").one().status == "expired"
    gateway.purchase = replace(gateway.purchase, app_account_token=None)
    with pytest.raises(PurchaseOwnedByAnotherAccount):
        service.verify_purchase(other, "signed")

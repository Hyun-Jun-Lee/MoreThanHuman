"""Apple 구독의 저장 상태와 서버 대화 권한."""
from datetime import datetime

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Index, String
from sqlalchemy.orm import Session

from database import Base
from domains.auth.models import ProfileModel


class AppleSubscriptionModel(Base):
    __tablename__ = "apple_subscriptions"

    original_transaction_id = Column(String(64), primary_key=True)
    user_id = Column(String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    last_transaction_id = Column(String(64), nullable=False)
    product_id = Column(String(32), nullable=False)
    environment = Column(String(16), nullable=False)
    status = Column(String(32), nullable=False)
    expires_at = Column(DateTime, nullable=True)
    grace_expires_at = Column(DateTime, nullable=True)
    verified_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    __table_args__ = (Index("ix_apple_subscriptions_user_status", "user_id", "status"),)


class AppleNotificationModel(Base):
    __tablename__ = "apple_subscription_notifications"

    notification_uuid = Column(String(64), primary_key=True)
    original_transaction_id = Column(String(64), nullable=True)
    received_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class ManualEntitlementGrantModel(Base):
    __tablename__ = "manual_entitlement_grants"

    id = Column(String(36), primary_key=True)
    user_id = Column(String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    plan = Column(String(16), nullable=False)
    revoke_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
    granted_by = Column(String(36), ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True)
    revoked_by = Column(String(36), ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    __table_args__ = (CheckConstraint("plan IN ('advance', 'plus')", name="ck_manual_entitlement_plan"),)


def apple_entitlement_for_user(db: Session, user_id: str, *, now: datetime) -> dict:
    records = db.query(AppleSubscriptionModel).filter_by(user_id=user_id).all()
    return apple_entitlement_from_records(records, now=now)


def apple_entitlement_from_records(records: list[AppleSubscriptionModel], *, now: datetime) -> dict:
    eligible = []
    for record in records:
        if record.status == "active" and record.expires_at and record.expires_at > now:
            eligible.append(record)
        elif record.status == "grace" and record.grace_expires_at and record.grace_expires_at > now:
            eligible.append(record)
    if not eligible:
        return {"plan": "free", "status": "free", "expires_at": None, "slot_limit": 1, "turn_limit": 15}
    record = max(eligible, key=lambda item: (item.product_id == "Plus", item.expires_at or now))
    return {
        "plan": record.product_id.lower(),
        "status": record.status,
        "expires_at": record.grace_expires_at if record.status == "grace" else record.expires_at,
        "slot_limit": 10 if record.product_id == "Plus" else 5,
        "turn_limit": None,
    }


def active_manual_grant(db: Session, user_id: str, *, now: datetime) -> ManualEntitlementGrantModel | None:
    return (db.query(ManualEntitlementGrantModel)
            .filter(ManualEntitlementGrantModel.user_id == user_id,
                    ManualEntitlementGrantModel.revoked_at.is_(None),
                    (ManualEntitlementGrantModel.revoke_at.is_(None) | (ManualEntitlementGrantModel.revoke_at > now)))
            .order_by(ManualEntitlementGrantModel.created_at.desc(), ManualEntitlementGrantModel.id.desc())
            .first())


def entitlement_for_user(
    db: Session, user_id: str, *, now: datetime | None = None, profile: ProfileModel | None = None
) -> dict:
    now = now or datetime.utcnow()
    profile = profile or db.get(ProfileModel, user_id)
    if profile is not None and profile.is_admin:
        return effective_entitlement(profile, None, None)
    apple = apple_entitlement_for_user(db, user_id, now=now)
    grant = active_manual_grant(db, user_id, now=now)
    return effective_entitlement(profile, apple, grant)


def effective_entitlement(
    profile: ProfileModel | None, apple: dict | None, grant: ManualEntitlementGrantModel | None
) -> dict:
    if profile is not None and profile.is_admin:
        return {"plan": "plus", "status": "admin", "expires_at": None,
                "slot_limit": None, "turn_limit": None, "source": "admin",
                "is_admin": True, "unlimited": True}
    assert apple is not None
    rank = {"free": 0, "advance": 1, "plus": 2}
    if grant is not None and rank[grant.plan] > rank[apple["plan"]]:
        return {"plan": grant.plan, "status": "manual", "expires_at": grant.revoke_at,
                "slot_limit": 10 if grant.plan == "plus" else 5, "turn_limit": None,
                "source": "manual", "is_admin": False, "unlimited": False}
    return {**apple, "source": "apple" if apple["plan"] != "free" else "free",
            "is_admin": False, "unlimited": False}

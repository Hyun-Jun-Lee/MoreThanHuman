"""Apple 구독의 저장 상태와 서버 대화 권한."""
from datetime import datetime

from sqlalchemy import Column, DateTime, ForeignKey, Index, String
from sqlalchemy.orm import Session

from database import Base


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


def entitlement_for_user(db: Session, user_id: str, *, now: datetime | None = None) -> dict:
    """검증된 유효 시각만으로 현재 플랜을 판정해요."""
    now = now or datetime.utcnow()
    records = db.query(AppleSubscriptionModel).filter_by(user_id=user_id).all()
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

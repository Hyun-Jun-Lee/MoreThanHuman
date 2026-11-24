"""계정 소유 소비성 구매·턴 원장과 가명 재전송 방지 기록."""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, UniqueConstraint

from database import Base


class PurchaseDeliveryModel(Base):
    __tablename__ = 'purchase_deliveries'
    transaction_id = Column(String(128), primary_key=True)
    user_id = Column(String(36), ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False, index=True)
    product_id = Column(String(128), nullable=False)
    environment = Column(String(16), nullable=False)
    resource_kind = Column(String(16), nullable=False)
    quantity = Column(Integer, nullable=False)
    status = Column(String(32), nullable=False)
    first_used_at = Column(DateTime)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    __table_args__ = (
        CheckConstraint("resource_kind IN ('slots', 'turns')", name='ck_delivery_resource'),
        CheckConstraint('quantity > 0', name='ck_delivery_quantity'),
        CheckConstraint("status IN ('pending', 'granted', 'refund-before-delivery', 'revoked')", name='ck_delivery_status'),
    )


class CreditLotModel(Base):
    __tablename__ = 'credit_lots'
    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String(36), ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False, index=True)
    source = Column(String(16), nullable=False)
    source_key = Column(String(128), nullable=False)
    quantity = Column(Integer, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    revoked_at = Column(DateTime)
    __table_args__ = (
        UniqueConstraint('user_id', 'source', 'source_key', name='uq_credit_source'),
        CheckConstraint("source IN ('trial', 'apple', 'manual')", name='ck_credit_source'),
        CheckConstraint('quantity > 0', name='ck_credit_quantity'),
    )


class TurnReservationModel(Base):
    __tablename__ = 'turn_reservations'
    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id = Column(String(36), ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False, index=True)
    lot_id = Column(String(36), ForeignKey('credit_lots.id', ondelete='CASCADE'), nullable=False, index=True)
    request_key = Column(String(128), nullable=False)
    status = Column(String(16), nullable=False)
    deadline_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    finished_at = Column(DateTime)
    __table_args__ = (
        UniqueConstraint('user_id', 'request_key', name='uq_member_turn_request'),
        CheckConstraint("status IN ('reserved', 'committed', 'released', 'revoked')", name='ck_member_turn_status'),
    )


class ManualResourceGrantModel(Base):
    __tablename__ = 'manual_resource_grants'
    id = Column(String(36), primary_key=True)
    user_id = Column(String(36), ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False, index=True)
    resource_kind = Column(String(16), nullable=False)
    quantity = Column(Integer, nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    revoked_at = Column(DateTime)
    __table_args__ = (
        CheckConstraint("resource_kind IN ('slots', 'turns')", name='ck_manual_resource'),
        CheckConstraint('quantity > 0', name='ck_manual_quantity'),
    )


class BillingTombstoneModel(Base):
    __tablename__ = 'billing_tombstones'
    kind = Column(String(16), primary_key=True)
    digest = Column(String(64), primary_key=True)
    key_version = Column(String(64), primary_key=True)
    status = Column(String(32), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)


class PurchaseNotificationModel(Base):
    __tablename__ = 'purchase_notifications'
    notification_uuid = Column(String(64), primary_key=True)
    notification_type = Column(String(64), nullable=False)
    received_at = Column(DateTime, nullable=False, default=datetime.utcnow)

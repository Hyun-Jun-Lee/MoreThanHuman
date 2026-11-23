"""
Auth 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    false,
)
from sqlalchemy.orm import relationship

from database import Base
from shared.language import DEFAULT_LANGUAGE_CONTEXT, LearningLanguageContext, language_context_from_values


class ProfileModel(Base):
    """앱 사용자 프로필 테이블"""

    __tablename__ = "profiles"

    id = Column(String(36), primary_key=True)
    email = Column(String(255), unique=True, index=True, nullable=True)
    name = Column(String(100), nullable=False)
    nickname = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    is_admin = Column(Boolean, default=False, server_default=false(), nullable=False)
    is_guest = Column(Boolean, default=False, server_default=false(), nullable=False)
    snack_unlimited_replay_enabled = Column(
        Boolean, default=False, server_default=false(), nullable=False
    )
    oauth_provider = Column(String(50), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    native_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.native_language.value, nullable=False)
    target_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.target_language.value, nullable=False)
    feedback_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.feedback_language.value, nullable=False)
    app_locale = Column(String(2), nullable=True)
    legacy_conversation_slots = Column(Integer, nullable=True)
    slot_limit_snapshot = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    last_active_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    conversations = relationship("ConversationModel", back_populates="user", cascade="all, delete-orphan")

    @property
    def language(self) -> LearningLanguageContext:
        """프로필 저장값을 검증된 언어 컨텍스트로 반환"""
        return language_context_from_values(
            native_language=self.native_language,
            target_language=self.target_language,
            feedback_language=self.feedback_language,
        )


class AccountDeletionModel(Base):
    """삭제 요청과 JWT 차단을 위한 최소 영속 기록이에요."""

    __tablename__ = "account_deletions"

    user_id = Column(String(36), primary_key=True)
    receipt_hash = Column(String(64), unique=True, nullable=False)
    status = Column(String(16), nullable=False, default="processing")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)


class UserConsentModel(Base):
    """AI 처리와 개인정보 고지의 버전별 명시 동의를 보관해요."""

    __tablename__ = "user_consents"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "consent_kind", "version", name="uq_user_consent_kind_version"
        ),
        CheckConstraint(
            "consent_kind IN ('privacy_policy', 'ai_data_processing')",
            name="ck_user_consent_kind",
        ),
    )

    id = Column(String(36), primary_key=True)
    user_id = Column(
        String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    consent_kind = Column(String(32), nullable=False)
    version = Column(String(64), nullable=False)
    accepted_at = Column(DateTime, nullable=False)
    revoked_at = Column(DateTime, nullable=True)


class GuestTransferReceiptModel(Base):
    """기존 회원 계정으로 게스트 데이터를 이전하는 일회용 영수증이에요."""

    __tablename__ = "guest_transfer_receipts"
    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'claimed', 'expired')",
            name="ck_guest_transfer_receipt_status",
        ),
        CheckConstraint("expires_at > created_at", name="ck_guest_transfer_receipt_expiry"),
        CheckConstraint(
            "(status = 'claimed' AND claimed_at IS NOT NULL AND claimed_by_user_id IS NOT NULL) "
            "OR (status != 'claimed' AND claimed_at IS NULL AND claimed_by_user_id IS NULL)",
            name="ck_guest_transfer_receipt_claim",
        ),
    )

    id = Column(String(36), primary_key=True)
    guest_user_id = Column(
        String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True
    )
    receipt_hash = Column(String(64), unique=True, nullable=False)
    status = Column(String(16), nullable=False, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at = Column(DateTime, nullable=False, index=True)
    claimed_at = Column(DateTime, nullable=True)
    claimed_by_user_id = Column(
        String(36), ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True
    )

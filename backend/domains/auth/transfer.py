"""게스트 데이터를 기존 회원 계정에 안전하게 합치는 일회용 영수증 흐름."""

import hashlib
import secrets
from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy.orm import Session

from config import get_settings
from domains.auth.models import (
    AccountDeletionModel,
    GuestTransferReceiptModel,
    ProfileModel,
    UserConsentModel,
)
from domains.conversation.models import (
    ConversationModel,
    ConversationSlotGrantModel,
    GuestTurnUsageModel,
    StreamAttemptModel,
    StreamTurnModel,
    SuggestedStartModel,
)
from domains.conversation.repository import ConversationRepository
from domains.language_snacks.models import LanguageSnackBasketResetModel


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("ascii")).hexdigest()


class GuestTransferError(ValueError):
    pass


class GuestTransferService:
    def __init__(self, db: Session):
        self.db = db

    def issue(self, guest_user_id: str) -> tuple[str, datetime]:
        guest = self.db.query(ProfileModel).filter_by(id=guest_user_id).with_for_update().one_or_none()
        if guest is None or not guest.is_guest or not guest.is_active:
            raise GuestTransferError("Only an active guest can create a transfer receipt")
        now = datetime.utcnow()
        self.db.query(GuestTransferReceiptModel).filter_by(
            guest_user_id=guest_user_id, status="pending"
        ).filter(GuestTransferReceiptModel.expires_at <= now).update(
            {GuestTransferReceiptModel.status: "expired"}, synchronize_session=False
        )
        receipt = secrets.token_urlsafe(32)
        expires_at = now + timedelta(
            minutes=get_settings().guest_transfer_receipt_ttl_minutes
        )
        self.db.add(
            GuestTransferReceiptModel(
                id=str(uuid4()),
                guest_user_id=guest_user_id,
                receipt_hash=_hash(receipt),
                status="pending",
                created_at=now,
                expires_at=expires_at,
            )
        )
        self.db.commit()
        return receipt, expires_at

    def claim(self, member_user_id: str, receipt: str) -> tuple[ProfileModel, str]:
        now = datetime.utcnow()
        transfer = self.db.query(GuestTransferReceiptModel).filter_by(
            receipt_hash=_hash(receipt)
        ).with_for_update().one_or_none()
        if transfer is None or transfer.status != "pending":
            raise GuestTransferError("Transfer receipt is invalid or already used")
        if transfer.expires_at <= now:
            transfer.status = "expired"
            self.db.commit()
            raise GuestTransferError("Transfer receipt has expired")
        guest_user_id = transfer.guest_user_id
        if guest_user_id == member_user_id:
            raise GuestTransferError("Guest and member accounts must be different")

        profiles = (
            self.db.query(ProfileModel)
            .filter(ProfileModel.id.in_([guest_user_id, member_user_id]))
            .order_by(ProfileModel.id)
            .with_for_update()
            .all()
        )
        by_id = {profile.id: profile for profile in profiles}
        guest = by_id.get(guest_user_id)
        member = by_id.get(member_user_id)
        if guest is None or not guest.is_guest or not guest.is_active:
            raise GuestTransferError("Guest account is no longer transferable")
        if member is None or member.is_guest or not member.is_active:
            raise GuestTransferError("A member account is required to claim guest data")

        try:
            self._merge_consents(guest_user_id, member_user_id)
            self.db.query(ConversationModel).filter_by(user_id=guest_user_id).update(
                {
                    ConversationModel.user_id: member_user_id,
                    ConversationModel.slot_active: False,
                },
                synchronize_session=False,
            )
            for model in (
                SuggestedStartModel,
                StreamTurnModel,
                StreamAttemptModel,
                GuestTurnUsageModel,
                ConversationSlotGrantModel,
            ):
                self.db.query(model).filter_by(user_id=guest_user_id).update(
                    {model.user_id: member_user_id}, synchronize_session=False
                )
            # 기기 로컬 진행은 회원 쪽이 우선이고, 서버 reset 표식도 덮어쓰지 않아요.
            self.db.query(LanguageSnackBasketResetModel).filter_by(
                user_id=guest_user_id
            ).delete(synchronize_session=False)
            transfer.status = "claimed"
            transfer.claimed_at = now
            transfer.claimed_by_user_id = member_user_id
            guest.is_active = False
            guest.last_active_at = now
            member.slot_limit_snapshot = None
            member.updated_at = now
            ConversationRepository(self.db).reconcile_slots_in_transaction(member)
            if self.db.query(AccountDeletionModel).filter_by(user_id=guest_user_id).one_or_none() is None:
                tombstone = secrets.token_urlsafe(32)
                self.db.add(
                    AccountDeletionModel(
                        user_id=guest_user_id,
                        receipt_hash=_hash(tombstone),
                        status="processing",
                        created_at=now,
                    )
                )
            self.db.commit()
            self.db.refresh(member)
            return member, guest_user_id
        except Exception:
            self.db.rollback()
            raise

    def _merge_consents(self, guest_user_id: str, member_user_id: str) -> None:
        guest_consents = self.db.query(UserConsentModel).filter_by(
            user_id=guest_user_id
        ).all()
        for consent in guest_consents:
            existing = self.db.query(UserConsentModel.id).filter_by(
                user_id=member_user_id,
                consent_kind=consent.consent_kind,
                version=consent.version,
            ).one_or_none()
            if existing is None:
                consent.user_id = member_user_id
            else:
                self.db.delete(consent)
        self.db.flush()

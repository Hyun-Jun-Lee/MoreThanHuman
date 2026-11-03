"""영속 삭제 요청, 사용자 데이터 제거, Supabase Auth 삭제를 처리해요."""

import hashlib
import re
import secrets
from datetime import datetime

import httpx
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from config import get_settings
from domains.auth.models import AccountDeletionModel, ProfileModel
from domains.conversation.audio_cache_flow import cache_files
from domains.conversation.models import (
    ConversationAudioCacheModel,
    ConversationModel,
    ConversationSlotGrantModel,
    MessageModel,
    StreamAttemptModel,
    StreamTurnModel,
    SuggestedStartModel,
)
from domains.language_snacks.models import LanguageSnackBasketResetModel
from shared.subscription import AppleSubscriptionModel


def _receipt_hash(receipt: str) -> str:
    return hashlib.sha256(receipt.encode("ascii")).hexdigest()


def supabase_admin_headers(secret: str) -> dict[str, str]:
    headers = {"apikey": secret}
    if not secret.startswith("sb_secret_"):
        headers["Authorization"] = f"Bearer {secret}"  # 기존 service_role JWT
    return headers


class DeletionAlreadyStarted(ValueError):
    pass


class AccountDeletionService:
    def __init__(self, db: Session, http_client: httpx.AsyncClient):
        self.db = db
        self.http_client = http_client

    def start(self, user_id: str) -> str:
        if self.db.query(AccountDeletionModel.user_id).filter_by(user_id=user_id).first():
            raise DeletionAlreadyStarted("Account deletion already started")
        receipt = secrets.token_urlsafe(32)
        self.db.add(AccountDeletionModel(
            user_id=user_id, receipt_hash=_receipt_hash(receipt),
            status="processing", created_at=datetime.utcnow(),
        ))
        try:
            self.db.commit()  # 이 시점부터 모든 보호 API가 기존 JWT를 거부해요.
        except IntegrityError as exc:
            self.db.rollback()
            raise DeletionAlreadyStarted("Account deletion already started") from exc
        return receipt

    def status(self, receipt: str) -> str | None:
        if not (32 <= len(receipt) <= 128 and re.fullmatch(r"[A-Za-z0-9_-]+", receipt)):
            return None
        row = self.db.query(AccountDeletionModel).filter_by(receipt_hash=_receipt_hash(receipt)).one_or_none()
        return row.status if row else None

    async def process(self, user_id: str) -> bool:
        row = self.db.query(AccountDeletionModel).filter_by(user_id=user_id).one_or_none()
        if row is None:
            raise ValueError("Account deletion request is missing")
        if row.status == "completed":
            return True
        self._purge_profile(user_id)
        await self._delete_auth_user(user_id)
        row.status = "completed"
        row.completed_at = datetime.utcnow()
        self.db.commit()
        return True

    def _purge_profile(self, user_id: str) -> None:
        profile = self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one_or_none()
        if profile is None:
            return
        message_ids = [item[0] for item in self.db.query(MessageModel.id)
                       .join(ConversationModel, MessageModel.conversation_id == ConversationModel.id)
                       .filter(ConversationModel.user_id == user_id).all()]
        cache = cache_files()
        if cache:
            for message_id in message_ids:
                cache.delete_message(message_id)
        self.db.query(StreamAttemptModel).filter_by(user_id=user_id).delete(synchronize_session=False)
        self.db.query(StreamTurnModel).filter_by(user_id=user_id).delete(synchronize_session=False)
        self.db.query(SuggestedStartModel).filter_by(user_id=user_id).delete(synchronize_session=False)
        for start in range(0, len(message_ids), 500):
            self.db.query(ConversationAudioCacheModel).filter(
                ConversationAudioCacheModel.message_id.in_(message_ids[start:start + 500])
            ).delete(synchronize_session=False)
        self.db.query(ConversationSlotGrantModel).filter_by(user_id=user_id).delete(synchronize_session=False)
        self.db.query(LanguageSnackBasketResetModel).filter_by(user_id=user_id).delete(synchronize_session=False)
        self.db.query(AppleSubscriptionModel).filter_by(user_id=user_id).delete(synchronize_session=False)
        self.db.delete(profile)  # 대화 → 메시지 → 문법 피드백은 ORM 관계로 삭제해요.
        self.db.commit()

    async def _delete_auth_user(self, user_id: str) -> None:
        settings = get_settings()
        secret = settings.supabase_secret_key
        if not secret:
            raise RuntimeError("SUPABASE_SECRET_KEY is required for account deletion")
        response = await self.http_client.delete(
            f"{settings.supabase_auth_url}/admin/users/{user_id}",
            headers=supabase_admin_headers(secret),
            timeout=settings.supabase_auth_timeout_seconds,
        )
        if response.status_code not in (200, 204, 404):
            raise RuntimeError(f"Supabase user deletion failed: HTTP {response.status_code}")

"""
Auth Repository Layer
데이터 접근 및 CRUD 연산
"""
from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from domains.auth.models import RefreshTokenModel, UserModel
from shared.exceptions import NotFoundException


class AuthRepository:
    """사용자 저장소"""

    def __init__(self, db: Session):
        self.db = db

    def save(self, user: UserModel) -> UserModel:
        """사용자 저장"""
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def find_by_id(self, user_id: str) -> UserModel:
        """ID로 사용자 조회"""
        user = self.db.query(UserModel).filter(UserModel.id == user_id).first()
        if not user:
            raise NotFoundException(f"User {user_id} not found")
        return user

    def find_by_email(self, email: str) -> UserModel | None:
        """이메일로 사용자 조회 (없으면 None)"""
        return self.db.query(UserModel).filter(UserModel.email == email).first()

    def find_by_oauth(self, provider: str, provider_id: str) -> UserModel | None:
        """OAuth provider ID로 사용자 조회"""
        return (
            self.db.query(UserModel)
            .filter(
                UserModel.oauth_provider == provider,
                UserModel.oauth_provider_id == provider_id,
            )
            .first()
        )

    # --- Refresh Token ---

    def create_refresh_token(
        self,
        *,
        user_id: str,
        device_id: str,
        token_hash: str,
        expires_at: datetime,
    ) -> RefreshTokenModel:
        token = RefreshTokenModel(
            id=str(uuid4()),
            user_id=user_id,
            device_id=device_id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        self.db.add(token)
        self.db.commit()
        self.db.refresh(token)
        return token

    def find_active_refresh_token_by_hash(self, token_hash: str) -> RefreshTokenModel | None:
        now = datetime.utcnow()
        return (
            self.db.query(RefreshTokenModel)
            .filter(
                RefreshTokenModel.token_hash == token_hash,
                RefreshTokenModel.revoked_at.is_(None),
                RefreshTokenModel.expires_at > now,
            )
            .first()
        )

    def revoke_refresh_token_if_active(self, refresh_token_id: str) -> bool:
        now = datetime.utcnow()
        updated = (
            self.db.query(RefreshTokenModel)
            .filter(
                RefreshTokenModel.id == refresh_token_id,
                RefreshTokenModel.revoked_at.is_(None),
            )
            .update(
                {
                    RefreshTokenModel.revoked_at: now,
                    RefreshTokenModel.last_used_at: now,
                },
                synchronize_session=False,
            )
        )
        self.db.commit()
        return updated == 1

    def revoke_active_refresh_tokens_for_user_device(self, *, user_id: str, device_id: str) -> int:
        now = datetime.utcnow()
        updated = (
            self.db.query(RefreshTokenModel)
            .filter(
                RefreshTokenModel.user_id == user_id,
                RefreshTokenModel.device_id == device_id,
                RefreshTokenModel.revoked_at.is_(None),
            )
            .update(
                {
                    RefreshTokenModel.revoked_at: now,
                },
                synchronize_session=False,
            )
        )
        self.db.commit()
        return int(updated or 0)

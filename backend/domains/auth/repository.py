"""
Auth Repository Layer
데이터 접근 및 CRUD 연산
"""
from sqlalchemy.orm import Session

from domains.auth.models import UserModel
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

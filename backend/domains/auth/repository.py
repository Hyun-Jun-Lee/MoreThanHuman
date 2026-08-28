"""
Auth Repository Layer
데이터 접근 및 CRUD 연산
"""
from datetime import datetime

from sqlalchemy.orm import Session

from domains.auth.models import ProfileModel
from shared.exceptions import NotFoundException


class AuthRepository:
    """프로필 저장소"""

    def __init__(self, db: Session):
        self.db = db

    def save(self, profile: ProfileModel) -> ProfileModel:
        """프로필 저장"""
        self.db.add(profile)
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def find_by_id(self, profile_id: str) -> ProfileModel:
        """ID로 프로필 조회"""
        profile = self.db.query(ProfileModel).filter(ProfileModel.id == profile_id).first()
        if not profile:
            raise NotFoundException(f"Profile {profile_id} not found")
        return profile

    def find_by_email(self, email: str) -> ProfileModel | None:
        """이메일로 프로필 조회 (없으면 None)"""
        return self.db.query(ProfileModel).filter(ProfileModel.email == email).first()

    def upsert_profile(
        self,
        *,
        profile_id: str,
        email: str,
        name: str,
        oauth_provider: str | None,
        avatar_url: str | None = None,
    ) -> ProfileModel:
        """Supabase Auth claim 기준으로 프로필 생성 또는 갱신"""
        profile = self.db.query(ProfileModel).filter(ProfileModel.id == profile_id).first()
        now = datetime.utcnow()
        if profile is None:
            profile = ProfileModel(
                id=profile_id,
                email=email,
                name=name,
                oauth_provider=oauth_provider,
                avatar_url=avatar_url,
                created_at=now,
                updated_at=now,
            )
            self.db.add(profile)
        else:
            profile.email = email
            profile.name = name
            profile.oauth_provider = oauth_provider
            profile.avatar_url = avatar_url
            profile.updated_at = now
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def update_language_preferences(
        self,
        *,
        profile_id: str,
        native_language: str,
        target_language: str,
        feedback_language: str,
    ) -> ProfileModel:
        """현재 사용자 프로필의 언어 선호만 갱신"""
        profile = self.find_by_id(profile_id)
        profile.native_language = native_language
        profile.target_language = target_language
        profile.feedback_language = feedback_language
        profile.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def update_app_locale(self, *, profile_id: str, app_locale: str) -> ProfileModel:
        """프로필의 앱 표시 언어를 갱신"""
        profile = self.find_by_id(profile_id)
        profile.app_locale = app_locale
        profile.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(profile)
        return profile

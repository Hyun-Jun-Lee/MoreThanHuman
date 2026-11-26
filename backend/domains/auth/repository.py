"""
Auth Repository Layer
데이터 접근 및 CRUD 연산
"""
from datetime import datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.auth.models import AccountDeletionModel, ProfileModel
from shared.exceptions import AuthenticationException, NotFoundException
from shared.latency import latency_span
from shared.language import LearningLanguageContext


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
        with latency_span("auth.profile.select"):
            profile = self.db.query(ProfileModel).filter(ProfileModel.id == profile_id).first()
        if not profile:
            raise NotFoundException(f"Profile {profile_id} not found")
        return profile

    def find_by_email(self, email: str) -> ProfileModel | None:
        """이메일로 프로필 조회 (없으면 None)"""
        return self.db.query(ProfileModel).filter(ProfileModel.email == email).first()

    def get_or_create_profile(
        self,
        *,
        profile_id: str,
        email: str | None,
        name: str,
        oauth_provider: str | None,
        avatar_url: str | None = None,
        language: LearningLanguageContext | None = None,
        is_guest: bool = False,
        app_locale: str | None = None,
    ) -> ProfileModel:
        from shared.billing_tombstones import find_tombstone
        from shared.credit_ledger import CreditLedger
        if (self.db.query(AccountDeletionModel.user_id).filter_by(user_id=profile_id).first()
                or find_tombstone(self.db, 'user', profile_id)):
            raise AuthenticationException("Account deletion is in progress or completed")
        profile = self.db.query(ProfileModel).filter(ProfileModel.id == profile_id).first()
        if profile is None:
            now = datetime.utcnow()
            profile = ProfileModel(
                id=profile_id,
                email=email,
                name=name,
                oauth_provider=oauth_provider,
                avatar_url=avatar_url,
                is_guest=is_guest,
                created_at=now,
                updated_at=now,
                last_active_at=now,
            )
            self.db.add(profile)
            self._apply_language(profile, language)
            self._apply_app_locale(profile, app_locale)
            try:
                self.db.commit()
            except IntegrityError:
                self.db.rollback()
                profile = self.db.query(ProfileModel).filter(ProfileModel.id == profile_id).first()
                if profile is None:
                    raise
                language_changed = self._apply_language(profile, language)
                locale_changed = self._apply_app_locale(profile, app_locale)
                if language_changed or locale_changed:
                    self.db.commit()
            self.db.refresh(profile)
            CreditLedger(self.db).lock(profile.id)
            CreditLedger(self.db).ensure_trial(profile)
            self.db.commit()
            return profile

        changed = self._apply_language(profile, language)
        changed = self._apply_app_locale(profile, app_locale) or changed
        if profile.is_guest and not is_guest:
            profile.email = email
            profile.name = name
            profile.oauth_provider = oauth_provider
            profile.avatar_url = avatar_url
            profile.is_guest = False
            self.db.flush()
            CreditLedger(self.db).lock(profile.id)
            CreditLedger(self.db).ensure_trial(profile)
            profile.updated_at = datetime.utcnow()
            changed = True
        elif profile.is_guest and is_guest:
            profile.last_active_at = datetime.utcnow()
            changed = True
        if changed:
            self.db.commit()
            self.db.refresh(profile)
        return profile

    @staticmethod
    def _apply_language(profile: ProfileModel, language: LearningLanguageContext | None) -> bool:
        if language is None:
            return False
        values = (
            language.native_language.value,
            language.target_language.value,
            language.feedback_language.value,
        )
        if (profile.native_language, profile.target_language, profile.feedback_language) == values:
            return False
        profile.native_language, profile.target_language, profile.feedback_language = values
        profile.updated_at = datetime.utcnow()
        return True

    @staticmethod
    def _apply_app_locale(profile: ProfileModel, app_locale: str | None) -> bool:
        if app_locale is None or profile.app_locale == app_locale:
            return False
        profile.app_locale = app_locale
        profile.updated_at = datetime.utcnow()
        return True

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
        if (
            profile.native_language == native_language
            and profile.target_language == target_language
            and profile.feedback_language == feedback_language
        ):
            return profile
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
        if not self._apply_app_locale(profile, app_locale):
            return profile
        self.db.commit()
        self.db.refresh(profile)
        return profile

    def update_nickname(self, *, profile_id: str, nickname: str) -> ProfileModel:
        """현재 사용자 프로필의 닉네임을 저장해요."""
        profile = self.find_by_id(profile_id)
        if profile.nickname == nickname:
            return profile
        profile.nickname = nickname
        profile.updated_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(profile)
        return profile

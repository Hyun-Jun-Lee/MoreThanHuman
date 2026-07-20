"""
Auth Service Layer
Supabase Auth claim을 앱 프로필로 연결해요.
"""
from dataclasses import dataclass

from domains.auth.models import ProfileModel
from domains.auth.repository import AuthRepository
from domains.auth.schemas import LanguagePreferencesRequest, LanguagePreferencesResponse, UserProfile
from shared.language import language_context_to_dict
from shared.exceptions import AuthenticationException


@dataclass(frozen=True)
class SupabaseUserClaims:
    """Supabase access token 검증 후 앱에서 필요한 사용자 claim"""

    sub: str
    email: str
    name: str
    oauth_provider: str | None = None
    avatar_url: str | None = None


class AuthService:
    """인증 서비스"""

    def __init__(self, repository: AuthRepository):
        self.repository = repository

    def get_or_create_profile_from_claims(self, claims: SupabaseUserClaims) -> ProfileModel:
        """Supabase claim 기반으로 앱 프로필 생성 또는 갱신"""
        if not claims.sub:
            raise AuthenticationException("Invalid Supabase token: missing subject")
        if not claims.email:
            raise AuthenticationException("Invalid Supabase token: missing email")

        return self.repository.upsert_profile(
            profile_id=claims.sub,
            email=claims.email,
            name=claims.name or claims.email.split("@")[0],
            oauth_provider=claims.oauth_provider,
            avatar_url=claims.avatar_url,
        )

    def get_profile(self, profile_id: str) -> UserProfile:
        """사용자 프로필 조회"""
        profile = self.repository.find_by_id(profile_id)
        return UserProfile.model_validate(profile)

    def get_language_preferences(self, profile_id: str) -> LanguagePreferencesResponse:
        """현재 사용자 언어 선호 조회"""
        profile = self.repository.find_by_id(profile_id)
        return LanguagePreferencesResponse.model_validate(language_context_to_dict(profile.language))

    def update_language_preferences(
        self,
        profile_id: str,
        request: LanguagePreferencesRequest,
    ) -> LanguagePreferencesResponse:
        """현재 사용자 언어 선호 갱신"""
        profile = self.repository.update_language_preferences(
            profile_id=profile_id,
            native_language=request.native_language.value,
            target_language=request.target_language.value,
            feedback_language=request.feedback_language.value,
        )
        return LanguagePreferencesResponse.model_validate(language_context_to_dict(profile.language))

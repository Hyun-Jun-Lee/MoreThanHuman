"""
Auth Service Layer
Supabase Auth claim을 앱 프로필로 연결해요.
"""
from dataclasses import dataclass

import httpx

from config import get_settings
from domains.auth.models import ProfileModel
from domains.auth.repository import AuthRepository
from domains.auth.schemas import (
    LanguagePreferencesRequest,
    LanguagePreferencesResponse,
    AppLocaleRequest,
    TokenResponse,
    UserProfile,
)
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

    async def issue_swagger_token(self, *, email: str, password: str) -> TokenResponse:
        """Swagger 테스트용 Supabase access token 발급"""
        settings = get_settings()
        try:
            async with httpx.AsyncClient(timeout=settings.supabase_auth_timeout_seconds) as client:
                response = await client.post(
                    f"{settings.supabase_auth_url}/token?grant_type=password",
                    headers={
                        "apikey": settings.required_supabase_publishable_key,
                        "Content-Type": "application/json",
                    },
                    json={"email": email, "password": password},
                )
        except httpx.HTTPError as exc:
            raise AuthenticationException("Supabase token issuance failed") from exc

        if response.status_code != 200:
            raise AuthenticationException("Invalid Supabase email/password")

        try:
            data = response.json()
        except ValueError as exc:
            raise AuthenticationException("Invalid Supabase token response") from exc
        if not isinstance(data, dict) or not isinstance(data.get("access_token"), str):
            raise AuthenticationException("Invalid Supabase token response")

        refresh_token = data.get("refresh_token")
        token_type = data.get("token_type") if isinstance(data.get("token_type"), str) else "bearer"
        expires_in = data.get("expires_in") if isinstance(data.get("expires_in"), int) else None
        return TokenResponse(
            access_token=data["access_token"],
            refresh_token=refresh_token if isinstance(refresh_token, str) else None,
            token_type=token_type,
            expires_in=expires_in,
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

    def update_app_locale(self, profile_id: str, request: AppLocaleRequest) -> UserProfile:
        """앱 표시 언어를 저장한 최신 프로필을 반환"""
        profile = self.repository.update_app_locale(
            profile_id=profile_id,
            app_locale=request.app_locale.value,
        )
        return UserProfile.model_validate(profile)

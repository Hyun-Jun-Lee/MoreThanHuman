"""
Supabase Auth access token 검증
"""
from typing import Any

import httpx

from config import get_settings
from domains.auth.service import SupabaseUserClaims
from shared.exceptions import AuthenticationException


class SupabaseAuthVerifier:
    """Supabase Auth 서버를 통해 access token을 검증해요."""

    async def verify_access_token(self, token: str) -> SupabaseUserClaims:
        """Bearer token 검증 후 앱 프로필 claim으로 변환"""
        normalized_token = token.strip()
        if not normalized_token:
            raise AuthenticationException("Missing Supabase access token")

        settings = get_settings()
        if settings.supabase_auth_verify_mode != "remote":
            raise AuthenticationException("Unsupported Supabase auth verification mode")

        user = await self._fetch_user(normalized_token)
        return self._claims_from_user_response(user)

    async def _fetch_user(self, token: str) -> dict[str, Any]:
        settings = get_settings()
        try:
            async with httpx.AsyncClient(timeout=settings.supabase_auth_timeout_seconds) as client:
                response = await client.get(
                    f"{settings.supabase_auth_url}/user",
                    headers={
                        "apikey": settings.required_supabase_publishable_key,
                        "Authorization": f"Bearer {token}",
                    },
                )
        except httpx.HTTPError as exc:
            raise AuthenticationException("Supabase token verification failed") from exc

        if response.status_code != 200:
            raise AuthenticationException("Invalid Supabase access token")

        data = response.json()
        if not isinstance(data, dict):
            raise AuthenticationException("Invalid Supabase user response")
        return data

    def _claims_from_user_response(self, user: dict[str, Any]) -> SupabaseUserClaims:
        sub = str(user.get("id") or "")
        email = str(user.get("email") or "")
        user_metadata = user.get("user_metadata") if isinstance(user.get("user_metadata"), dict) else {}
        app_metadata = user.get("app_metadata") if isinstance(user.get("app_metadata"), dict) else {}

        name = (
            self._string_metadata(user_metadata, "name")
            or self._string_metadata(user_metadata, "full_name")
            or email.split("@")[0]
        )
        oauth_provider = self._string_metadata(app_metadata, "provider")
        avatar_url = self._string_metadata(user_metadata, "avatar_url") or self._string_metadata(
            user_metadata,
            "picture",
        )

        if not sub:
            raise AuthenticationException("Invalid Supabase token: missing subject")
        if not email:
            raise AuthenticationException("Invalid Supabase token: missing email")

        return SupabaseUserClaims(
            sub=sub,
            email=email,
            name=name,
            oauth_provider=oauth_provider,
            avatar_url=avatar_url,
        )

    @staticmethod
    def _string_metadata(metadata: dict[str, Any], key: str) -> str | None:
        value = metadata.get(key)
        return value if isinstance(value, str) and value.strip() else None

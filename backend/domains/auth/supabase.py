"""
Supabase Auth access token 검증
"""
import asyncio
from time import monotonic
from typing import Any

import httpx
from jose import JWTError, jwt

from config import get_settings
from domains.auth.service import SupabaseUserClaims
from shared.exceptions import AuthenticationException
from shared.latency import latency_span


class SupabaseAuthVerifier:
    """ES256 token은 공개 키로, 나머지는 Supabase Auth로 검증해요."""

    JWKS_TTL_SECONDS = 300
    JWKS_MISS_REFRESH_SECONDS = 10

    def __init__(self, http_client: httpx.AsyncClient):
        self.http_client = http_client
        self._jwks: list[dict[str, Any]] = []
        self._jwks_fetched_at = 0.0
        self._jwks_lock = asyncio.Lock()

    async def verify_access_token(self, token: str) -> SupabaseUserClaims:
        """Bearer token 검증 후 앱 프로필 claim으로 변환"""
        normalized_token = token.strip()
        if not normalized_token:
            raise AuthenticationException("Missing Supabase access token")

        settings = get_settings()
        if settings.supabase_auth_verify_mode == "auto":
            try:
                header = jwt.get_unverified_header(normalized_token)
            except JWTError as exc:
                raise AuthenticationException("Invalid Supabase access token") from exc
            if header.get("alg") == "ES256":
                return await self._verify_es256(normalized_token, header)
        elif settings.supabase_auth_verify_mode != "remote":
            raise AuthenticationException("Unsupported Supabase auth verification mode")

        user = await self._fetch_user(normalized_token)
        return self._claims_from_user_response(user)

    async def _verify_es256(self, token: str, header: dict[str, Any]) -> SupabaseUserClaims:
        settings = get_settings()
        kid = header.get("kid")
        if not isinstance(kid, str) or not kid:
            raise AuthenticationException("Invalid Supabase access token")
        key = await self._find_key(kid)
        if key is None:
            raise AuthenticationException("Invalid Supabase access token")
        try:
            claims = jwt.decode(
                token, key, algorithms=["ES256"],
                audience="authenticated", issuer=settings.supabase_auth_url,
                options={"require_exp": True, "require_iat": True, "require_sub": True},
            )
        except JWTError as exc:
            raise AuthenticationException("Invalid Supabase access token") from exc
        if claims.get("role") != "authenticated":
            raise AuthenticationException("Invalid Supabase access token")
        return self._claims_from_user_response({
            "id": claims.get("sub"), "email": claims.get("email"),
            "user_metadata": claims.get("user_metadata"),
            "app_metadata": claims.get("app_metadata"),
        })

    async def _find_key(self, kid: str) -> dict[str, Any] | None:
        async with self._jwks_lock:
            now = monotonic()
            if self._jwks_fetched_at == 0 or now - self._jwks_fetched_at >= self.JWKS_TTL_SECONDS:
                await self._refresh_jwks()
            key = next((item for item in self._jwks if self._matches_key(item, kid)), None)
            if key is None and monotonic() - self._jwks_fetched_at >= self.JWKS_MISS_REFRESH_SECONDS:
                await self._refresh_jwks()
                key = next((item for item in self._jwks if self._matches_key(item, kid)), None)
            return key

    async def _refresh_jwks(self) -> None:
        settings = get_settings()
        try:
            with latency_span("auth.jwks_fetch"):
                response = await self.http_client.get(
                    settings.supabase_jwks_url, timeout=settings.supabase_auth_timeout_seconds,
                )
            response.raise_for_status()
            keys = response.json().get("keys")
            if not isinstance(keys, list):
                raise ValueError("Invalid JWKS")
        except (httpx.HTTPError, ValueError, AttributeError) as exc:
            raise AuthenticationException("Supabase signing keys unavailable") from exc
        self._jwks = [key for key in keys if isinstance(key, dict)]
        self._jwks_fetched_at = monotonic()

    @staticmethod
    def _matches_key(key: dict[str, Any], kid: str) -> bool:
        return (
            key.get("kid") == kid and key.get("kty") == "EC"
            and key.get("crv") == "P-256" and key.get("alg") == "ES256"
            and key.get("use", "sig") == "sig"
            and "verify" in key.get("key_ops", ["verify"])
        )

    async def _fetch_user(self, token: str) -> dict[str, Any]:
        settings = get_settings()
        try:
            with latency_span("auth.remote_user"):
                response = await self.http_client.get(
                    f"{settings.supabase_auth_url}/user",
                    timeout=settings.supabase_auth_timeout_seconds,
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

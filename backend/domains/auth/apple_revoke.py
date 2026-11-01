"""계정 삭제 때 새 Apple 승인 코드로 Sign in with Apple 연결을 해제해요."""

import time

import httpx
from jose import jwt

from config import get_settings
from domains.auth.deletion import supabase_admin_headers


async def revoke_apple_sign_in(
    client: httpx.AsyncClient, user_id: str, identity_token: str, authorization_code: str,
) -> bool:
    """서버에서 Apple ID와 Supabase identity를 대조한 뒤 토큰을 폐기해요.

    인증코드나 Apple 토큰을 저장하지 않아요. 실패해도 계정 삭제는 진행해야 해요.
    """
    settings = get_settings()
    secret = settings.supabase_secret_key
    if not all((secret, settings.apple_signin_team_id, settings.apple_signin_key_id,
                settings.apple_signin_client_id, settings.apple_signin_private_key)):
        return False
    try:
        user = await client.get(
            f"{settings.supabase_auth_url}/admin/users/{user_id}",
            headers=supabase_admin_headers(secret),
            timeout=settings.supabase_auth_timeout_seconds,
        )
        user.raise_for_status()
        header = jwt.get_unverified_header(identity_token)
        keys = await client.get("https://appleid.apple.com/auth/keys", timeout=5.0)
        keys.raise_for_status()
        key = next((item for item in keys.json().get("keys", [])
                    if item.get("kid") == header.get("kid") and item.get("alg") == "RS256"), None)
        if key is None:
            return False
        claims = jwt.decode(identity_token, key, algorithms=["RS256"],
                            audience=settings.apple_signin_client_id, issuer="https://appleid.apple.com")
        apple_sub = claims.get("sub")
        identities = user.json().get("identities") or []
        linked = any(
            item.get("provider") == "apple" and
            (item.get("id") == apple_sub or (item.get("identity_data") or {}).get("sub") == apple_sub)
            for item in identities if isinstance(item, dict)
        )
        if not apple_sub or not linked:
            return False
        now = int(time.time())
        client_secret = jwt.encode(
            {"iss": settings.apple_signin_team_id, "iat": now, "exp": now + 300,
             "aud": "https://appleid.apple.com", "sub": settings.apple_signin_client_id},
            settings.apple_signin_private_key.replace("\\n", "\n"),
            algorithm="ES256", headers={"kid": settings.apple_signin_key_id},
        )
        base = {"client_id": settings.apple_signin_client_id, "client_secret": client_secret}
        exchanged = await client.post(
            "https://appleid.apple.com/auth/token",
            data={**base, "code": authorization_code, "grant_type": "authorization_code"},
            timeout=5.0,
        )
        exchanged.raise_for_status()
        tokens = exchanged.json()
        token = tokens.get("refresh_token") or tokens.get("access_token")
        if not token:
            return False
        revoked = await client.post(
            "https://appleid.apple.com/auth/revoke",
            data={**base, "token": token, "token_type_hint":
                  "refresh_token" if tokens.get("refresh_token") else "access_token"},
            timeout=5.0,
        )
        return revoked.status_code == 200
    except Exception:  # Apple 연결 해제 실패가 계정 데이터 삭제를 막지 않아야 해요.
        return False

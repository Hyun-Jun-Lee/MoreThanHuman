from types import SimpleNamespace

import httpx
import pytest

from domains.auth.apple_revoke import revoke_apple_sign_in


@pytest.mark.asyncio
@pytest.mark.parametrize("linked", [False, True])
async def test_apple_revoke_requires_identity_link_before_exchanging_code(monkeypatch, linked):
    monkeypatch.setattr("domains.auth.apple_revoke.get_settings", lambda: SimpleNamespace(
        supabase_secret_key="sb_secret_test", supabase_auth_url="https://supabase.test/auth/v1",
        supabase_auth_timeout_seconds=1.0, apple_signin_team_id="TEAM",
        apple_signin_key_id="KEY", apple_signin_client_id="com.example.app",
        apple_signin_private_key="private-key"))
    monkeypatch.setattr("domains.auth.apple_revoke.jwt.get_unverified_header", lambda _: {"kid": "APPLE"})
    monkeypatch.setattr("domains.auth.apple_revoke.jwt.decode", lambda *_args, **_kwargs: {"sub": "apple-user"})
    monkeypatch.setattr("domains.auth.apple_revoke.jwt.encode", lambda *_args, **_kwargs: "client-secret")
    requested = []

    def handle(request):
        requested.append(request.url.path)
        if request.url.path.endswith("/admin/users/user-id"):
            assert "authorization" not in request.headers
            identity = "apple-user" if linked else "other-user"
            return httpx.Response(200, json={"identities": [
                {"provider": "apple", "identity_data": {"sub": identity}},
            ]})
        if request.url.path == "/auth/keys":
            return httpx.Response(200, json={"keys": [{"kid": "APPLE", "alg": "RS256"}]})
        if request.url.path == "/auth/token":
            return httpx.Response(200, json={"refresh_token": "refresh"})
        if request.url.path == "/auth/revoke":
            return httpx.Response(200)
        raise AssertionError(request.url.path)

    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
        result = await revoke_apple_sign_in(client, "user-id", "identity-jwt", "auth-code")
    assert result is linked
    assert ("/auth/token" in requested) is linked
    assert ("/auth/revoke" in requested) is linked

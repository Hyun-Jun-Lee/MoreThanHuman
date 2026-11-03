"""Supabase 공개 키 검증과 레거시 원격 검증을 확인해요."""

import base64
from datetime import datetime, timedelta, timezone

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from jose import jwt

from config import Settings, get_settings
from domains.auth.supabase import SupabaseAuthVerifier
from shared.exceptions import AuthenticationException


def _b64(value: int) -> str:
    return base64.urlsafe_b64encode(value.to_bytes(32, "big")).rstrip(b"=").decode()


def _signing_key(kid: str):
    private_key = ec.generate_private_key(ec.SECP256R1())
    public = private_key.public_key().public_numbers()
    pem = private_key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    return pem, {
        "kid": kid, "kty": "EC", "alg": "ES256", "crv": "P-256",
        "use": "sig", "x": _b64(public.x), "y": _b64(public.y),
    }


def _token(pem: bytes, kid: str, **overrides) -> str:
    now = datetime.now(timezone.utc)
    claims = {
        "iss": get_settings().supabase_auth_url, "aud": "authenticated",
        "sub": "550e8400-e29b-41d4-a716-446655440000",
        "email": "learner@example.com", "role": "authenticated", "iat": now,
        "exp": now + timedelta(minutes=5),
        "user_metadata": {"full_name": "Learner"},
        "app_metadata": {"provider": "google"},
    }
    claims.update(overrides)
    return jwt.encode(claims, pem, algorithm="ES256", headers={"kid": kid})


@pytest.fixture
def auto_verify(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "supabase_auth_verify_mode", "auto")
    monkeypatch.setattr(settings, "supabase_url", "https://auth.test")
    monkeypatch.setattr(settings, "supabase_publishable_key", "public-test-key")


def test_auto_is_default_without_environment_override(monkeypatch):
    monkeypatch.delenv("SUPABASE_AUTH_VERIFY_MODE", raising=False)
    assert Settings(_env_file=None, grammar_model_provider="openrouter").supabase_auth_verify_mode == "auto"


@pytest.mark.asyncio
async def test_es256_uses_cached_jwks_without_user_request(auto_verify):
    pem, public = _signing_key("key-1")
    requests = []

    def upstream(request):
        requests.append(request.url.path)
        assert request.url.path.endswith("/.well-known/jwks.json")
        return httpx.Response(200, json={"keys": [public]})

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        verifier = SupabaseAuthVerifier(client)
        for _ in range(2):
            claims = await verifier.verify_access_token(_token(pem, "key-1"))
            assert claims.sub == "550e8400-e29b-41d4-a716-446655440000"
            assert claims.email == "learner@example.com"
            assert claims.name == "Learner"
            assert claims.oauth_provider == "google"
    assert len(requests) == 1


@pytest.mark.asyncio
async def test_es256_rejects_bad_signature_claims_and_unknown_key(auto_verify):
    pem, public = _signing_key("key-1")
    other_pem, _ = _signing_key("key-2")
    paths = []

    def upstream(request):
        paths.append(request.url.path)
        return httpx.Response(200, json={"keys": [public]})

    bad_tokens = [
        _token(other_pem, "key-1"),
        _token(pem, "key-1", exp=datetime.now(timezone.utc) - timedelta(seconds=1)),
        _token(pem, "key-1", aud="wrong"),
        _token(pem, "key-1", iss="https://other.test/auth/v1"),
        _token(pem, "key-1", role="service_role"),
        _token(pem, "key-2"),
    ]
    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        verifier = SupabaseAuthVerifier(client)
        for token in bad_tokens:
            with pytest.raises(AuthenticationException, match="Invalid Supabase access token"):
                await verifier.verify_access_token(token)
    assert paths == ["/auth/v1/.well-known/jwks.json"]


@pytest.mark.asyncio
async def test_es256_jwks_failure_does_not_trust_token(auto_verify):
    pem, _ = _signing_key("key-1")

    def upstream(request):
        return httpx.Response(503)

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        with pytest.raises(AuthenticationException, match="signing keys unavailable"):
            await SupabaseAuthVerifier(client).verify_access_token(_token(pem, "key-1"))


@pytest.mark.asyncio
async def test_es256_refreshes_jwks_for_rotated_key(auto_verify):
    first_pem, first_key = _signing_key("key-1")
    second_pem, second_key = _signing_key("key-2")
    keys = [first_key]
    calls = 0

    def upstream(request):
        nonlocal calls
        calls += 1
        return httpx.Response(200, json={"keys": keys})

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        verifier = SupabaseAuthVerifier(client)
        await verifier.verify_access_token(_token(first_pem, "key-1"))
        keys = [second_key]
        verifier._jwks_fetched_at -= verifier.JWKS_MISS_REFRESH_SECONDS
        claims = await verifier.verify_access_token(_token(second_pem, "key-2"))
        assert claims.email == "learner@example.com"
    assert calls == 2


@pytest.mark.asyncio
async def test_hs256_keeps_remote_verification(auto_verify):
    token = jwt.encode({"sub": "user"}, "legacy-secret", algorithm="HS256")
    paths = []

    def upstream(request):
        paths.append(request.url.path)
        return httpx.Response(200, json={"id": "legacy-user", "email": "old@example.com"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        claims = await SupabaseAuthVerifier(client).verify_access_token(token)
    assert claims.sub == "legacy-user"
    assert paths == ["/auth/v1/user"]

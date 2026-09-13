import asyncio
import importlib

import httpx
import pytest

from config import get_settings
from domains.auth.service import AuthService
from domains.auth.supabase import SupabaseAuthVerifier
from domains.llm.ollama import OllamaProvider
from domains.llm.openrouter import OpenRouterProvider
from domains.llm.schemas import LLMMessage, LLMRequest
from domains.voice.openai_provider import OpenAIVoiceProvider
from domains.voice.openrouter_provider import OpenRouterVoiceProvider
from shared.exceptions import AuthenticationException, ExternalAPIException

http_module = importlib.import_module("shared.http_clients")


@pytest.mark.asyncio
async def test_concurrent_auth_headers_and_upstream_cookies_are_isolated(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "supabase_url", "https://auth.test")
    monkeypatch.setattr(settings, "supabase_publishable_key", "public-test-key")
    observed = []

    async def upstream(request):
        token = request.headers["authorization"].removeprefix("Bearer ")
        observed.append(request)
        await asyncio.sleep(0)
        return httpx.Response(200, json={"id": token, "email": f"{token}@example.com"},
                              headers={"set-cookie": f"user={token}; Path=/"})

    client_class = httpx.AsyncClient
    monkeypatch.setattr(http_module.httpx, "AsyncClient", lambda **kwargs: client_class(
        **kwargs, transport=httpx.MockTransport(upstream),
    ))
    async with http_module.create_http_client(settings) as client:
        verifier = SupabaseAuthVerifier(client)
        claims = await asyncio.gather(*(verifier.verify_access_token(token) for token in ["a", "b"]))
        assert [claim.sub for claim in claims] == ["a", "b"]
        assert (await verifier.verify_access_token("c")).sub == "c"
        assert not list(client.cookies.jar)
        assert "authorization" not in client.headers
        assert all("cookie" not in request.headers for request in observed)
        assert all(request.extensions["timeout"]["read"] == settings.supabase_auth_timeout_seconds
                   for request in observed)
        assert not client.is_closed


PROVIDER_CASES = [
    (OpenRouterProvider, "llm", 30.0), (OllamaProvider, "llm", 60.0),
    (OpenRouterVoiceProvider, "stt", None), (OpenRouterVoiceProvider, "tts", None),
    (OpenAIVoiceProvider, "stt", None), (OpenAIVoiceProvider, "tts", None),
]


async def call_provider(provider, operation):
    if operation == "llm":
        return await provider.chat_completion(LLMRequest(
            messages=[LLMMessage(role="user", content="Hello")], model="test-model",
        ))
    if operation == "stt":
        return await provider.transcribe_audio(filename="test.wav", content_type="audio/wav", audio_bytes=b"audio")
    return await provider.synthesize_speech(text="Hello")


@pytest.mark.asyncio
@pytest.mark.parametrize("provider_class,operation,timeout", PROVIDER_CASES)
async def test_providers_borrow_client_and_preserve_timeout(monkeypatch, provider_class, operation, timeout):
    settings = importlib.import_module(provider_class.__module__).settings
    monkeypatch.setattr(settings, "openai_api_key", "openai-test-key")
    requests = []

    async def upstream(request):
        requests.append(request)
        if operation == "llm":
            return httpx.Response(200, json={"choices": [{"message": {"content": "Hello"}}]})
        if operation == "stt":
            return httpx.Response(200, json={"text": "Hello"})
        return httpx.Response(200, content=b"audio", headers={"content-type": "audio/mpeg"})

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        for _ in range(2):
            provider = provider_class(client)
            await call_provider(provider, operation)
            assert not client.is_closed
        expected = timeout if timeout is not None else settings.voice_provider_timeout_seconds
        assert all(request.extensions["timeout"] == dict.fromkeys(
            ["connect", "read", "write", "pool"], expected,
        ) for request in requests)
        assert len(requests) == 2
    assert client.is_closed


@pytest.mark.asyncio
@pytest.mark.parametrize("provider_class,operation,_timeout", PROVIDER_CASES)
async def test_provider_timeouts_preserve_error_mapping_without_retry(monkeypatch, provider_class, operation, _timeout):
    settings = importlib.import_module(provider_class.__module__).settings
    monkeypatch.setattr(settings, "openai_api_key", "openai-test-key")
    calls = []

    def upstream(request):
        calls.append(request)
        raise httpx.ReadTimeout("test timeout", request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        with pytest.raises(ExternalAPIException):
            await call_provider(provider_class(client), operation)
        assert len(calls) == 1
        assert not client.is_closed


@pytest.mark.asyncio
async def test_auth_pool_timeout_preserves_authentication_error(monkeypatch):
    settings = get_settings()
    monkeypatch.setattr(settings, "supabase_url", "https://auth.test")
    monkeypatch.setattr(settings, "supabase_publishable_key", "public-test-key")

    def upstream(request):
        raise httpx.PoolTimeout("test pool timeout", request=request)

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        with pytest.raises(AuthenticationException, match="verification failed"):
            await SupabaseAuthVerifier(client).verify_access_token("token")
        with pytest.raises(AuthenticationException, match="issuance failed"):
            await AuthService(None, http_client=client).issue_swagger_token(email="x@example.com", password="test")
        assert not client.is_closed

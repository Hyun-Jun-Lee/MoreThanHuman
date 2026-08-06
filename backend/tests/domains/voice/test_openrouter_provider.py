import httpx
import pytest

from domains.voice import openrouter_provider as openrouter_provider_module
from domains.voice.openrouter_provider import OpenRouterVoiceProvider
from shared.exceptions import AppException, RateLimitException


class FakeAsyncClient:
    def __init__(self, response: httpx.Response):
        self.response = response
        self.calls = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, traceback):
        return False

    async def post(self, url, **kwargs):
        self.calls.append({"url": url, **kwargs})
        return self.response


def make_response(status_code: int = 200, *, json_data=None, content: bytes = b"", headers=None):
    body_kwargs = {"json": json_data} if json_data is not None else {"content": content}
    return httpx.Response(
        status_code,
        headers=headers,
        request=httpx.Request("POST", "https://openrouter.ai/test"),
        **body_kwargs,
    )


@pytest.mark.asyncio
async def test_openrouter_transcribe_audio_uses_multipart_request(monkeypatch):
    fake_client = FakeAsyncClient(make_response(json_data={"text": "Hello there."}))
    monkeypatch.setattr(openrouter_provider_module.httpx, "AsyncClient", lambda: fake_client)
    monkeypatch.setattr(openrouter_provider_module.settings, "openrouter_api_key", "test-key")
    monkeypatch.setattr(
        openrouter_provider_module.settings,
        "stt_model",
        "openai/gpt-4o-mini-transcribe",
    )

    result = await OpenRouterVoiceProvider().transcribe_audio(
        filename="speech.webm",
        content_type="audio/webm",
        audio_bytes=b"audio-bytes",
    )

    assert result.text == "Hello there."
    assert fake_client.calls[0]["url"] == "https://openrouter.ai/api/v1/audio/transcriptions"
    assert fake_client.calls[0]["headers"]["Authorization"] == "Bearer test-key"
    assert fake_client.calls[0]["data"] == {"model": "openai/gpt-4o-mini-transcribe"}
    assert fake_client.calls[0]["files"]["file"] == ("speech.webm", b"audio-bytes", "audio/webm")


@pytest.mark.asyncio
async def test_openrouter_synthesize_speech_uses_audio_speech_endpoint(monkeypatch):
    fake_client = FakeAsyncClient(
        make_response(
            content=b"mp3-bytes",
            headers={"content-type": "audio/mpeg"},
        )
    )
    monkeypatch.setattr(openrouter_provider_module.httpx, "AsyncClient", lambda: fake_client)
    monkeypatch.setattr(openrouter_provider_module.settings, "openrouter_api_key", "test-key")
    monkeypatch.setattr(openrouter_provider_module.settings, "tts_model", "microsoft/mai-voice-2-flash")
    monkeypatch.setattr(openrouter_provider_module.settings, "tts_voice", "en-US-Harper:MAI-Voice-2-Flash")
    monkeypatch.setattr(openrouter_provider_module.settings, "tts_response_format", "mp3")

    result = await OpenRouterVoiceProvider().synthesize_speech(text="Welcome back.")

    assert result.audio_bytes == b"mp3-bytes"
    assert result.content_type == "audio/mpeg"
    assert result.format == "mp3"
    assert fake_client.calls[0]["url"] == "https://openrouter.ai/api/v1/audio/speech"
    assert fake_client.calls[0]["json"] == {
        "model": "microsoft/mai-voice-2-flash",
        "voice": "en-US-Harper:MAI-Voice-2-Flash",
        "input": "Welcome back.",
        "response_format": "mp3",
    }


@pytest.mark.asyncio
async def test_openrouter_transcribe_audio_maps_rate_limit(monkeypatch):
    fake_client = FakeAsyncClient(make_response(429, json_data={"error": "rate limited"}))
    monkeypatch.setattr(openrouter_provider_module.httpx, "AsyncClient", lambda: fake_client)
    monkeypatch.setattr(openrouter_provider_module.settings, "openrouter_api_key", "test-key")

    with pytest.raises(RateLimitException, match="rate limit"):
        await OpenRouterVoiceProvider().transcribe_audio(
            filename="speech.webm",
            content_type="audio/webm",
            audio_bytes=b"audio-bytes",
        )


@pytest.mark.asyncio
async def test_openrouter_provider_requires_api_key(monkeypatch):
    monkeypatch.setattr(openrouter_provider_module.settings, "openrouter_api_key", "")

    with pytest.raises(AppException, match="OPENROUTER_API_KEY"):
        await OpenRouterVoiceProvider().synthesize_speech(text="Hello.")

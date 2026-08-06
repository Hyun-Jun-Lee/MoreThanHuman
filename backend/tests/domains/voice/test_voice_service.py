import pytest

from domains.voice.schemas import VoiceSynthesisResult, VoiceTranscriptionResult
from domains.voice import service as voice_service_module
from domains.voice.openai_provider import OpenAIVoiceProvider
from domains.voice.openrouter_provider import OpenRouterVoiceProvider
from domains.voice.service import VoiceService
from shared.exceptions import AppException, ValidationException

WEBM_BYTES = b"\x1A\x45\xDF\xA3fake webm audio"


class FakeUpload:
    def __init__(
        self,
        content: bytes,
        *,
        filename: str = "speech.webm",
        content_type: str = "audio/webm",
    ):
        self._content = content
        self._offset = 0
        self.filename = filename
        self.content_type = content_type

    async def read(self, size: int = -1) -> bytes:
        if size is None or size < 0:
            size = len(self._content) - self._offset
        chunk = self._content[self._offset : self._offset + size]
        self._offset += len(chunk)
        return chunk


class FakeVoiceProvider:
    def __init__(self, *, transcript: str = "I want to practice English."):
        self.transcript = transcript
        self.transcribe_calls = []
        self.synthesis_calls = []

    async def transcribe_audio(self, *, filename: str, content_type: str, audio_bytes: bytes):
        self.transcribe_calls.append(
            {
                "filename": filename,
                "content_type": content_type,
                "audio_bytes": audio_bytes,
            }
        )
        return VoiceTranscriptionResult(text=self.transcript)

    async def synthesize_speech(self, *, text: str):
        self.synthesis_calls.append(text)
        return VoiceSynthesisResult(
            audio_bytes=b"audio-bytes",
            content_type="audio/mpeg",
            format="mp3",
        )

    def get_provider_name(self) -> str:
        return "fake"


@pytest.mark.asyncio
async def test_text_input_does_not_require_voice_provider_configuration(monkeypatch):
    monkeypatch.setattr(voice_service_module.settings, "stt_provider", "unsupported")
    monkeypatch.setattr(voice_service_module.settings, "tts_provider", "unsupported")
    service = VoiceService()

    input_mode, text = await service.resolve_input_text(text=" Hello ", audio_file=None)

    assert input_mode == "text"
    assert text == "Hello"


def test_create_provider_supports_openrouter(monkeypatch):
    monkeypatch.setattr(voice_service_module.settings, "stt_provider", "openrouter")
    monkeypatch.setattr(voice_service_module.settings, "tts_provider", "openrouter")

    provider = VoiceService().provider

    assert isinstance(provider, OpenRouterVoiceProvider)


def test_create_provider_still_supports_openai(monkeypatch):
    monkeypatch.setattr(voice_service_module.settings, "stt_provider", "openai")
    monkeypatch.setattr(voice_service_module.settings, "tts_provider", "openai")

    provider = VoiceService().provider

    assert isinstance(provider, OpenAIVoiceProvider)


def test_create_provider_rejects_mixed_voice_providers(monkeypatch):
    monkeypatch.setattr(voice_service_module.settings, "stt_provider", "openrouter")
    monkeypatch.setattr(voice_service_module.settings, "tts_provider", "openai")

    with pytest.raises(AppException, match="same provider"):
        _ = VoiceService().provider


@pytest.mark.asyncio
async def test_transcribe_upload_returns_non_empty_transcript():
    provider = FakeVoiceProvider(transcript="  Let's talk about travel. ")
    service = VoiceService(provider=provider)

    result = await service.transcribe_upload(FakeUpload(WEBM_BYTES))

    assert result.text == "Let's talk about travel."
    assert provider.transcribe_calls[0]["filename"] == "speech.webm"


@pytest.mark.asyncio
async def test_transcribe_upload_rejects_empty_transcript():
    service = VoiceService(provider=FakeVoiceProvider(transcript="   "))

    with pytest.raises(ValidationException, match="empty transcript"):
        await service.transcribe_upload(FakeUpload(WEBM_BYTES))


@pytest.mark.asyncio
async def test_transcribe_upload_rejects_unsupported_audio_type():
    service = VoiceService(provider=FakeVoiceProvider())

    with pytest.raises(ValidationException, match="Unsupported audio"):
        await service.transcribe_upload(
            FakeUpload(WEBM_BYTES, filename="speech.txt", content_type="text/plain")
        )


@pytest.mark.asyncio
async def test_transcribe_upload_rejects_invalid_audio_signature():
    service = VoiceService(provider=FakeVoiceProvider())

    with pytest.raises(ValidationException, match="Invalid audio file signature"):
        await service.transcribe_upload(FakeUpload(b"fake audio"))


@pytest.mark.asyncio
async def test_transcribe_upload_rejects_supported_extension_with_unsupported_content_type():
    service = VoiceService(provider=FakeVoiceProvider())

    with pytest.raises(ValidationException, match="Unsupported audio content type"):
        await service.transcribe_upload(
            FakeUpload(WEBM_BYTES, filename="speech.webm", content_type="text/plain")
        )


@pytest.mark.asyncio
async def test_resolve_input_text_rejects_ambiguous_input():
    service = VoiceService(provider=FakeVoiceProvider())

    with pytest.raises(ValidationException, match="either text or audio_file"):
        await service.resolve_input_text(text="Hello", audio_file=FakeUpload(WEBM_BYTES))


@pytest.mark.asyncio
async def test_synthesize_response_returns_base64_audio():
    provider = FakeVoiceProvider()
    service = VoiceService(provider=provider)

    result = await service.synthesize_response("Hello there.")

    assert result.content_type == "audio/mpeg"
    assert result.format == "mp3"
    assert result.base64 == "YXVkaW8tYnl0ZXM="
    assert provider.synthesis_calls == ["Hello there."]


@pytest.mark.asyncio
async def test_synthesize_response_rejects_oversized_audio(monkeypatch):
    class LargeAudioProvider(FakeVoiceProvider):
        async def synthesize_speech(self, *, text: str):
            return VoiceSynthesisResult(
                audio_bytes=b"x" * 2,
                content_type="audio/mpeg",
                format="mp3",
            )

    monkeypatch.setattr(voice_service_module.settings, "tts_max_output_mb", 0)
    service = VoiceService(provider=LargeAudioProvider())

    with pytest.raises(ValidationException, match="TTS output exceeds"):
        await service.synthesize_response("Hello there.")

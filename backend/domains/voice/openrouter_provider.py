"""
OpenRouter Voice Provider
"""
import httpx

from config import get_settings
from domains.voice.provider import VoiceProvider
from domains.voice.schemas import VoiceSynthesisResult, VoiceTranscriptionResult
from shared.exceptions import AppException, ExternalAPIException, RateLimitException

settings = get_settings()


class OpenRouterVoiceProvider(VoiceProvider):
    """OpenRouter STT/TTS API Provider"""

    def __init__(self):
        self.api_key = settings.openrouter_api_key
        self.transcriptions_url = "https://openrouter.ai/api/v1/audio/transcriptions"
        self.speech_url = "https://openrouter.ai/api/v1/audio/speech"

    def _headers(self) -> dict[str, str]:
        if not self.api_key:
            raise AppException("OPENROUTER_API_KEY is required for OpenRouter voice features.")
        return {
            "Authorization": f"Bearer {self.api_key}",
            "HTTP-Referer": "https://github.com/MoreThanHuman",
            "X-OpenRouter-Title": "Curitalk",
        }

    async def transcribe_audio(
        self,
        *,
        filename: str,
        content_type: str,
        audio_bytes: bytes,
    ) -> VoiceTranscriptionResult:
        """OpenRouter STT API 호출"""
        files = {"file": (filename, audio_bytes, content_type)}
        data = {"model": settings.stt_model}

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    self.transcriptions_url,
                    headers=self._headers(),
                    files=files,
                    data=data,
                    timeout=settings.voice_provider_timeout_seconds,
                )
                response.raise_for_status()
                payload = response.json()
                return VoiceTranscriptionResult(text=str(payload.get("text", "")))
            except httpx.HTTPStatusError as e:
                status_code = e.response.status_code if e.response is not None else None
                if status_code == 429:
                    raise RateLimitException(
                        "STT provider rate limit reached. Please try again later.",
                        details={"provider": self.get_provider_name()},
                    )
                response_body = e.response.text[:500] if e.response is not None else ""
                raise ExternalAPIException(
                    "OpenRouter transcription failed.",
                    details={
                        "provider": self.get_provider_name(),
                        "status_code": status_code,
                        "response_body": response_body,
                    },
                )
            except httpx.HTTPError as e:
                raise ExternalAPIException(
                    "OpenRouter transcription failed.",
                    details={"provider": self.get_provider_name(), "error_type": type(e).__name__},
                )

    async def synthesize_speech(self, *, text: str) -> VoiceSynthesisResult:
        """OpenRouter TTS API 호출"""
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    self.speech_url,
                    headers={**self._headers(), "Content-Type": "application/json"},
                    json={
                        "model": settings.tts_model,
                        "voice": settings.tts_voice,
                        "input": text,
                        "response_format": settings.tts_response_format,
                    },
                    timeout=settings.voice_provider_timeout_seconds,
                )
                response.raise_for_status()
                return VoiceSynthesisResult(
                    audio_bytes=response.content,
                    content_type=response.headers.get(
                        "content-type",
                        f"audio/{settings.tts_response_format}",
                    ),
                    format=settings.tts_response_format,
                )
            except httpx.HTTPStatusError as e:
                status_code = e.response.status_code if e.response is not None else None
                if status_code == 429:
                    raise RateLimitException(
                        "TTS provider rate limit reached. Please try again later.",
                        details={"provider": self.get_provider_name()},
                    )
                response_body = e.response.text[:500] if e.response is not None else ""
                raise ExternalAPIException(
                    "OpenRouter speech synthesis failed.",
                    details={
                        "provider": self.get_provider_name(),
                        "status_code": status_code,
                        "response_body": response_body,
                    },
                )
            except httpx.HTTPError as e:
                raise ExternalAPIException(
                    "OpenRouter speech synthesis failed.",
                    details={"provider": self.get_provider_name(), "error_type": type(e).__name__},
                )

    def get_provider_name(self) -> str:
        """Provider 이름 반환"""
        return "openrouter"

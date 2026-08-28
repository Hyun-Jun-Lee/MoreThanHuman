"""
Voice Service Layer
"""
import base64
import logging
from pathlib import Path
from typing import Protocol

from fastapi import UploadFile

from config import get_settings
from domains.voice.openai_provider import OpenAIVoiceProvider
from domains.voice.openrouter_provider import OpenRouterVoiceProvider
from domains.voice.provider import VoiceProvider
from domains.voice.schemas import (
    VoiceAudioResponse,
    VoiceInputMode,
    VoiceTranscriptionResult,
)
from shared.exceptions import AppException, ValidationException

settings = get_settings()
logger = logging.getLogger(__name__)


class UploadedAudio(Protocol):
    """UploadFile 테스트 더블용 최소 인터페이스"""

    filename: str | None
    content_type: str | None

    async def read(self, size: int = -1) -> bytes:
        """파일 바이트 읽기"""
        ...


class VoiceService:
    """음성 입력/응답 처리 서비스"""

    minimum_audio_bytes = 1024
    supported_content_types = {
        "audio/flac",
        "audio/mpeg",
        "audio/mp4",
        "audio/mpga",
        "audio/m4a",
        "audio/ogg",
        "audio/wav",
        "audio/webm",
        "audio/x-m4a",
        "video/mp4",
    }
    supported_extensions = {".flac", ".mp3", ".mp4", ".mpeg", ".mpga", ".m4a", ".ogg", ".wav", ".webm"}
    octet_stream_content_type = "application/octet-stream"

    def __init__(self, provider: VoiceProvider | None = None):
        self._provider = provider

    @property
    def provider(self) -> VoiceProvider:
        """음성 provider는 실제 음성 기능 사용 시점에만 생성"""
        if self._provider is None:
            self._provider = self._create_provider()
        return self._provider

    def _create_provider(self) -> VoiceProvider:
        if settings.stt_provider != settings.tts_provider:
            raise AppException("STT_PROVIDER and TTS_PROVIDER must use the same provider.")
        if settings.stt_provider == "openai":
            return OpenAIVoiceProvider()
        if settings.stt_provider == "openrouter":
            return OpenRouterVoiceProvider()
        if settings.tts_provider not in {"openai", "openrouter"}:
            raise AppException(
                "Only openai and openrouter are supported for STT_PROVIDER and TTS_PROVIDER."
            )
        raise AppException("Unsupported voice provider configuration.")

    @staticmethod
    def normalize_text(value: str | None) -> str | None:
        """빈 문자열을 None으로 정규화"""
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    async def resolve_input_text(
        self,
        *,
        text: str | None,
        audio_file: UploadedAudio | UploadFile | None,
    ) -> tuple[VoiceInputMode, str]:
        """텍스트 또는 음성 파일을 canonical user text로 변환"""
        normalized_text = self.normalize_text(text)
        has_audio = audio_file is not None and bool(getattr(audio_file, "filename", None))

        if normalized_text and has_audio:
            raise ValidationException("Provide either text or audio_file, not both.")
        if not normalized_text and not has_audio:
            raise ValidationException("Either text or audio_file is required.")

        if normalized_text:
            return VoiceInputMode.TEXT, normalized_text

        transcript = await self.transcribe_upload(audio_file)
        return VoiceInputMode.AUDIO, transcript.text

    async def transcribe_upload(self, audio_file: UploadedAudio | UploadFile | None) -> VoiceTranscriptionResult:
        """업로드된 음성 파일을 텍스트로 변환"""
        if audio_file is None:
            raise ValidationException("audio_file is required.")

        filename = audio_file.filename or "audio.webm"
        content_type = audio_file.content_type or "application/octet-stream"
        self._validate_audio_metadata(filename, content_type)

        audio_bytes = await self._read_limited_upload(audio_file)
        self._validate_audio_size(
            audio_bytes,
            filename=filename,
            content_type=content_type,
        )
        self._validate_audio_signature(filename, audio_bytes)

        provider = self.provider
        provider_name = self._provider_name(provider)
        logger.info(
            "Voice STT stage=upload status=validated provider=%s filename=%r content_type=%s byte_length=%s",
            provider_name,
            filename,
            content_type,
            len(audio_bytes),
        )
        result = await provider.transcribe_audio(
            filename=filename,
            content_type=content_type,
            audio_bytes=audio_bytes,
        )
        transcript = self.normalize_text(result.text)
        if not transcript:
            logger.warning(
                "Voice STT stage=transcription status=empty provider=%s filename=%r content_type=%s byte_length=%s",
                provider_name,
                filename,
                content_type,
                len(audio_bytes),
            )
            raise ValidationException("STT returned an empty transcript.")
        logger.info(
            "Voice STT stage=transcription status=success provider=%s filename=%r byte_length=%s transcript_chars=%s",
            provider_name,
            filename,
            len(audio_bytes),
            len(transcript),
        )
        return VoiceTranscriptionResult(text=transcript)

    async def synthesize_response(self, text: str) -> VoiceAudioResponse:
        """AI 응답 텍스트를 base64 오디오로 변환"""
        normalized_text = self.normalize_text(text)
        if not normalized_text:
            raise ValidationException("TTS input text is empty.")

        if len(normalized_text) > settings.tts_max_input_chars:
            raise ValidationException(
                f"TTS input text exceeds {settings.tts_max_input_chars} characters."
            )

        result = await self.provider.synthesize_speech(text=normalized_text)
        max_output_bytes = settings.tts_max_output_mb * 1024 * 1024
        if len(result.audio_bytes) > max_output_bytes:
            raise ValidationException(
                f"TTS output exceeds {settings.tts_max_output_mb} MB.",
                details={"max_output_mb": settings.tts_max_output_mb},
            )
        return VoiceAudioResponse(
            content_type=result.content_type,
            base64=base64.b64encode(result.audio_bytes).decode("ascii"),
            format=result.format,
        )

    def _validate_audio_metadata(self, filename: str, content_type: str) -> None:
        extension = Path(filename).suffix.lower()
        if extension not in self.supported_extensions:
            raise ValidationException(
                "Unsupported audio file type.",
                details={
                    "content_type": content_type,
                    "extension": extension,
                    "supported_extensions": sorted(self.supported_extensions),
                },
            )
        if content_type not in self.supported_content_types and content_type != self.octet_stream_content_type:
            raise ValidationException(
                "Unsupported audio content type.",
                details={
                    "content_type": content_type,
                    "supported_content_types": sorted(self.supported_content_types),
                },
            )

    async def _read_limited_upload(self, audio_file: UploadedAudio | UploadFile) -> bytes:
        max_bytes = settings.voice_max_upload_mb * 1024 * 1024
        chunk_size = 1024 * 1024
        total = 0
        chunks: list[bytes] = []

        while True:
            chunk = await audio_file.read(chunk_size)
            if not chunk:
                break
            total += len(chunk)
            if total > max_bytes:
                raise ValidationException(
                    f"audio_file exceeds {settings.voice_max_upload_mb} MB.",
                    details={"max_upload_mb": settings.voice_max_upload_mb},
                )
            chunks.append(chunk)

        return b"".join(chunks)

    def _validate_audio_size(
        self,
        audio_bytes: bytes,
        *,
        filename: str,
        content_type: str,
    ) -> None:
        if not audio_bytes:
            raise ValidationException("audio_file is empty.")
        if len(audio_bytes) < self.minimum_audio_bytes:
            logger.warning(
                "Voice STT stage=upload status=rejected reason=too_small filename=%r "
                "content_type=%s byte_length=%s minimum_byte_length=%s",
                filename,
                content_type,
                len(audio_bytes),
                self.minimum_audio_bytes,
            )
            raise ValidationException(
                "audio_file is too small.",
                details={
                    "byte_length": len(audio_bytes),
                    "minimum_byte_length": self.minimum_audio_bytes,
                },
            )
        max_bytes = settings.voice_max_upload_mb * 1024 * 1024
        if len(audio_bytes) > max_bytes:
            raise ValidationException(
                f"audio_file exceeds {settings.voice_max_upload_mb} MB.",
                details={"max_upload_mb": settings.voice_max_upload_mb},
            )

    def _validate_audio_signature(self, filename: str, audio_bytes: bytes) -> None:
        extension = Path(filename).suffix.lower()
        header = audio_bytes[:32]
        valid = False

        if extension == ".wav":
            valid = header.startswith(b"RIFF") and b"WAVE" in header[:16]
        elif extension == ".flac":
            valid = header.startswith(b"fLaC")
        elif extension == ".ogg":
            valid = header.startswith(b"OggS")
        elif extension == ".webm":
            valid = header.startswith(b"\x1A\x45\xDF\xA3")
        elif extension in {".mp4", ".m4a"}:
            valid = b"ftyp" in header[:16]
        elif extension in {".mp3", ".mpeg", ".mpga"}:
            valid = header.startswith(b"ID3") or (
                len(header) >= 2 and header[0] == 0xFF and (header[1] & 0xE0) == 0xE0
            )

        if not valid:
            raise ValidationException(
                "Invalid audio file signature.",
                details={"extension": extension},
            )

    def _provider_name(self, provider: VoiceProvider) -> str:
        get_provider_name = getattr(provider, "get_provider_name", None)
        if callable(get_provider_name):
            return str(get_provider_name())
        return provider.__class__.__name__

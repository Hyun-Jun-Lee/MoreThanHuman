"""
Voice 도메인 Pydantic 스키마 정의
"""
from enum import Enum

from pydantic import BaseModel


class VoiceInputMode(str, Enum):
    """대화 입력 모드"""

    TEXT = "text"
    AUDIO = "audio"


class VoiceAudioResponse(BaseModel):
    """TTS 오디오 응답"""

    content_type: str
    base64: str
    format: str


class VoiceAudioError(BaseModel):
    """TTS 생성 실패 정보"""

    message: str
    provider: str | None = None


class VoiceTranscriptionResult(BaseModel):
    """STT 변환 결과"""

    text: str


class VoiceSynthesisResult(BaseModel):
    """TTS 생성 결과"""

    audio_bytes: bytes
    content_type: str
    format: str

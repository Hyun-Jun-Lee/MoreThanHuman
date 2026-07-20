"""
Voice Provider Base Interface
"""
from abc import ABC, abstractmethod

from domains.voice.schemas import VoiceSynthesisResult, VoiceTranscriptionResult


class VoiceProvider(ABC):
    """STT/TTS Provider 추상 인터페이스"""

    @abstractmethod
    async def transcribe_audio(
        self,
        *,
        filename: str,
        content_type: str,
        audio_bytes: bytes,
    ) -> VoiceTranscriptionResult:
        """음성 파일을 텍스트로 변환"""
        pass

    @abstractmethod
    async def synthesize_speech(self, *, text: str) -> VoiceSynthesisResult:
        """텍스트를 음성으로 변환"""
        pass

    @abstractmethod
    def get_provider_name(self) -> str:
        """Provider 이름 반환"""
        pass

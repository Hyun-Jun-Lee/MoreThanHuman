"""
LLM Provider Base Interface
Abstract base class for all LLM providers
"""
from abc import ABC, abstractmethod

from domains.llm.models import LLMRequest, LLMResponse


class LLMProvider(ABC):
    """LLM Provider 추상 인터페이스"""

    @abstractmethod
    async def chat_completion(self, request: LLMRequest) -> LLMResponse:
        """
        채팅 완료 요청

        Args:
            request: LLM 요청 파라미터

        Returns:
            LLM 응답

        Raises:
            RateLimitException: Rate limit 도달
            ExternalAPIException: API 호출 실패
        """
        pass

    @abstractmethod
    def validate_config(self) -> bool:
        """
        Provider 설정 검증

        Returns:
            설정이 유효한지 여부
        """
        pass

    @abstractmethod
    def get_provider_name(self) -> str:
        """
        Provider 이름 반환

        Returns:
            Provider 이름
        """
        pass

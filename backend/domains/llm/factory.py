"""
LLM Provider Factory
Dynamic provider selection based on configuration
"""
from enum import Enum

from config import get_settings
from domains.llm.ollama import OllamaProvider
from domains.llm.openrouter import OpenRouterProvider
from domains.llm.provider import LLMProvider
from shared.exceptions import AppException

settings = get_settings()


class LLMProviderType(str, Enum):
    """지원하는 LLM Provider 타입"""

    OPENROUTER = "openrouter"
    OLLAMA = "ollama"


class LLMProviderFactory:
    """LLM Provider Factory"""

    _providers: dict[LLMProviderType, type[LLMProvider]] = {
        LLMProviderType.OPENROUTER: OpenRouterProvider,
        LLMProviderType.OLLAMA: OllamaProvider,
    }

    @classmethod
    def create_provider(cls, provider_type: str | None = None) -> LLMProvider:
        """
        Provider 생성

        Args:
            provider_type: Provider 타입 (None이면 설정값 사용)

        Returns:
            LLM Provider 인스턴스

        Raises:
            AppException: 지원하지 않는 Provider 타입
        """
        # Use config value if not specified
        provider_name = provider_type or settings.llm_provider

        try:
            provider_enum = LLMProviderType(provider_name.lower())
        except ValueError:
            supported = ", ".join([p.value for p in LLMProviderType])
            raise AppException(
                f"지원하지 않는 LLM Provider: {provider_name}. "
                f"지원 목록: {supported}"
            )

        provider_class = cls._providers[provider_enum]
        provider = provider_class()

        # Validate configuration
        if not provider.validate_config():
            raise AppException(
                f"{provider.get_provider_name()} provider 설정이 올바르지 않습니다. "
                f"환경 변수를 확인해주세요."
            )

        return provider

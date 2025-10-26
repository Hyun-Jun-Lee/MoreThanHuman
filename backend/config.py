"""
환경 변수 및 애플리케이션 설정 관리
"""
from functools import lru_cache
from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """애플리케이션 설정"""

    # Database
    database_url: str = None

    # External APIs
    openrouter_api_key: str
    tavily_api_key: str

    # Application
    debug: bool = False
    cors_origins: list[str] = ["http://localhost:5173"]

    # LLM Provider Settings
    llm_provider: str
    ollama_base_url: str

    # OpenRouter Model Settings
    openrouter_model: str

    # Ollama Model Settings
    ollama_model: str

    # Common LLM Settings
    max_tokens: int = 4000
    temperature: float = 0.7

    # Conversation Settings
    max_history_turns: int = 10

    class Config:
        # 프로젝트 루트의 .env 파일 경로 (backend/config.py 기준 상위 디렉토리)
        env_file = str(Path(__file__).parent.parent / ".env")
        case_sensitive = False


@lru_cache
def get_settings() -> Settings:
    """설정 싱글톤 인스턴스 반환"""
    return Settings()


def get_model_for_provider(provider: str | None = None) -> str:
    """
    현재 Provider에 맞는 모델 반환

    Args:
        provider: Provider 타입 (None이면 설정값 사용)

    Returns:
        Provider에 맞는 모델명
    """
    settings = get_settings()
    current_provider = provider or settings.llm_provider

    if current_provider == "ollama":
        return settings.ollama_model
    else:  # openrouter
        return settings.openrouter_model

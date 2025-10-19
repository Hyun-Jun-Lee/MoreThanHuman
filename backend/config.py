"""
환경 변수 및 애플리케이션 설정 관리
"""
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """애플리케이션 설정"""

    # Database
    database_url: str

    # External APIs
    openrouter_api_key: str
    tavily_api_key: str

    # Application
    debug: bool = False
    cors_origins: list[str] = ["http://localhost:5173"]

    # LLM Settings
    llm_model: str = "google/gemini-2.0-flash-exp:free"
    llm_fallback_model: str = "deepseek/deepseek-chat"
    max_tokens: int = 2000
    temperature: float = 0.7

    # Conversation Settings
    max_history_turns: int = 10

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache
def get_settings() -> Settings:
    """설정 싱글톤 인스턴스 반환"""
    return Settings()

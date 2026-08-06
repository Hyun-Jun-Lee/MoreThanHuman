"""
환경 변수 및 애플리케이션 설정 관리
"""
from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings
from shared.exceptions import AppException


class Settings(BaseSettings):
    """애플리케이션 설정"""

    # Database
    database_url: str = None

    # External APIs
    openrouter_api_key: str
    openai_api_key: str | None = None

    # Application
    env: str = "prod"
    debug: bool = False
    cors_origins: list[str] = []

    # LLM Provider Settings
    llm_provider: str = "openrouter"
    ollama_base_url: str | None = None

    # OpenRouter Model Settings
    openrouter_model: str

    # Ollama Model Settings
    ollama_model: str | None = None

    # Grammar Check Model Settings (separate from conversation model)
    grammar_model_provider: str = None  # If None, uses llm_provider
    grammar_openrouter_model: str | None = None  # If None, uses openrouter_model
    grammar_ollama_model: str | None = None  # If None, uses ollama_model

    # Auth / JWT
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 1440  # 24시간
    jwt_refresh_token_expire_days: int = 15

    # Supabase Auth
    supabase_url: str | None = None
    supabase_publishable_key: str | None = None
    supabase_auth_verify_mode: Literal["remote"] = "remote"
    supabase_auth_timeout_seconds: float = 5.0
    auto_create_tables: bool = False

    # Google OAuth2
    google_client_id: str | None = None
    google_client_secret: str | None = None
    google_redirect_uri: str = "http://localhost:8010/api/auth/google/callback"

    # Common LLM Settings
    max_tokens: int = 4000
    temperature: float = 0.7

    # Search Settings
    search_summary_max_tokens: int = 600
    search_query_analysis_max_tokens: int = 500
    search_quality_judge_max_tokens: int = 500
    search_region: str = "kr-kr"
    search_safesearch: str = "moderate"
    search_recent_timelimit: str = "m"
    search_backend: str = "auto"
    search_max_results: int = 12
    search_min_relevant_results: int = 2

    # Conversation Settings
    max_history_turns: int = 10

    # Voice Settings
    stt_provider: str = "openrouter"
    stt_model: str = "openai/gpt-4o-mini-transcribe"
    tts_provider: str = "openrouter"
    tts_model: str = "microsoft/mai-voice-2-flash"
    tts_voice: str = "en-US-Harper:MAI-Voice-2-Flash"
    tts_response_format: str = "mp3"
    tts_max_input_chars: int = 4000
    tts_max_output_mb: int = 5
    voice_max_upload_mb: int = 10
    voice_provider_timeout_seconds: float = 60.0

    @property
    def is_dev(self) -> bool:
        """개발 전용 기능 활성화 여부"""
        return self.env.lower() in {"dev", "development", "local"}

    @property
    def normalized_supabase_url(self) -> str:
        """후행 slash가 제거된 Supabase project URL"""
        if not self.supabase_url or not self.supabase_url.strip():
            raise AppException("SUPABASE_URL is required for Supabase Auth.")
        return self.supabase_url.strip().rstrip("/")

    @property
    def supabase_auth_url(self) -> str:
        """Supabase Auth base URL"""
        return f"{self.normalized_supabase_url}/auth/v1"

    @property
    def supabase_jwks_url(self) -> str:
        """Supabase JWKS discovery URL"""
        return f"{self.supabase_auth_url}/.well-known/jwks.json"

    @property
    def required_supabase_publishable_key(self) -> str:
        """Supabase publishable key 필수값"""
        if not self.supabase_publishable_key or not self.supabase_publishable_key.strip():
            raise AppException("SUPABASE_PUBLISHABLE_KEY is required for Supabase Auth.")
        return self.supabase_publishable_key.strip()

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
        if not settings.ollama_model:
            raise AppException("OLLAMA_MODEL is required when LLM_PROVIDER=ollama.")
        return settings.ollama_model
    return settings.openrouter_model


def get_grammar_model_config() -> tuple[str, str]:
    """
    문법 체크용 모델 설정 반환

    Returns:
        (provider, model) 튜플
    """
    settings = get_settings()

    # 문법 전용 provider 설정이 있으면 사용, 없으면 기본 provider 사용
    provider = settings.grammar_model_provider or settings.llm_provider

    if provider == "ollama":
        if not settings.ollama_model:
            raise AppException("OLLAMA_MODEL is required when GRAMMAR_MODEL_PROVIDER=ollama.")
        model = settings.grammar_ollama_model or settings.ollama_model
    else:  # openrouter
        model = settings.grammar_openrouter_model or settings.openrouter_model

    return provider, model

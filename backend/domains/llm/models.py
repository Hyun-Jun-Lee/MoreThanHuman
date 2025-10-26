"""
LLM Provider Models
Shared types for LLM requests and responses
"""
from typing import Any
from pydantic import BaseModel


class LLMMessage(BaseModel):
    """단일 LLM 메시지"""

    role: str  # "system", "user", "assistant"
    content: str


class LLMRequest(BaseModel):
    """LLM 요청 파라미터"""

    messages: list[LLMMessage]
    model: str
    max_tokens: int = 2000
    temperature: float = 0.7
    extra_params: dict[str, Any] | None = None


class LLMResponse(BaseModel):
    """LLM 응답"""

    content: str
    model: str | None = None
    usage: dict[str, Any] | None = None

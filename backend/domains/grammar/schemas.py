"""
Grammar 도메인 Pydantic 스키마 정의
"""
from datetime import datetime, timezone
from uuid import UUID

from pydantic import BaseModel, Field

from domains.grammar.enums import ErrorType


class GrammarError(BaseModel):
    """문법 에러"""

    type: ErrorType
    original: str
    corrected: str
    explanation: str
    position: dict[str, int]  # {"start": int, "end": int}


class GrammarFeedback(BaseModel):
    """문법 피드백"""

    id: UUID
    message_id: UUID
    original_text: str
    corrected_text: str
    has_errors: bool
    errors: list[GrammarError]
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Config:
        from_attributes = True


class GrammarAnalysis(BaseModel):
    """문법 분석 결과"""

    has_errors: bool
    errors: list[GrammarError]
    corrected_sentence: str
    overall_quality: float  # 0-1 scale


class GrammarStats(BaseModel):
    """문법 통계"""

    total_messages: int
    messages_with_errors: int
    error_rate: float
    common_errors: list[dict]
    improvement_trend: list[dict]

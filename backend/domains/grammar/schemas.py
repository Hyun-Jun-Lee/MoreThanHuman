"""
Grammar 도메인 Pydantic 스키마 정의
"""
from datetime import datetime, timezone
from uuid import UUID

from pydantic import BaseModel, Field


class GrammarError(BaseModel):
    """문법 에러 (간소화)"""

    original: str
    corrected: str
    explanation: str


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
    """문법 분석 결과 (간소화)"""

    has_errors: bool
    errors: list[GrammarError]
    corrected_sentence: str


class GrammarStats(BaseModel):
    """문법 통계"""

    total_messages: int
    messages_with_errors: int
    error_rate: float
    common_errors: list[dict]
    improvement_trend: list[dict]

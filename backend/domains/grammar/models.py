"""
Grammar 도메인 모델 정의
"""
from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel
from sqlalchemy import Boolean, Column, DateTime, Enum as SQLEnum, ForeignKey, JSON, String, Text
from sqlalchemy.orm import relationship

from database import Base


# Enums
class ErrorType(str, Enum):
    """에러 타입"""

    GRAMMAR = "grammar"
    WORD_CHOICE = "word_choice"
    EXPRESSION = "expression"
    SPELLING = "spelling"
    PUNCTUATION = "punctuation"


# SQLAlchemy Models
class GrammarFeedbackModel(Base):
    """문법 피드백 테이블"""

    __tablename__ = "grammar_feedback"

    id = Column(String(36), primary_key=True)  # UUID를 문자열로 저장
    message_id = Column(String(36), ForeignKey("messages.id"), unique=True, nullable=False)
    original_text = Column(Text, nullable=False)
    corrected_text = Column(Text, nullable=False)
    has_errors = Column(Boolean, default=False, nullable=False)
    errors = Column(JSON, default=list, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    message = relationship("MessageModel", back_populates="grammar_feedback")


# Pydantic Models
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
    created_at: datetime

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

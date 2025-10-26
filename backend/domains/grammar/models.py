"""
Grammar 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, JSON, String, Text
from sqlalchemy.orm import relationship

from database import Base


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

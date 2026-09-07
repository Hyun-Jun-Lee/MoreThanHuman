"""Language snack 도메인 SQLAlchemy 모델 정의."""
from datetime import datetime

from sqlalchemy import Column, DateTime, Index, String, Text

from database import Base


class LanguageSnackModel(Base):
    """Home에 노출할 공통 언어 지식 카드."""

    __tablename__ = "language_snacks"
    __table_args__ = (Index("ix_language_snacks_published_at_id", "published_at", "id"),)

    id = Column(String(36), primary_key=True)
    category = Column(String(40), nullable=False)
    left_label = Column(String(48), nullable=False)
    left_word = Column(String(80), nullable=False)
    right_label = Column(String(48), nullable=False)
    right_word = Column(String(80), nullable=False)
    meaning = Column(String(160), nullable=False)
    example = Column(String(240), nullable=False)
    published_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

"""
Auth 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, String
from sqlalchemy.orm import relationship

from database import Base
from shared.language import DEFAULT_LANGUAGE_CONTEXT, LearningLanguageContext, language_context_from_values


class ProfileModel(Base):
    """앱 사용자 프로필 테이블"""

    __tablename__ = "profiles"

    id = Column(String(36), primary_key=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    oauth_provider = Column(String(50), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    native_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.native_language.value, nullable=False)
    target_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.target_language.value, nullable=False)
    feedback_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.feedback_language.value, nullable=False)
    app_locale = Column(String(2), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    conversations = relationship("ConversationModel", back_populates="user", cascade="all, delete-orphan")

    @property
    def language(self) -> LearningLanguageContext:
        """프로필 저장값을 검증된 언어 컨텍스트로 반환"""
        return language_context_from_values(
            native_language=self.native_language,
            target_language=self.target_language,
            feedback_language=self.feedback_language,
        )

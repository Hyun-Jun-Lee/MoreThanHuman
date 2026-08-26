"""
Conversation 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, Enum as SQLEnum, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import relationship

from database import Base
from domains.auth.models import ProfileModel  # noqa: F401 - SQLAlchemy relationship registration
from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole, RoleplayDifficulty
from domains.grammar.models import GrammarFeedbackModel  # noqa: F401 - SQLAlchemy relationship registration
from shared.language import DEFAULT_LANGUAGE_CONTEXT, LearningLanguageContext, language_context_from_values


class ConversationModel(Base):
    """대화 테이블"""

    __tablename__ = "conversations"

    id = Column(String(36), primary_key=True)  # UUID를 문자열로 저장
    user_id = Column(String(36), ForeignKey("profiles.id"), nullable=False, index=True)
    title = Column(String(200), nullable=True)  # 대화 제목 (첫 질문)
    conversation_type = Column(SQLEnum(ConversationType), default=ConversationType.FREE_CHAT, nullable=False)  # 대화 타입
    role_character = Column(String(500), nullable=True)  # 롤플레이 캐릭터/상황 설명
    roleplay_difficulty = Column(SQLEnum(RoleplayDifficulty), nullable=True)  # 롤플레이 난이도
    native_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.native_language.value, nullable=False)
    target_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.target_language.value, nullable=False)
    feedback_language = Column(String(8), default=DEFAULT_LANGUAGE_CONTEXT.feedback_language.value, nullable=False)
    message_count = Column(Integer, default=0, nullable=False)
    status = Column(SQLEnum(ConversationStatus), default=ConversationStatus.ACTIVE, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("ProfileModel", back_populates="conversations")
    messages = relationship("MessageModel", back_populates="conversation", cascade="all, delete-orphan")

    @property
    def language(self) -> LearningLanguageContext:
        """대화 시작 시점의 언어 스냅샷"""
        return language_context_from_values(
            native_language=self.native_language,
            target_language=self.target_language,
            feedback_language=self.feedback_language,
        )


class MessageModel(Base):
    """메시지 테이블"""

    __tablename__ = "messages"

    id = Column(String(36), primary_key=True)  # UUID를 문자열로 저장
    conversation_id = Column(String(36), ForeignKey("conversations.id"), nullable=False)
    role = Column(SQLEnum(MessageRole), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    conversation = relationship("ConversationModel", back_populates="messages")
    grammar_feedback = relationship("GrammarFeedbackModel", back_populates="message", uselist=False, cascade="all, delete-orphan")

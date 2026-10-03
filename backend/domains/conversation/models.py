"""
Conversation 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import Column, Date, DateTime, Enum as SQLEnum, ForeignKey, Index, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from database import Base
from domains.auth.models import ProfileModel  # noqa: F401 - SQLAlchemy relationship registration
from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole
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


class ConversationSlotGrantModel(Base):
    """검증된 영구 단품 구매가 부여한 대화 슬롯."""

    __tablename__ = "conversation_slot_grants"

    id = Column(String(36), primary_key=True)
    user_id = Column(String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    purchase_key = Column(String(255), nullable=False, unique=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    revoked_at = Column(DateTime, nullable=True)


class WeeklyTopicBatchModel(Base):
    __tablename__ = "weekly_topic_batches"
    __table_args__ = (UniqueConstraint("native_language", "target_language", "week_start", name="uq_weekly_topic_batch_pair_week"),)

    id = Column(String(36), primary_key=True)
    native_language = Column(String(8), nullable=False)
    target_language = Column(String(8), nullable=False)
    week_start = Column(Date, nullable=False)
    published_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    topics = relationship("WeeklyTopicModel", back_populates="batch", cascade="all, delete-orphan")


class WeeklyTopicModel(Base):
    __tablename__ = "weekly_topics"

    id = Column(String(36), primary_key=True)
    batch_id = Column(String(36), ForeignKey("weekly_topic_batches.id", ondelete="CASCADE"), nullable=False, index=True)
    text = Column(String(200), nullable=False)
    first_question = Column(String(300), nullable=True)
    position = Column(Integer, nullable=False)
    archived_at = Column(DateTime, nullable=True)
    batch = relationship("WeeklyTopicBatchModel", back_populates="topics")


class SuggestedStartModel(Base):
    __tablename__ = "suggested_starts"
    __table_args__ = (UniqueConstraint("user_id", "request_id", name="uq_suggested_start_user_request"),)

    id = Column(String(36), primary_key=True)
    user_id = Column(String(36), ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    request_id = Column(String(36), nullable=False)
    topic_id = Column(String(36), ForeignKey("weekly_topics.id"), nullable=False)
    status = Column(String(16), nullable=False, default="pending")
    conversation_id = Column(String(36), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=True)
    assistant_message_id = Column(String(36), ForeignKey("messages.id", ondelete="CASCADE"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

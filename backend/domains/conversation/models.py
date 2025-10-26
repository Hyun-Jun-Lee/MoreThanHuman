"""
Conversation 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, Enum as SQLEnum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database import Base
from domains.conversation.enums import ConversationStatus, MessageRole


class ConversationModel(Base):
    """대화 테이블"""

    __tablename__ = "conversations"

    id = Column(String(36), primary_key=True)  # UUID를 문자열로 저장
    title = Column(String(200), nullable=True)  # 대화 제목 (첫 질문)
    message_count = Column(Integer, default=0, nullable=False)
    status = Column(SQLEnum(ConversationStatus), default=ConversationStatus.ACTIVE, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    messages = relationship("MessageModel", back_populates="conversation", cascade="all, delete-orphan")


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

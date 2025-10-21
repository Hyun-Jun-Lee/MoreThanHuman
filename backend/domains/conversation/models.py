"""
Conversation 도메인 모델 정의
"""
from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Enum as SQLEnum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from database import Base


# Enums
class ConversationStatus(str, Enum):
    """대화 상태"""

    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"


class MessageRole(str, Enum):
    """메시지 역할"""

    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


# SQLAlchemy Models
class ConversationModel(Base):
    """대화 테이블"""

    __tablename__ = "conversations"

    id = Column(String(36), primary_key=True)  # UUID를 문자열로 저장
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


# Pydantic Models
class Conversation(BaseModel):
    """대화 스키마"""

    id: UUID
    message_count: int
    status: ConversationStatus
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class Message(BaseModel):
    """메시지 스키마"""

    id: UUID
    conversation_id: UUID
    role: MessageRole
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class ConversationResponse(BaseModel):
    """대화 시작 응답"""

    conversation_id: UUID
    response: str
    grammar_feedback: dict | None = None


class MessageResponse(BaseModel):
    """메시지 응답"""

    message_id: UUID
    response: str
    grammar_feedback: dict | None = None
    turn_count: int

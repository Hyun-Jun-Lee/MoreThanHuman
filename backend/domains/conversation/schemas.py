"""
Conversation 도메인 Pydantic 스키마 정의
"""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel

from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole


class Conversation(BaseModel):
    """대화 스키마"""

    id: UUID
    title: str | None = None
    conversation_type: ConversationType
    role_character: str | None = None
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
    grammar_feedback: dict | None = None  # GrammarFeedback relationship

    class Config:
        from_attributes = True


class ConversationResponse(BaseModel):
    """대화 시작 응답"""

    conversation_id: UUID
    message_id: UUID  # 사용자 메시지 ID (SSE 연결용)
    conversation_type: ConversationType
    role_character: str | None = None
    response: str
    grammar_feedback: dict | None = None


class MessageResponse(BaseModel):
    """메시지 응답"""

    message_id: UUID
    response: str
    grammar_feedback: dict | None = None
    turn_count: int

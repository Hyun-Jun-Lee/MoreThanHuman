"""
Conversation 도메인 Pydantic 스키마 정의
"""
from datetime import datetime
from typing import Generic, TypeVar
from uuid import UUID

from pydantic import BaseModel, Field

from domains.conversation.enums import (
    ConversationStatus,
    ConversationType,
    FreeChatConversationDirection,
    MessageRole,
    RoleplayDifficulty,
)
from domains.voice.schemas import VoiceAudioError, VoiceAudioResponse, VoiceInputMode
from shared.language import LearningLanguageContext

SchemaType = TypeVar("SchemaType")


class StartFreeChatRequest(BaseModel):
    """자유 대화 시작 요청"""

    first_message: str
    search_context: str | None = None
    topic: str | None = None
    conversation_direction: FreeChatConversationDirection | None = None
    selected_question: str | None = None
    custom_focus: str | None = Field(default=None, min_length=2, max_length=200)


class StartRoleplayRequest(BaseModel):
    """롤플레이 대화 시작 요청"""

    role_character: str
    roleplay_difficulty: RoleplayDifficulty = RoleplayDifficulty.NORMAL
    search_context: str | None = None
    include_audio_response: bool = False


class SendMessageRequest(BaseModel):
    """메시지 전송 요청"""

    message: str


class UpdateTitleRequest(BaseModel):
    """대화 제목 수정 요청"""

    title: str


class Conversation(BaseModel):
    """대화 스키마"""

    id: UUID
    title: str | None = None
    conversation_type: ConversationType
    role_character: str | None = None
    roleplay_difficulty: RoleplayDifficulty | None = None
    language: LearningLanguageContext = Field(default_factory=LearningLanguageContext)
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
    roleplay_difficulty: RoleplayDifficulty | None = None
    language: LearningLanguageContext = Field(default_factory=LearningLanguageContext)
    response: str
    grammar_feedback: dict | None = None


class MessageResponse(BaseModel):
    """메시지 응답"""

    message_id: UUID
    response: str
    grammar_feedback: dict | None = None
    turn_count: int


class MultimodalConversationResponse(ConversationResponse):
    """멀티모달 대화 시작 응답"""

    input_mode: VoiceInputMode = VoiceInputMode.TEXT
    transcript: str | None = None
    audio: VoiceAudioResponse | None = None
    audio_error: VoiceAudioError | None = None


class MultimodalMessageResponse(MessageResponse):
    """멀티모달 메시지 응답"""

    input_mode: VoiceInputMode = VoiceInputMode.TEXT
    transcript: str | None = None
    audio: VoiceAudioResponse | None = None
    audio_error: VoiceAudioError | None = None


class Pagination(BaseModel):
    """offset 기반 페이지 메타"""

    limit: int
    offset: int
    total_count: int
    has_more: bool
    next_offset: int


class PaginatedResponse(BaseModel, Generic[SchemaType]):
    """results/pagination 구조"""

    results: list[SchemaType]
    pagination: Pagination


class PaginatedConversations(PaginatedResponse[Conversation]):
    """대화 목록 페이지 응답"""


class PaginatedMessages(PaginatedResponse[Message]):
    """메시지 목록 페이지 응답"""

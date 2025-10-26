"""
Conversation 도메인 Enum 정의
"""
from enum import Enum


class ConversationStatus(str, Enum):
    """대화 상태"""

    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"


class MessageRole(str, Enum):
    """메시지 역할"""

    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"

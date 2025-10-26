"""
Conversation Repository Layer
데이터 접근 및 CRUD 연산
"""
from sqlalchemy import desc
from sqlalchemy.orm import Session

from domains.conversation.enums import ConversationStatus
from domains.conversation.models import ConversationModel, MessageModel
from shared.exceptions import NotFoundException


class ConversationRepository:
    """대화 저장소"""

    def __init__(self, db: Session):
        self.db = db

    def save(self, conversation: ConversationModel) -> ConversationModel:
        """
        대화 저장

        Args:
            conversation: 대화 모델

        Returns:
            저장된 대화
        """
        self.db.add(conversation)
        self.db.commit()
        self.db.refresh(conversation)
        return conversation

    def find_by_id(self, conversation_id: str) -> ConversationModel:
        """
        ID로 대화 조회

        Args:
            conversation_id: 대화 ID

        Returns:
            대화 모델

        Raises:
            NotFoundException: 대화를 찾을 수 없을 때
        """
        conversation = self.db.query(ConversationModel).filter(ConversationModel.id == conversation_id).first()
        if not conversation:
            raise NotFoundException(f"Conversation {conversation_id} not found")
        return conversation

    def find_all(self, limit: int = 50, offset: int = 0) -> list[ConversationModel]:
        """
        모든 대화 조회

        Args:
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            대화 목록
        """
        return (
            self.db.query(ConversationModel)
            .order_by(desc(ConversationModel.created_at))
            .limit(limit)
            .offset(offset)
            .all()
        )

    def update_status(self, conversation_id: str, status: ConversationStatus) -> None:
        """
        대화 상태 업데이트

        Args:
            conversation_id: 대화 ID
            status: 새로운 상태
        """
        conversation = self.find_by_id(conversation_id)
        conversation.status = status
        self.db.commit()

    def update_message_count(self, conversation_id: str, count: int) -> None:
        """
        메시지 카운트 업데이트

        Args:
            conversation_id: 대화 ID
            count: 메시지 개수
        """
        conversation = self.find_by_id(conversation_id)
        conversation.message_count = count
        self.db.commit()

    def delete_by_id(self, conversation_id: str) -> None:
        """
        대화 삭제

        Args:
            conversation_id: 대화 ID
        """
        conversation = self.find_by_id(conversation_id)
        self.db.delete(conversation)
        self.db.commit()

    # Message operations
    def save_message(self, message: MessageModel) -> MessageModel:
        """
        메시지 저장

        Args:
            message: 메시지 모델

        Returns:
            저장된 메시지
        """
        self.db.add(message)
        self.db.commit()
        self.db.refresh(message)
        return message

    def find_message_by_id(self, message_id: str) -> MessageModel:
        """
        ID로 메시지 조회

        Args:
            message_id: 메시지 ID

        Returns:
            메시지 모델

        Raises:
            NotFoundException: 메시지를 찾을 수 없을 때
        """
        message = self.db.query(MessageModel).filter(MessageModel.id == message_id).first()
        if not message:
            raise NotFoundException(f"Message {message_id} not found")
        return message

    def get_messages(self, conversation_id: str, limit: int = 50, offset: int = 0) -> list[MessageModel]:
        """
        대화의 메시지 조회

        Args:
            conversation_id: 대화 ID
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            메시지 목록
        """
        return (
            self.db.query(MessageModel)
            .filter(MessageModel.conversation_id == conversation_id)
            .order_by(MessageModel.created_at)
            .limit(limit)
            .offset(offset)
            .all()
        )

    def get_recent_messages(self, conversation_id: str, turn_count: int = 10) -> list[MessageModel]:
        """
        최근 N턴의 메시지 조회

        Args:
            conversation_id: 대화 ID
            turn_count: 조회할 턴 개수

        Returns:
            최근 메시지 목록
        """
        return (
            self.db.query(MessageModel)
            .filter(MessageModel.conversation_id == conversation_id)
            .order_by(desc(MessageModel.created_at))
            .limit(turn_count * 2)  # user + assistant
            .all()
        )[::-1]  # 시간순 정렬

    def delete_message(self, message_id: str) -> None:
        """
        메시지 삭제

        Args:
            message_id: 메시지 ID
        """
        message = self.find_message_by_id(message_id)
        self.db.delete(message)
        self.db.commit()

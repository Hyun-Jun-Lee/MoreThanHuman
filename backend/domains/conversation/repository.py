"""
Conversation Repository Layer
데이터 접근 및 CRUD 연산
"""
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

from domains.conversation.enums import ConversationStatus
from domains.auth.models import ProfileModel
from domains.conversation.enums import MessageRole
from domains.conversation.models import ConversationModel, ConversationSlotGrantModel, MessageModel
from shared.exceptions import AppException, NotFoundException


class ConversationSlotsFull(AppException):
    """새 대화의 동시 보유 슬롯이 없어요."""


class ConversationTurnsFull(AppException):
    """대화별 무료 사용자 발화 한도에 도달했어요."""


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

    def _slot_limit(self, profile: ProfileModel) -> int:
        grants = (
            self.db.query(func.count(ConversationSlotGrantModel.id))
            .filter(
                ConversationSlotGrantModel.user_id == profile.id,
                ConversationSlotGrantModel.revoked_at.is_(None),
            )
            .scalar()
        ) or 0
        return max(1, profile.legacy_conversation_slots or 1) + grants

    def access_summary(self, user_id: str, *, enabled: bool) -> dict:
        """홈과 대화 탭에서 동일하게 사용하는 생성 권한."""
        used = self.count_conversations(user_id)
        if not enabled:
            return {
                "enabled": False,
                "can_create": True,
                "used_slots": used,
                "slot_limit": None,
                "remaining_slots": None,
            }
        profile = self.db.query(ProfileModel).filter(ProfileModel.id == user_id).one()
        limit = self._slot_limit(profile)
        return {
            "enabled": True,
            "can_create": used < limit,
            "used_slots": used,
            "slot_limit": limit,
            "remaining_slots": max(0, limit - used),
        }

    def assert_can_create(self, user_id: str, *, enabled: bool) -> None:
        if enabled and not self.access_summary(user_id, enabled=True)["can_create"]:
            raise ConversationSlotsFull("추가 대화 이용권이 필요해요")

    def create_with_access(self, conversation: ConversationModel, *, enabled: bool) -> ConversationModel:
        """프로필 행 잠금 아래에서 슬롯 검사와 새 대화 INSERT를 직렬화해요."""
        if not enabled:
            return self.save(conversation)
        try:
            profile = (
                self.db.query(ProfileModel)
                .filter(ProfileModel.id == conversation.user_id)
                .with_for_update()
                .one()
            )
            used = self.count_conversations(conversation.user_id)
            if used >= self._slot_limit(profile):
                raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            self.db.add(conversation)
            self.db.commit()
            self.db.refresh(conversation)
            return conversation
        except Exception:
            self.db.rollback()
            raise

    def count_user_turns(self, conversation_id: str) -> int:
        return (
            self.db.query(func.count(MessageModel.id))
            .filter(MessageModel.conversation_id == conversation_id, MessageModel.role == MessageRole.USER)
            .scalar()
        ) or 0

    def turn_access(self, conversation_id: str, user_id: str, *, enabled: bool) -> dict:
        self.find_by_id(conversation_id, user_id)
        used = self.count_user_turns(conversation_id)
        return {
            "enabled": enabled,
            "user_turns": used,
            "turn_limit": 15 if enabled else None,
            "can_send": not enabled or used < 15,
        }

    def assert_can_send(self, conversation_id: str, user_id: str, *, enabled: bool) -> None:
        if enabled and not self.turn_access(conversation_id, user_id, enabled=True)["can_send"]:
            raise ConversationTurnsFull("이 대화의 무료 15턴을 모두 사용했어요")

    def save_user_turn(self, message: MessageModel, user_id: str, *, enabled: bool) -> MessageModel:
        """대화 행 잠금 아래에서 사용자 발화 수와 INSERT를 원자적으로 처리해요."""
        if not enabled:
            return self.save_message(message)
        try:
            conversation = (
                self.db.query(ConversationModel)
                .filter(ConversationModel.id == message.conversation_id, ConversationModel.user_id == user_id)
                .with_for_update()
                .one_or_none()
            )
            if conversation is None:
                raise NotFoundException(f"Conversation {message.conversation_id} not found")
            if self.count_user_turns(conversation.id) >= 15:
                raise ConversationTurnsFull("이 대화의 무료 15턴을 모두 사용했어요")
            self.db.add(message)
            self.db.commit()
            self.db.refresh(message)
            return message
        except Exception:
            self.db.rollback()
            raise

    def delete_failed_user_turn(self, message_id: str) -> None:
        message = self.db.query(MessageModel).filter(MessageModel.id == message_id).one_or_none()
        if message is not None:
            self.db.delete(message)
            self.db.commit()

    def find_by_id(self, conversation_id: str, user_id: str) -> ConversationModel:
        """
        ID로 대화 조회 (user_id 검증 포함)

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID

        Returns:
            대화 모델

        Raises:
            NotFoundException: 대화를 찾을 수 없을 때
        """
        conversation = (
            self.db.query(ConversationModel)
            .filter(ConversationModel.id == conversation_id, ConversationModel.user_id == user_id)
            .first()
        )
        if not conversation:
            raise NotFoundException(f"Conversation {conversation_id} not found")
        return conversation

    def find_all(self, user_id: str, limit: int = 50, offset: int = 0) -> list[ConversationModel]:
        """
        사용자의 대화 목록 조회

        Args:
            user_id: 사용자 ID
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            대화 목록
        """
        return (
            self.db.query(ConversationModel)
            .filter(ConversationModel.user_id == user_id)
            .order_by(desc(ConversationModel.updated_at))
            .limit(limit)
            .offset(offset)
            .all()
        )

    def count_conversations(self, user_id: str) -> int:
        """사용자의 전체 대화 수 조회"""
        return self.db.query(ConversationModel).filter(ConversationModel.user_id == user_id).count()

    def update_status(self, conversation_id: str, user_id: str, status: ConversationStatus) -> None:
        """
        대화 상태 업데이트

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
            status: 새로운 상태
        """
        conversation = self.find_by_id(conversation_id, user_id)
        conversation.status = status
        self.db.commit()

    def update_message_count(self, conversation_id: str, user_id: str, count: int) -> None:
        """
        메시지 카운트 업데이트

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
            count: 메시지 개수
        """
        conversation = self.find_by_id(conversation_id, user_id)
        conversation.message_count = count
        self.db.commit()

    def update_title(self, conversation_id: str, user_id: str, title: str) -> None:
        """
        대화 제목 업데이트

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
            title: 새로운 제목
        """
        conversation = self.find_by_id(conversation_id, user_id)
        conversation.title = title
        self.db.commit()

    def delete_by_id(self, conversation_id: str, user_id: str) -> None:
        """
        대화 삭제

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
        """
        conversation = self.find_by_id(conversation_id, user_id)
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

    def ensure_message_belongs_to_user(self, message_id: str, user_id: str) -> None:
        """
        메시지가 사용자의 대화에 속하는지 확인

        Args:
            message_id: 메시지 ID
            user_id: 사용자 ID

        Raises:
            NotFoundException: 메시지가 없거나 사용자 소유가 아닐 때
        """
        message = (
            self.db.query(MessageModel)
            .join(ConversationModel, MessageModel.conversation_id == ConversationModel.id)
            .filter(MessageModel.id == message_id, ConversationModel.user_id == user_id)
            .first()
        )
        if not message:
            raise NotFoundException(f"Message {message_id} not found")

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
        from sqlalchemy.orm import joinedload

        return (
            self.db.query(MessageModel)
            .options(joinedload(MessageModel.grammar_feedback))
            .filter(MessageModel.conversation_id == conversation_id)
            .order_by(MessageModel.created_at)
            .limit(limit)
            .offset(offset)
            .all()
        )

    def count_messages(self, conversation_id: str) -> int:
        """대화의 전체 메시지 수 조회"""
        return self.db.query(MessageModel).filter(MessageModel.conversation_id == conversation_id).count()

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

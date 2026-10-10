"""
Conversation Repository Layer
데이터 접근 및 CRUD 연산
"""
from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy import desc, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.conversation.enums import ConversationStatus
from domains.auth.models import ProfileModel
from domains.conversation.enums import MessageRole
from domains.conversation.models import ConversationModel, MessageModel, StreamTurnModel, SuggestedStartModel, WeeklyTopicModel
from domains.conversation.stream_turns import StreamTurnStore
from shared.exceptions import AppException, NotFoundException
from shared.subscription import entitlement_for_user


class ConversationSlotsFull(AppException):
    """새 대화의 동시 보유 슬롯이 없어요."""


class ConversationTurnsFull(AppException):
    """대화별 무료 사용자 발화 한도에 도달했어요."""


class ConversationLocked(AppException):
    """읽기 전용 대화예요."""


class SuggestedStartInProgress(AppException):
    """같은 요청 ID가 아직 AI의 첫 질문을 생성 중이에요."""


class PreviousTurnUnresolved(AppException):
    """이전 사용자 발화의 AI 응답을 먼저 복구해야 해요."""


class ConversationRepository:
    """대화 저장소"""

    def __init__(self, db: Session):
        self.db = db

    def completed_suggested_start(self, user_id: str, request_id: str, topic_id: str) -> SuggestedStartModel | None:
        """완료된 요청은 주제 보관 후에도 같은 결과로 재조회해요."""
        existing = self.db.query(SuggestedStartModel).filter_by(
            user_id=user_id, request_id=request_id, status="completed"
        ).one_or_none()
        if existing is not None and existing.topic_id != topic_id:
            raise AppException("같은 요청 ID로 다른 주제를 시작할 수 없어요")
        return existing

    def reserve_suggested_start(self, user_id: str, request_id: str, topic_id: str) -> tuple[SuggestedStartModel, bool]:
        """요청 ID를 영속적으로 예약하고, 완료 요청은 재조회해요."""
        existing = self.db.query(SuggestedStartModel).filter_by(user_id=user_id, request_id=request_id).one_or_none()
        if existing is not None:
            if existing.topic_id != topic_id:
                raise AppException("같은 요청 ID로 다른 주제를 시작할 수 없어요")
            if existing.status == "completed":
                return existing, True
            # 중단된 프로세스의 예약은 제한 시간 뒤 재시도할 수 있어요.
            if existing.created_at < datetime.utcnow() - timedelta(minutes=5):
                self.db.delete(existing)
                self.db.commit()
            else:
                raise SuggestedStartInProgress("대화를 준비하고 있어요")
        reservation = SuggestedStartModel(
            id=str(uuid4()), user_id=user_id, request_id=request_id, topic_id=topic_id,
            status="pending", created_at=datetime.utcnow(),
        )
        try:
            self.db.add(reservation)
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            existing = self.db.query(SuggestedStartModel).filter_by(user_id=user_id, request_id=request_id).one()
            if existing.topic_id != topic_id:
                raise AppException("같은 요청 ID로 다른 주제를 시작할 수 없어요")
            if existing.status == "completed":
                return existing, True
            raise SuggestedStartInProgress("대화를 준비하고 있어요")
        return reservation, False

    def complete_suggested_start(self, reservation_id: str, conversation: ConversationModel, message: MessageModel, *, enabled: bool) -> None:
        """슬롯 검사와 대화·AI 메시지·예약 완료를 한 트랜잭션에 저장해요."""
        try:
            profile = self.db.query(ProfileModel).filter_by(id=conversation.user_id).with_for_update().one()
            reservation = self.db.query(SuggestedStartModel).filter_by(id=reservation_id, status="pending").one_or_none()
            if reservation is None:
                raise SuggestedStartInProgress("요청이 재시도 중이에요")
            topic = self.db.query(WeeklyTopicModel).filter_by(
                id=reservation.topic_id, archived_at=None
            ).with_for_update().one_or_none()
            if (topic is None or topic.batch.native_language != profile.native_language
                    or topic.batch.target_language != profile.target_language):
                raise NotFoundException("추천 주제를 찾을 수 없어요")
            if enabled:
                entitlement = self._reconcile_slots_locked(profile)
            if enabled and (
                self.count_active_conversations(conversation.user_id)
                + self.count_pending_roleplay_starts(conversation.user_id)
            ) >= entitlement["slot_limit"]:
                raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            conversation.slot_active = enabled
            self.db.add(conversation)
            self.db.flush()
            self.db.add(message)
            self.db.flush()
            reservation.status = "completed"
            reservation.conversation_id = conversation.id
            reservation.assistant_message_id = message.id
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

    def release_suggested_start(self, reservation_id: str) -> None:
        reservation = self.db.query(SuggestedStartModel).filter_by(id=reservation_id, status="pending").one_or_none()
        if reservation is not None:
            self.db.delete(reservation)
            self.db.commit()

    def suggested_result(self, reservation: SuggestedStartModel) -> tuple[ConversationModel, MessageModel]:
        conversation = self.db.query(ConversationModel).filter_by(id=reservation.conversation_id).one()
        message = self.db.query(MessageModel).filter_by(
            id=reservation.assistant_message_id, conversation_id=conversation.id,
            role=MessageRole.ASSISTANT,
        ).one_or_none()
        if message is None:
            raise NotFoundException("첫 AI 메시지를 찾을 수 없어요")
        return conversation, message

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

    def _reconcile_slots_locked(self, profile: ProfileModel) -> dict:
        """프로필 행 잠금 아래에서 플랜 변경을 활성 슬롯에 반영해요."""
        entitlement = entitlement_for_user(self.db, profile.id)
        limit = entitlement["slot_limit"]
        if profile.slot_limit_snapshot == limit:
            return entitlement
        last_user_turn = (
            select(func.max(MessageModel.created_at))
            .where(MessageModel.conversation_id == ConversationModel.id, MessageModel.role == MessageRole.USER)
            .correlate(ConversationModel)
            .scalar_subquery()
        )
        conversations = (
            self.db.query(ConversationModel)
            .filter_by(user_id=profile.id)
            .order_by(desc(last_user_turn), desc(ConversationModel.updated_at), desc(ConversationModel.id))
            .all()
        )
        active = [conversation for conversation in conversations if conversation.slot_active]
        if profile.slot_limit_snapshot is None:
            selected = {conversation.id for conversation in conversations[:limit]}
        elif len(active) > limit:
            selected = {conversation.id for conversation in active[:limit]}
        elif limit > profile.slot_limit_snapshot:
            selected = {conversation.id for conversation in active}
            selected.update(conversation.id for conversation in conversations if conversation.id not in selected and len(selected) < limit)
        else:
            selected = {conversation.id for conversation in active}
        for conversation in conversations:
            conversation.slot_active = conversation.id in selected
        profile.slot_limit_snapshot = limit
        self.db.flush()
        return entitlement

    def _locked_entitlement(self, user_id: str) -> tuple[ProfileModel, dict]:
        profile = self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one()
        return profile, self._reconcile_slots_locked(profile)

    def count_active_conversations(self, user_id: str) -> int:
        return self.db.query(ConversationModel).filter_by(user_id=user_id, slot_active=True).count()

    def count_pending_roleplay_starts(self, user_id: str) -> int:
        return self.db.query(StreamTurnModel).filter(
            StreamTurnModel.user_id == user_id,
            StreamTurnModel.kind == "roleplay_start",
            StreamTurnModel.status == "pending",
            StreamTurnModel.deadline_at >= datetime.utcnow(),
        ).count()

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
                "locked_count": 0,
            }
        _, entitlement = self._locked_entitlement(user_id)
        limit = entitlement["slot_limit"]
        active_count = self.count_active_conversations(user_id)
        used = active_count + self.count_pending_roleplay_starts(user_id)
        active = self.db.query(ConversationModel).filter_by(user_id=user_id, slot_active=True).order_by(desc(ConversationModel.updated_at)).all()
        self.db.commit()
        return {
            "enabled": True,
            "can_create": used < limit,
            "used_slots": used,
            "slot_limit": limit,
            "remaining_slots": max(0, limit - used),
            "locked_count": max(0, self.count_conversations(user_id) - active_count),
            "plan": entitlement["plan"],
            "active_conversations": [{"id": conversation.id, "title": conversation.title or "Untitled conversation"} for conversation in active],
        }

    def assert_can_create(self, user_id: str, *, enabled: bool) -> None:
        if enabled and not self.access_summary(user_id, enabled=True)["can_create"]:
            raise ConversationSlotsFull("추가 대화 이용권이 필요해요")

    def create_with_access(self, conversation: ConversationModel, *, enabled: bool) -> ConversationModel:
        """프로필 행 잠금 아래에서 슬롯 검사와 새 대화 INSERT를 직렬화해요."""
        if not enabled:
            return self.save(conversation)
        try:
            _, entitlement = self._locked_entitlement(conversation.user_id)
            used = self.count_active_conversations(conversation.user_id) + self.count_pending_roleplay_starts(conversation.user_id)
            if used >= entitlement["slot_limit"]:
                raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            conversation.slot_active = True
            self.db.add(conversation)
            self.db.commit()
            self.db.refresh(conversation)
            return conversation
        except Exception:
            self.db.rollback()
            raise

    def create_stream_free_chat(
        self, conversation: ConversationModel, user_message: MessageModel,
        *, turn_id: str, enabled: bool,
    ) -> None:
        """새 대화·확정 발화·turn 연결을 한 트랜잭션에 저장해요."""
        try:
            if enabled:
                _, entitlement = self._locked_entitlement(conversation.user_id)
                used = (self.count_active_conversations(conversation.user_id)
                        + self.count_pending_roleplay_starts(conversation.user_id))
                if used >= entitlement["slot_limit"]:
                    raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            turn = self.db.query(StreamTurnModel).filter_by(
                id=turn_id, user_id=conversation.user_id, status="pending",
            ).with_for_update().one()
            conversation.slot_active = enabled
            conversation.message_count = 1
            self.db.add(conversation)
            self.db.flush()
            self.db.add(user_message)
            self.db.flush()
            turn.conversation_id = conversation.id
            turn.user_message_id = user_message.id
            self.db.commit()
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
        if enabled:
            _, entitlement = self._locked_entitlement(user_id)
        else:
            entitlement = {"turn_limit": None}
        conversation = self.find_by_id(conversation_id, user_id)
        used = self.count_user_turns(conversation_id)
        locked = enabled and not conversation.slot_active
        limit = entitlement["turn_limit"]
        if enabled:
            self.db.commit()
        return {
            "enabled": enabled,
            "user_turns": used,
            "turn_limit": limit,
            "can_send": not locked and (limit is None or used < limit),
            "locked": locked,
        }

    def assert_can_send(self, conversation_id: str, user_id: str, *, enabled: bool) -> None:
        if enabled:
            access = self.turn_access(conversation_id, user_id, enabled=True)
            if access["locked"]:
                raise ConversationLocked("읽기 전용 대화예요")
            if not access["can_send"]:
                raise ConversationTurnsFull("이 대화의 무료 15턴을 모두 사용했어요")

    def assert_no_unresolved_turn(
        self, conversation_id: str, user_id: str, *, exclude_turn_id: str | None = None
    ) -> None:
        candidates = self.db.query(StreamTurnModel).filter(
            StreamTurnModel.user_id == user_id,
            StreamTurnModel.conversation_id == conversation_id,
            StreamTurnModel.status.in_(["pending", "failed"]),
        ).all()
        store = StreamTurnStore(self.db)
        for candidate in candidates:
            if candidate.id == exclude_turn_id:
                continue
            current = store.get(user_id, candidate.id)
            if current.status in {"pending", "failed"}:
                raise PreviousTurnUnresolved("이전 답변을 재시도하거나 상태를 확인해 주세요")

    def save_user_turn(
        self, message: MessageModel, user_id: str, *, enabled: bool,
        stream_turn_id: str | None = None,
    ) -> MessageModel:
        """대화 행 잠금 아래에서 사용자 발화 수와 INSERT를 원자적으로 처리해요."""
        self.assert_no_unresolved_turn(message.conversation_id, user_id,
                                       exclude_turn_id=stream_turn_id)
        if not enabled:
            try:
                self.db.add(message)
                if stream_turn_id:
                    self.db.flush()
                    turn = self.db.query(StreamTurnModel).filter_by(
                        id=stream_turn_id, user_id=user_id, status="pending",
                    ).with_for_update().one()
                    turn.user_message_id = message.id
                self.db.commit()
                self.db.refresh(message)
                return message
            except Exception:
                self.db.rollback()
                raise
        try:
            _, entitlement = self._locked_entitlement(user_id)
            conversation = (
                self.db.query(ConversationModel)
                .filter(ConversationModel.id == message.conversation_id, ConversationModel.user_id == user_id)
                .with_for_update()
                .one_or_none()
            )
            if conversation is None:
                raise NotFoundException(f"Conversation {message.conversation_id} not found")
            if not conversation.slot_active:
                raise ConversationLocked("읽기 전용 대화예요")
            limit = entitlement["turn_limit"]
            if limit is not None and self.count_user_turns(conversation.id) >= limit:
                raise ConversationTurnsFull("이 대화의 무료 15턴을 모두 사용했어요")
            self.db.add(message)
            if stream_turn_id:
                self.db.flush()
                turn = self.db.query(StreamTurnModel).filter_by(
                    id=stream_turn_id, user_id=user_id, status="pending",
                ).with_for_update().one()
                turn.user_message_id = message.id
            self.db.commit()
            self.db.refresh(message)
            return message
        except Exception:
            self.db.rollback()
            raise

    def activate_conversation(self, conversation_id: str, user_id: str, replace_id: str | None) -> None:
        try:
            _, entitlement = self._locked_entitlement(user_id)
            conversation = self.find_by_id(conversation_id, user_id)
            if conversation.slot_active:
                self.db.commit()
                return
            if (self.count_active_conversations(user_id)
                    + self.count_pending_roleplay_starts(user_id)) >= entitlement["slot_limit"]:
                if replace_id is None or replace_id == conversation_id:
                    raise ConversationSlotsFull("교체할 활성 대화를 선택해 주세요")
                replacing = self.find_by_id(replace_id, user_id)
                if not replacing.slot_active:
                    raise ConversationSlotsFull("교체할 대화가 활성 상태가 아니에요")
                replacing.slot_active = False
            conversation.slot_active = True
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise

    def deactivate_conversation(self, conversation_id: str, user_id: str) -> None:
        try:
            self._locked_entitlement(user_id)
            self.find_by_id(conversation_id, user_id).slot_active = False
            self.db.commit()
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

    def delete_by_id(self, conversation_id: str, user_id: str) -> list[str]:
        """
        대화 삭제

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
        """
        conversation = self.find_by_id(conversation_id, user_id)
        message_ids = [message.id for message in conversation.messages]
        self.db.query(SuggestedStartModel).filter_by(
            conversation_id=conversation_id, user_id=user_id
        ).delete(synchronize_session=False)
        self.db.delete(conversation)
        self.db.commit()
        return message_ids

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

    def completed_audio_message_ids(self, message_ids: list[str]) -> set[str]:
        if not message_ids:
            return set()
        return {message_id for (message_id,) in self.db.query(
            StreamTurnModel.assistant_message_id,
        ).filter(StreamTurnModel.assistant_message_id.in_(message_ids),
                 StreamTurnModel.status == "completed").all()}

    def existing_message_ids(self, message_ids: list[str]) -> set[str]:
        if not message_ids:
            return set()
        return {message_id for (message_id,) in self.db.query(MessageModel.id).filter(
            MessageModel.id.in_(message_ids),
        ).all()}

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

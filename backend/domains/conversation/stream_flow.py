"""대화 스트림의 발화 확정, 프롬프트 구성, 완료 저장을 관리해요."""

import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from uuid import uuid4

import httpx
from sqlalchemy.orm import Session

from config import get_settings
from database import SessionLocal
from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole
from domains.conversation.models import ConversationModel, MessageModel, StreamAttemptModel, StreamTurnModel
from domains.conversation.repository import ConversationRepository, ConversationSlotsFull, GuestTurnsFull, PreviousTurnUnresolved
from domains.conversation.service import ConversationService, free_chat_title
from domains.conversation.stream_turns import StreamTurnConflict, StreamTurnStore
from shared.background_tasks import BackgroundTaskRegistry
from shared.language import LearningLanguageContext, language_context_from_values, language_context_to_dict, language_name
from shared.latency import latency_span
from shared.logging_config import log_event

settings = get_settings()


@dataclass(frozen=True)
class PreparedGeneration:
    turn_id: str
    attempt_id: str
    conversation_id: str | None
    user_message_id: str | None
    user_text: str | None
    input_mode: str | None
    system_prompt: str
    history: list[dict]
    prompt: str
    fixed_answer: str | None = None


def _language(data: dict) -> LearningLanguageContext:
    values = data["language"]
    return language_context_from_values(**values)


def _prepare_existing_turn(
    *, db: Session, store: StreamTurnStore, repository: ConversationRepository,
    service: ConversationService, user_id: str, request_id: str, kind: str,
    input_data: dict, background_tasks: BackgroundTaskRegistry,
    access_enabled: bool, nickname: str | None,
) -> PreparedGeneration:
    """기존 대화의 검사·이력 조회·예약·발화를 한 커밋으로 확정해요."""
    conversation_id = input_data["conversation_id"]
    user_text = input_data["text"]
    prepared: PreparedGeneration | None = None
    committed = False
    try:
        with latency_span("stream_precheck", operation=kind):
            with latency_span("stream_precheck.access", operation=kind):
                conversation = repository.lock_sendable_conversation(
                    conversation_id, user_id,
                    enabled=access_enabled, operation=kind,
                )
            with latency_span("stream_precheck.unresolved", operation=kind):
                try:
                    repository.assert_no_unresolved_turn(conversation_id, user_id)
                except PreviousTurnUnresolved:
                    if db.in_transaction():
                        db.commit()  # 검사 중 발생한 슬롯 재조정은 보존해요.
                    raise

        language = conversation.language
        with latency_span("stream_context.history_before", operation=kind):
            previous = repository.get_recent_messages(conversation_id, settings.max_history_turns)
            prior_assistant = next((item.content for item in reversed(previous)
                                    if item.role == MessageRole.ASSISTANT), None)
        with latency_span("stream_context.prompt", operation=kind):
            system_prompt = service.build_system_prompt(
                None, conversation.conversation_type, conversation.role_character,
                language_context=language, nickname=nickname,
            )
            history = service.prepare_message_history(previous)

        with latency_span("stream_reserve", operation=kind):
            try:
                turn = store.reserve(
                    user_id=user_id, request_id=request_id, kind=kind,
                    input_data=input_data, commit=False,
                )
            except StreamTurnConflict:
                if db.in_transaction():
                    db.commit()  # 이미 확정된 요청에도 슬롯 재조정 결과는 유지해요.
                raise
        with latency_span("stream_context.user_message", operation=kind):
            user_message = MessageModel(
                id=str(uuid4()), conversation_id=conversation_id,
                role=MessageRole.USER, content=user_text,
            )
            db.add(user_message)
            db.flush()
            if access_enabled:
                repository.reserve_guest_turn(
                    user_id,
                    request_key=user_message.id,
                    conversation_id=conversation_id,
                )
            turn.user_message_id = user_message.id
            prepared = PreparedGeneration(
                turn_id=turn.id, attempt_id=turn.attempt_id,
                conversation_id=conversation_id, user_message_id=user_message.id,
                user_text=user_text, input_mode=input_data.get("input_mode"),
                system_prompt=system_prompt, history=history, prompt=user_text,
            )
            db.commit()
            committed = True

        background_tasks.start(service.process_grammar_feedback_background(
            prepared.user_message_id, user_text, prior_assistant, language_context=language,
        ))
        return prepared
    except Exception:
        if not committed:
            db.rollback()
        elif prepared is not None:
            store.fail(prepared.turn_id, "PREPARATION_FAILED", attempt_id=prepared.attempt_id)
        raise


def prepare_generation(
    *, user_id: str, request_id: str, kind: str | None, input_data: dict | None,
    http_client: httpx.AsyncClient, background_tasks: BackgroundTaskRegistry,
    retry_turn_id: str | None = None,
    nickname: str | None = None,
) -> PreparedGeneration:
    """생성 전 입력과 사용자 발화를 확정하고 DB 연결을 닫아요."""
    with SessionLocal() as db:
        store = StreamTurnStore(db)
        repository = ConversationRepository(db)
        service = ConversationService(repository, http_client=http_client, background_tasks=background_tasks)
        operation = kind or "retry"
        access_enabled = repository.access_enabled_for(
            user_id, configured=settings.conversation_access_enabled
        )
        if retry_turn_id is None and kind in {"turn", "message"}:
            assert input_data is not None
            return _prepare_existing_turn(
                db=db, store=store, repository=repository, service=service,
                user_id=user_id, request_id=request_id, kind=kind,
                input_data=input_data, background_tasks=background_tasks,
                access_enabled=access_enabled,
                nickname=nickname,
            )
        if retry_turn_id:
            with latency_span("stream_precheck", operation=operation):
                previous_turn = store.get(user_id, retry_turn_id)
                if previous_turn is None:
                    raise LookupError(retry_turn_id)
                if previous_turn.kind == "roleplay_start" and access_enabled:
                    profile, entitlement = repository._locked_entitlement(user_id)
                    if profile.is_guest and (
                        repository.count_guest_turns(user_id, include_reserved=True)
                        >= entitlement["turn_limit"]
                    ):
                        raise GuestTurnsFull("게스트 체험 5회를 모두 사용했어요")
                    if not profile.is_guest and entitlement.get("remaining_turns") == 0:
                        from shared.credit_ledger import CreditsExhausted
                        raise CreditsExhausted("남은 AI 답변 횟수가 없어요")
                    reserved = (repository.count_active_conversations(user_id)
                                + repository.count_pending_roleplay_starts(user_id))
                    if entitlement["slot_limit"] is not None and reserved >= entitlement["slot_limit"]:
                        raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
                if previous_turn.user_message_id and access_enabled:
                    repository.reserve_guest_turn(
                        user_id,
                        request_key=previous_turn.user_message_id,
                        conversation_id=previous_turn.conversation_id,
                    )
            with latency_span("stream_reserve", operation=operation):
                turn = store.retry(user_id=user_id, turn_id=retry_turn_id, request_id=request_id)
            kind = turn.kind
            input_data = json.loads(turn.input_json)
        else:
            assert kind is not None and input_data is not None
            with latency_span("stream_precheck", operation=operation):
                conversation_id = input_data.get("conversation_id")
                if conversation_id:
                    with latency_span("stream_precheck.ownership", operation=operation):
                        conversation = repository.find_by_id(conversation_id, user_id)
                    with latency_span("stream_precheck.access", operation=operation):
                        repository.assert_can_send(conversation_id, user_id, enabled=access_enabled)
                    with latency_span("stream_precheck.unresolved", operation=operation):
                        unresolved = store.unresolved(user_id, conversation_id)
                    if any(item.status != "completed" for item in unresolved):
                        log_event(
                            "conversation.stream.conflict", source="precheck",
                            pending_count=sum(item.status == "pending" for item in unresolved),
                            failed_count=sum(item.status == "failed" for item in unresolved),
                        )
                        raise StreamTurnConflict("PREVIOUS_TURN_UNRESOLVED")
                elif kind == "free_chat_start":
                    repository.assert_can_create(user_id, enabled=access_enabled)
                elif kind == "roleplay_start" and access_enabled:
                    profile, entitlement = repository._locked_entitlement(user_id)
                    if profile.is_guest and (
                        repository.count_guest_turns(user_id, include_reserved=True)
                        >= entitlement["turn_limit"]
                    ):
                        raise GuestTurnsFull("게스트 체험 5회를 모두 사용했어요")
                    if not profile.is_guest and entitlement.get("remaining_turns") == 0:
                        from shared.credit_ledger import CreditsExhausted
                        raise CreditsExhausted("남은 AI 답변 횟수가 없어요")
                    reserved = (repository.count_active_conversations(user_id)
                                + repository.count_pending_roleplay_starts(user_id))
                    if entitlement["slot_limit"] is not None and reserved >= entitlement["slot_limit"]:
                        raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            with latency_span("stream_reserve", operation=operation):
                turn = store.reserve(user_id=user_id, request_id=request_id, kind=kind, input_data=input_data)

        try:
            user_text = input_data.get("text")
            input_mode = input_data.get("input_mode")
            if kind in {"turn", "message"}:
                with latency_span("stream_context.conversation", operation=operation):
                    conversation = repository.find_by_id(input_data["conversation_id"], user_id)
                    language = conversation.language
                if turn.user_message_id:
                    with latency_span("stream_context.user_message", operation=operation):
                        user_message = db.query(MessageModel).filter_by(
                            id=turn.user_message_id, conversation_id=conversation.id,
                            role=MessageRole.USER,
                        ).one()
                else:
                    with latency_span("stream_context.history_before", operation=operation):
                        previous = repository.get_recent_messages(conversation.id, settings.max_history_turns)
                    with latency_span("stream_context.user_message", operation=operation):
                        user_message = MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                                                    role=MessageRole.USER, content=user_text)
                        repository.save_user_turn(
                            user_message, user_id, enabled=access_enabled,
                            stream_turn_id=turn.id,
                        )
                    prior_assistant = next((item.content for item in reversed(previous)
                                            if item.role == MessageRole.ASSISTANT), None)
                    background_tasks.start(service.process_grammar_feedback_background(
                        user_message.id, user_text, prior_assistant, language_context=language,
                    ))
                with latency_span("stream_context.history_after", operation=operation):
                    previous = [item for item in repository.get_recent_messages(
                        conversation.id, settings.max_history_turns + 1
                    ) if item.id != user_message.id]
                with latency_span("stream_context.prompt", operation=operation):
                    system_prompt = service.build_system_prompt(
                        None, conversation.conversation_type, conversation.role_character,
                        language_context=language, nickname=nickname,
                    )
                    history = service.prepare_message_history(previous)
                conversation_id = conversation.id
                user_message_id = user_message.id
                prompt = user_text
            elif kind == "free_chat_start":
                language = _language(input_data)
                with latency_span("stream_context.user_message", operation=operation):
                    if turn.conversation_id:
                        conversation = repository.find_by_id(turn.conversation_id, user_id)
                        user_message = db.query(MessageModel).filter_by(id=turn.user_message_id).one()
                    else:
                        title = free_chat_title(input_data.get("topic"), user_text)
                        conversation = ConversationModel(
                            id=str(uuid4()), user_id=user_id, title=title,
                            conversation_type=ConversationType.FREE_CHAT,
                            role_character=None,
                            topic=input_data.get("topic"),
                            topic_summary=input_data.get("search_context"),
                            conversation_direction=input_data.get("conversation_direction"),
                            custom_focus=input_data.get("custom_focus"),
                            message_count=0, status=ConversationStatus.ACTIVE,
                            **language_context_to_dict(language),
                        )
                        user_message = MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                                                    role=MessageRole.USER, content=user_text)
                        repository.create_stream_free_chat(
                            conversation, user_message, turn_id=turn.id,
                            enabled=access_enabled,
                        )
                        background_tasks.start(service.process_grammar_feedback_background(
                            user_message.id, user_text, language_context=language,
                        ))
                with latency_span("stream_context.prompt", operation=operation):
                    system_prompt = service.build_system_prompt(
                        input_data.get("search_context"), ConversationType.FREE_CHAT, None,
                        topic=input_data.get("topic"),
                        conversation_direction=input_data.get("conversation_direction"),
                        selected_question=input_data.get("selected_question"),
                        custom_focus=input_data.get("custom_focus"),
                        language_context=language, nickname=nickname,
                    )
                conversation_id = conversation.id
                user_message_id = user_message.id
                history = []
                prompt = user_text
            elif kind == "roleplay_start":
                language = _language(input_data)
                role = input_data["role_character"]
                with latency_span("stream_context.prompt", operation=operation):
                    system_prompt = service.build_system_prompt(
                        input_data.get("search_context"), ConversationType.ROLE_PLAYING,
                        role, language_context=language, nickname=nickname,
                    )
                    prompt = (
                        f"You are starting a role-play as '{role}'. "
                        f"Greet the user naturally in {language_name(language.target_language)} "
                        "and start the conversation as this character would. Keep it short (1-2 sentences)."
                    )
                history = []
                conversation_id = None
                user_message_id = None
            else:
                raise ValueError(f"Unsupported stream kind: {kind}")
            return PreparedGeneration(
                turn_id=turn.id, attempt_id=turn.attempt_id,
                conversation_id=conversation_id, user_message_id=user_message_id,
                user_text=user_text, input_mode=input_mode, system_prompt=system_prompt,
                history=history, prompt=prompt,
                fixed_answer=(('안녕하세요! 먼저 말을 걸어 주세요.' if language.target_language.value == 'ko'
                               else 'Hello! Say something to begin our conversation.')
                              if kind == 'roleplay_start' else None),
            )
        except Exception:
            store.fail(turn.id, "PREPARATION_FAILED")
            raise


def complete_generated_text(user_id: str, prepared: PreparedGeneration, answer: str) -> tuple[str, str]:
    """assistant 메시지와 turn 완료를 같은 트랜잭션에 저장해요."""
    if not answer.strip():
        raise ValueError("Empty assistant text cannot commit a turn")
    with SessionLocal() as db:
        repository = ConversationRepository(db)
        access_enabled = repository.access_enabled_for(
            user_id, configured=settings.conversation_access_enabled
        )
        from shared.credit_ledger import CreditLedger, CreditsExhausted
        CreditLedger(db).lock(user_id)
        turn = db.query(StreamTurnModel).filter_by(
            id=prepared.turn_id, user_id=user_id, status="pending", attempt_id=prepared.attempt_id,
        ).with_for_update().one()
        if turn.deadline_at < datetime.utcnow():
            raise StreamTurnConflict('TURN_EXPIRED')
        if turn.kind == "roleplay_start":
            data = json.loads(turn.input_json)
            language = _language(data)
            role = data["role_character"]
            if access_enabled:
                profile, entitlement = repository._locked_entitlement(user_id)
                if profile.is_guest and (
                    repository.count_guest_turns(user_id, include_reserved=True)
                    >= entitlement["turn_limit"]
                ):
                    raise GuestTurnsFull("게스트 체험 5회를 모두 사용했어요")
                if not profile.is_guest and entitlement.get("remaining_turns") == 0:
                    raise CreditsExhausted("남은 AI 답변 횟수가 없어요")
                if (entitlement["slot_limit"] is not None
                        and repository.count_active_conversations(user_id)
                        + repository.count_pending_roleplay_starts(user_id) > entitlement["slot_limit"]):
                    raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            conversation = ConversationModel(
                id=str(uuid4()), user_id=user_id, title=role[:200],
                conversation_type=ConversationType.ROLE_PLAYING, role_character=role,
                message_count=1, status=ConversationStatus.ACTIVE,
                slot_active=access_enabled,
                **language_context_to_dict(language),
            )
            db.add(conversation)
            db.flush()
            turn.conversation_id = conversation.id
        else:
            conversation = db.query(ConversationModel).filter_by(
                id=turn.conversation_id, user_id=user_id,
            ).with_for_update().one()
            conversation.message_count = db.query(MessageModel).filter_by(
                conversation_id=conversation.id
            ).count() + 1
        assistant = MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                                 role=MessageRole.ASSISTANT, content=answer)
        db.add(assistant)
        db.flush()
        if turn.user_message_id:
            repository.commit_guest_turn(user_id, turn.user_message_id)
        now = datetime.utcnow()
        turn.assistant_message_id = assistant.id
        turn.status = "completed"
        turn.deadline_at = now + timedelta(minutes=5)
        turn.updated_at = now
        attempt = db.query(StreamAttemptModel).filter_by(id=turn.attempt_id).one()
        attempt.status = "completed"
        attempt.finished_at = now
        db.commit()
        return conversation.id, assistant.id

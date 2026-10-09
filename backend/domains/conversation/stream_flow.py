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
from domains.conversation.repository import ConversationRepository, ConversationSlotsFull
from domains.conversation.service import ConversationService
from domains.conversation.stream_turns import StreamTurnConflict, StreamTurnStore
from shared.background_tasks import BackgroundTaskRegistry
from shared.language import LearningLanguageContext, language_context_from_values, language_context_to_dict, language_name

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


def _language(data: dict) -> LearningLanguageContext:
    values = data["language"]
    return language_context_from_values(**values)


def prepare_generation(
    *, user_id: str, request_id: str, kind: str | None, input_data: dict | None,
    http_client: httpx.AsyncClient, background_tasks: BackgroundTaskRegistry,
    retry_turn_id: str | None = None,
) -> PreparedGeneration:
    """생성 전 입력과 사용자 발화를 확정하고 DB 연결을 닫아요."""
    with SessionLocal() as db:
        store = StreamTurnStore(db)
        repository = ConversationRepository(db)
        service = ConversationService(repository, http_client=http_client, background_tasks=background_tasks)
        if retry_turn_id:
            previous_turn = store.get(user_id, retry_turn_id)
            if previous_turn is None:
                raise LookupError(retry_turn_id)
            if previous_turn.kind == "roleplay_start" and settings.conversation_access_enabled:
                _, entitlement = repository._locked_entitlement(user_id)
                reserved = (repository.count_active_conversations(user_id)
                            + repository.count_pending_roleplay_starts(user_id))
                if reserved >= entitlement["slot_limit"]:
                    raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            turn = store.retry(user_id=user_id, turn_id=retry_turn_id, request_id=request_id)
            kind = turn.kind
            input_data = json.loads(turn.input_json)
        else:
            assert kind is not None and input_data is not None
            conversation_id = input_data.get("conversation_id")
            if conversation_id:
                conversation = repository.find_by_id(conversation_id, user_id)
                repository.assert_can_send(conversation_id, user_id, enabled=settings.conversation_access_enabled)
                if any(item.status != "completed" for item in store.unresolved(user_id, conversation_id)):
                    raise StreamTurnConflict("PREVIOUS_TURN_UNRESOLVED")
            elif kind == "free_chat_start":
                repository.assert_can_create(user_id, enabled=settings.conversation_access_enabled)
            elif kind == "roleplay_start" and settings.conversation_access_enabled:
                _, entitlement = repository._locked_entitlement(user_id)
                reserved = (repository.count_active_conversations(user_id)
                            + repository.count_pending_roleplay_starts(user_id))
                if reserved >= entitlement["slot_limit"]:
                    raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            turn = store.reserve(user_id=user_id, request_id=request_id, kind=kind, input_data=input_data)

        try:
            user_text = input_data.get("text")
            input_mode = input_data.get("input_mode")
            if kind in {"turn", "message"}:
                conversation = repository.find_by_id(input_data["conversation_id"], user_id)
                language = conversation.language
                if turn.user_message_id:
                    user_message = db.query(MessageModel).filter_by(
                        id=turn.user_message_id, conversation_id=conversation.id,
                        role=MessageRole.USER,
                    ).one()
                else:
                    previous = repository.get_recent_messages(conversation.id, settings.max_history_turns)
                    user_message = MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                                                role=MessageRole.USER, content=user_text)
                    repository.save_user_turn(
                        user_message, user_id, enabled=settings.conversation_access_enabled,
                        stream_turn_id=turn.id,
                    )
                    prior_assistant = next((item.content for item in reversed(previous)
                                            if item.role == MessageRole.ASSISTANT), None)
                    background_tasks.start(service.process_grammar_feedback_background(
                        user_message.id, user_text, prior_assistant, language_context=language,
                    ))
                previous = [item for item in repository.get_recent_messages(
                    conversation.id, settings.max_history_turns + 1
                ) if item.id != user_message.id]
                system_prompt = service.build_system_prompt(
                    None, conversation.conversation_type, conversation.role_character,
                    language_context=language,
                )
                history = service.prepare_message_history(previous)
                conversation_id = conversation.id
                user_message_id = user_message.id
                prompt = user_text
            elif kind == "free_chat_start":
                language = _language(input_data)
                if turn.conversation_id:
                    conversation = repository.find_by_id(turn.conversation_id, user_id)
                    user_message = db.query(MessageModel).filter_by(id=turn.user_message_id).one()
                else:
                    title = user_text[:47] + "..." if len(user_text) > 50 else user_text
                    conversation = ConversationModel(
                        id=str(uuid4()), user_id=user_id, title=title,
                        conversation_type=ConversationType.FREE_CHAT,
                        role_character=None, message_count=0, status=ConversationStatus.ACTIVE,
                        **language_context_to_dict(language),
                    )
                    user_message = MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                                                role=MessageRole.USER, content=user_text)
                    repository.create_stream_free_chat(
                        conversation, user_message, turn_id=turn.id,
                        enabled=settings.conversation_access_enabled,
                    )
                    background_tasks.start(service.process_grammar_feedback_background(
                        user_message.id, user_text, language_context=language,
                    ))
                system_prompt = service.build_system_prompt(
                    input_data.get("search_context"), ConversationType.FREE_CHAT, None,
                    topic=input_data.get("topic"),
                    conversation_direction=input_data.get("conversation_direction"),
                    selected_question=input_data.get("selected_question"),
                    custom_focus=input_data.get("custom_focus"),
                    language_context=language,
                )
                conversation_id = conversation.id
                user_message_id = user_message.id
                history = []
                prompt = user_text
            elif kind == "roleplay_start":
                language = _language(input_data)
                role = input_data["role_character"]
                system_prompt = service.build_system_prompt(
                    input_data.get("search_context"), ConversationType.ROLE_PLAYING,
                    role, language_context=language,
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
            )
        except Exception:
            store.fail(turn.id, "PREPARATION_FAILED")
            raise


def complete_generated_text(user_id: str, prepared: PreparedGeneration, answer: str) -> tuple[str, str]:
    """assistant 메시지와 turn 완료를 같은 트랜잭션에 저장해요."""
    with SessionLocal() as db:
        turn = db.query(StreamTurnModel).filter_by(
            id=prepared.turn_id, user_id=user_id, status="pending", attempt_id=prepared.attempt_id,
        ).with_for_update().one()
        if turn.kind == "roleplay_start":
            data = json.loads(turn.input_json)
            language = _language(data)
            role = data["role_character"]
            repository = ConversationRepository(db)
            if settings.conversation_access_enabled:
                _, entitlement = repository._locked_entitlement(user_id)
                if (repository.count_active_conversations(user_id)
                        + repository.count_pending_roleplay_starts(user_id) > entitlement["slot_limit"]):
                    raise ConversationSlotsFull("추가 대화 이용권이 필요해요")
            conversation = ConversationModel(
                id=str(uuid4()), user_id=user_id, title=role[:200],
                conversation_type=ConversationType.ROLE_PLAYING, role_character=role,
                message_count=1, status=ConversationStatus.ACTIVE,
                slot_active=settings.conversation_access_enabled,
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

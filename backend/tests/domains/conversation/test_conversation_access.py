from uuid import uuid4
import importlib

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole
from domains.conversation.models import ConversationModel, ConversationSlotGrantModel, MessageModel
from domains.conversation.repository import (
    ConversationRepository,
    ConversationLocked,
    ConversationSlotsFull,
    ConversationTurnsFull,
)
from domains.conversation.service import ConversationService
from scripts import initialize_conversation_slots


def _setup():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner"))
    db.commit()
    return ConversationRepository(db), user_id


def _conversation(user_id):
    return ConversationModel(
        id=str(uuid4()), user_id=user_id, conversation_type=ConversationType.FREE_CHAT
    )


def test_disabled_policy_preserves_unlimited_creation_and_reports_no_limit():
    repository, user_id = _setup()
    for _ in range(3):
        repository.create_with_access(_conversation(user_id), enabled=False)

    access = repository.access_summary(user_id, enabled=False)
    assert access == {
        "enabled": False,
        "can_create": True,
        "used_slots": 3,
        "slot_limit": None,
        "remaining_slots": None,
        "locked_count": 0,
    }


def test_free_slot_reopens_after_deletion_and_completed_conversations_count():
    repository, user_id = _setup()
    first = repository.create_with_access(_conversation(user_id), enabled=True)
    repository.update_status(first.id, user_id, ConversationStatus.COMPLETED)

    assert repository.access_summary(user_id, enabled=True)["can_create"] is False
    with pytest.raises(ConversationSlotsFull):
        repository.create_with_access(_conversation(user_id), enabled=True)

    repository.delete_by_id(first.id, user_id)
    repository.create_with_access(_conversation(user_id), enabled=True)
    assert repository.access_summary(user_id, enabled=True)["used_slots"] == 1


def test_legacy_allowance_and_permanent_grant_do_not_change_subscription_slots():
    repository, user_id = _setup()
    profile = repository.db.query(ProfileModel).filter_by(id=user_id).one()
    profile.legacy_conversation_slots = 3
    repository.db.commit()
    conversations = [repository.save(_conversation(user_id)) for _ in range(3)]
    assert repository.access_summary(user_id, enabled=True)["used_slots"] == 1
    with pytest.raises(ConversationSlotsFull):
        repository.create_with_access(_conversation(user_id), enabled=True)
    repository.db.add(
        ConversationSlotGrantModel(
            id=str(uuid4()), user_id=user_id, purchase_key="verified-store-purchase"
        )
    )
    repository.db.commit()
    assert repository.access_summary(user_id, enabled=True)["slot_limit"] == 1
    assert repository.access_summary(user_id, enabled=True)["locked_count"] == 2
    selected = repository.db.query(ConversationModel).filter_by(user_id=user_id, slot_active=True).one()
    replacement = next(item for item in conversations if item.id != selected.id)
    repository.activate_conversation(replacement.id, user_id, selected.id)
    assert repository.turn_access(selected.id, user_id, enabled=True)["locked"] is True
    repository.deactivate_conversation(replacement.id, user_id)
    repository.create_with_access(_conversation(user_id), enabled=True)


def test_each_conversation_stops_at_fifteen_user_turns():
    repository, user_id = _setup()
    first = repository.create_with_access(_conversation(user_id), enabled=True)
    second = repository.save(_conversation(user_id))
    for index in range(15):
        repository.save_user_turn(
            MessageModel(
                id=str(uuid4()),
                conversation_id=first.id,
                role=MessageRole.USER,
                content=f"turn {index}",
            ),
            user_id,
            enabled=True,
        )
    repository.save_message(
        MessageModel(
            id=str(uuid4()), conversation_id=first.id, role=MessageRole.ASSISTANT, content="Hello"
        )
    )
    assert repository.turn_access(first.id, user_id, enabled=True) == {
        "enabled": True,
        "user_turns": 15,
        "turn_limit": 15,
        "can_send": False,
        "locked": False,
    }
    with pytest.raises(ConversationTurnsFull):
        repository.save_user_turn(
            MessageModel(
                id=str(uuid4()), conversation_id=first.id, role=MessageRole.USER, content="extra"
            ),
            user_id,
            enabled=True,
        )
    assert repository.turn_access(second.id, user_id, enabled=True)["locked"] is True
    with pytest.raises(ConversationLocked):
        repository.save_user_turn(
            MessageModel(id=str(uuid4()), conversation_id=second.id, role=MessageRole.USER, content="locked"),
            user_id, enabled=True,
        )


def test_failed_turn_release_restores_allowance():
    repository, user_id = _setup()
    conversation = repository.save(_conversation(user_id))
    message = repository.save_user_turn(
        MessageModel(
            id=str(uuid4()), conversation_id=conversation.id, role=MessageRole.USER, content="retry"
        ),
        user_id,
        enabled=True,
    )
    repository.delete_failed_user_turn(message.id)
    assert repository.turn_access(conversation.id, user_id, enabled=True)["user_turns"] == 0


@pytest.mark.asyncio
async def test_turn_preparation_failure_does_not_consume_free_turn(monkeypatch):
    service_module = importlib.import_module("domains.conversation.service")
    repository, user_id = _setup()
    conversation = repository.save(_conversation(user_id))
    service = ConversationService(repository, background_tasks=object())
    monkeypatch.setattr(service_module.settings, "conversation_access_enabled", True)

    def fail_history(*_args):
        raise RuntimeError("history unavailable")

    monkeypatch.setattr(service, "prepare_message_history", fail_history)
    with pytest.raises(RuntimeError, match="history unavailable"):
        await service.continue_conversation(conversation.id, "Hello", user_id)

    assert repository.turn_access(conversation.id, user_id, enabled=True)["user_turns"] == 0


def test_initialization_selects_one_existing_conversation(monkeypatch):
    repository, user_id = _setup()
    first = repository.save(_conversation(user_id))
    repository.save(_conversation(user_id))
    monkeypatch.setattr(
        initialize_conversation_slots,
        "SessionLocal",
        sessionmaker(bind=repository.db.get_bind()),
    )

    assert initialize_conversation_slots.initialize() == 1
    repository.db.expire_all()
    profile = repository.db.query(ProfileModel).filter_by(id=user_id).one()
    assert profile.slot_limit_snapshot == 1
    assert repository.count_active_conversations(user_id) == 1

    repository.delete_by_id(first.id, user_id)
    assert initialize_conversation_slots.initialize() == 1
    repository.db.expire_all()
    assert repository.db.query(ProfileModel).filter_by(id=user_id).one().slot_limit_snapshot == 1


def test_api_returns_machine_readable_limit_conflicts(monkeypatch):
    router_module = importlib.import_module("domains.conversation.router")
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    user_id = str(uuid4())
    profile = ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner")
    db.add(profile)
    db.commit()
    repository = ConversationRepository(db)
    conversation = repository.save(_conversation(user_id))
    for index in range(15):
        repository.save_message(
            MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.USER,
                content=f"turn {index}",
            )
        )
    monkeypatch.setattr(router_module.settings, "conversation_access_enabled", True)
    app = FastAPI()
    app.include_router(router_module.router)
    app.dependency_overrides[router_module.get_current_user] = lambda: profile
    app.dependency_overrides[router_module.get_conversation_service] = (
        lambda: ConversationService(repository)
    )
    app.dependency_overrides[router_module.get_voice_service] = lambda: object()
    client = TestClient(app)

    access = client.get("/api/conversations/access/")
    assert access.status_code == 200
    assert access.json()["data"]["can_create"] is False
    assert access.json()["data"]["slot_limit"] == 1

    start = client.post(
        "/api/conversations/start/roleplay/", json={"role_character": "A barista"}
    )
    assert start.status_code == 409
    assert start.json()["detail"]["code"] == "CONVERSATION_SLOTS_FULL"

    turn = client.post(
        f"/api/conversations/{conversation.id}/turn/", json={"text": "one more"}
    )
    assert turn.status_code == 409
    assert turn.json()["detail"]["code"] == "CONVERSATION_TURNS_FULL"

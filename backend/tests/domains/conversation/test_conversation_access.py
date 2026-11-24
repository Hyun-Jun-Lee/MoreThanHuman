from datetime import datetime, timedelta
from uuid import uuid4
import importlib

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
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
    GuestTurnsFull,
)
from domains.conversation.service import ConversationService
from domains.conversation.stream_turns import StreamTurnStore
from shared.credit_ledger import CreditLedger, CreditsExhausted


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


def test_guest_turn_limit_is_account_wide_and_survives_conversation_deletion():
    repository, user_id = _setup()
    profile = repository.db.get(ProfileModel, user_id)
    profile.is_guest = True
    profile.email = None
    repository.db.commit()
    conversation = repository.create_with_access(_conversation(user_id), enabled=True)

    for index in range(5):
        user_message = repository.save_user_turn(
            MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.USER,
                content=f"guest turn {index}",
            ),
            user_id,
            enabled=True,
        )
        repository.save_assistant_turn(
            MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.ASSISTANT,
                content="response",
            ),
            user_id=user_id,
            user_message_id=user_message.id,
        )

    access = repository.turn_access(conversation.id, user_id, enabled=True)
    assert access == {
        "enabled": True,
        "user_turns": 5,
        "turn_limit": 5,
        "can_send": False,
        "locked": False,
        "turn_scope": "account",
        "remaining_turns": 0,
        "limit_action": "login",
    }
    assert repository.access_summary(user_id, enabled=True)["plan"] == "guest"

    repository.delete_by_id(conversation.id, user_id)
    with pytest.raises(GuestTurnsFull):
        repository.create_with_access(_conversation(user_id), enabled=True)
    assert repository.count_guest_turns(user_id) == 5


def test_guest_limits_stay_enabled_when_member_access_rollout_is_disabled():
    repository, user_id = _setup()
    profile = repository.db.get(ProfileModel, user_id)
    profile.is_guest = True
    profile.email = None
    repository.db.commit()

    conversation = repository.create_with_access(_conversation(user_id), enabled=False)
    access = repository.access_summary(user_id, enabled=False)
    assert access["enabled"] is True
    assert access["plan"] == "guest"
    assert access["slot_limit"] == 1
    assert access["remaining_turns"] == 5

    for index in range(5):
        user_message = repository.save_user_turn(
            MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.USER,
                content=f"guest rollout-independent turn {index}",
            ),
            user_id,
            enabled=False,
        )
        repository.save_assistant_turn(
            MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.ASSISTANT,
                content="response",
            ),
            user_id=user_id,
            user_message_id=user_message.id,
        )

    with pytest.raises(GuestTurnsFull):
        repository.assert_can_create(user_id, enabled=False)
    with pytest.raises(GuestTurnsFull):
        repository.assert_can_send(conversation.id, user_id, enabled=False)


def test_failed_guest_turn_is_released_and_can_be_retried_once():
    repository, user_id = _setup()
    profile = repository.db.get(ProfileModel, user_id)
    profile.is_guest = True
    profile.email = None
    repository.db.commit()
    conversation = repository.create_with_access(_conversation(user_id), enabled=True)
    message = repository.save_user_turn(
        MessageModel(
            id=str(uuid4()),
            conversation_id=conversation.id,
            role=MessageRole.USER,
            content="retry me",
        ),
        user_id,
        enabled=True,
    )

    repository.delete_failed_user_turn(message.id)

    assert repository.count_guest_turns(user_id, include_reserved=True) == 0
    assert repository.turn_access(conversation.id, user_id, enabled=True)["remaining_turns"] == 5


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






def test_create_precheck_counts_pending_roleplay_and_closes_transaction():
    repository, user_id = _setup()
    repository.db.get(ProfileModel, user_id).slot_limit_snapshot = 1
    repository.db.commit()
    StreamTurnStore(repository.db).reserve(
        user_id=user_id, request_id=str(uuid4()), kind="roleplay_start", input_data={},
    )

    with pytest.raises(ConversationSlotsFull):
        repository.assert_can_create(user_id, enabled=True)

    assert not repository.db.in_transaction()




def test_member_trial_is_account_wide_and_deletion_does_not_restore():
    repository, user_id = _setup()
    conversation = repository.create_with_access(_conversation(user_id), enabled=True)
    for index in range(10):
        message = MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                               role=MessageRole.USER, content=str(index))
        repository.save_user_turn(message, user_id, enabled=True)
        repository.save_assistant_turn(MessageModel(id=str(uuid4()), conversation_id=conversation.id,
            role=MessageRole.ASSISTANT, content='reply'), user_id=user_id, user_message_id=message.id)
    assert repository.turn_access(conversation.id, user_id, enabled=True)['remaining_turns'] == 0
    repository.delete_by_id(conversation.id, user_id)
    access = repository.access_summary(user_id, enabled=True)
    assert access['remaining_slots'] == 1
    assert access['remaining_turns'] == 0
    with pytest.raises(CreditsExhausted):
        repository.create_with_access(_conversation(user_id), enabled=True)


def test_existing_over_capacity_member_conversations_remain_sendable():
    repository, user_id = _setup()
    conversations = [repository.save(_conversation(user_id)) for _ in range(3)]
    access = repository.access_summary(user_id, enabled=True)
    assert access['used_slots'] == 3
    assert access['locked_count'] == 0
    assert not access['can_create']
    for conversation in conversations:
        assert repository.turn_access(conversation.id, user_id, enabled=True)['can_send']
    with pytest.raises(ConversationSlotsFull):
        repository.assert_can_create(user_id, enabled=True)

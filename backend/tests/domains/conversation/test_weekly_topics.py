from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import MessageRole
from domains.conversation.models import MessageModel
from domains.conversation.models import SuggestedStartModel
from domains.conversation.repository import ConversationRepository
from domains.conversation.repository import ConversationSlotsFull
from domains.conversation.service import ConversationService
from domains.conversation.topic_repository import WeeklyTopicRepository
from shared.language import LearningLanguageContext
from shared.exceptions import NotFoundException


@pytest.fixture
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    @event.listens_for(engine, "connect")
    def enable_foreign_keys(connection, _):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as session:
        yield session
    engine.dispose()


def test_latest_published_batch_and_archive(db):
    topics = WeeklyTopicRepository(db)
    first = topics.publish("ko", "en", "2026-09-28", [f"주제 {i}" for i in range(6)])
    assert topics.publish("ko", "en", "2026-09-28", ["다른 주제"])[0].id == first[0].id
    assert [item.text for item in topics.latest("ko", "en")[1]] == [f"주제 {i}" for i in range(6)]
    assert topics.latest("en", "ko") == (None, [])
    topics.archive(first[0].id)
    assert len(topics.latest("ko", "en")[1]) == 5
    assert topics.available(first[0].id, "ko", "en") is None
    later = topics.publish("ko", "en", "2026-10-05", [f"새 주제 {i}" for i in range(6)])
    for item in later:
        topics.archive(item.id)
    assert topics.latest("ko", "en")[0].isoformat() == "2026-09-28"


@pytest.mark.asyncio
async def test_suggested_start_is_ai_first_and_idempotent(db, monkeypatch):
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner"))
    db.commit()
    topic = WeeklyTopicRepository(db).publish("ko", "en", "2026-09-28", [f"주제 {i}" for i in range(6)])[0]
    service = ConversationService(ConversationRepository(db))

    async def answer(*_args):
        return "What would you like to try?"

    monkeypatch.setattr(service, "generate_response", answer)
    request_id = str(uuid4())
    first = await service.start_suggested_free_chat(
        topic.id, request_id, user_id, LearningLanguageContext()
    )
    second = await service.start_suggested_free_chat(
        topic.id, request_id, user_id, LearningLanguageContext()
    )
    assert first.conversation_id == second.conversation_id
    messages = db.query(MessageModel).filter_by(conversation_id=str(first.conversation_id)).all()
    assert len(messages) == 1
    assert messages[0].role == MessageRole.ASSISTANT
    assert str(first.assistant_message_id) == messages[0].id
    db.add(MessageModel(id=str(uuid4()), conversation_id=str(first.conversation_id), role=MessageRole.ASSISTANT, content="Later answer"))
    db.commit()
    repeated_later = await service.start_suggested_free_chat(
        topic.id, request_id, user_id, LearningLanguageContext()
    )
    assert repeated_later.assistant_message_id == first.assistant_message_id
    service.repository.delete_by_id(str(first.conversation_id), user_id)
    assert db.query(SuggestedStartModel).filter_by(user_id=user_id, request_id=request_id).count() == 0


@pytest.mark.asyncio
async def test_archived_topic_cannot_start_and_generation_failure_can_retry(db, monkeypatch):
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner"))
    db.commit()
    topic = WeeklyTopicRepository(db).publish("ko", "en", "2026-09-28", [f"주제 {i}" for i in range(6)])[0]
    service = ConversationService(ConversationRepository(db))
    request_id = str(uuid4())

    async def unavailable(*_args):
        raise RuntimeError("model unavailable")

    monkeypatch.setattr(service, "generate_response", unavailable)
    with pytest.raises(RuntimeError, match="model unavailable"):
        await service.start_suggested_free_chat(topic.id, request_id, user_id, LearningLanguageContext())
    assert service.repository.count_conversations(user_id) == 0

    async def recovered(*_args):
        return "What do you enjoy?"

    monkeypatch.setattr(service, "generate_response", recovered)
    first = await service.start_suggested_free_chat(topic.id, request_id, user_id, LearningLanguageContext())
    WeeklyTopicRepository(db).archive(topic.id)
    repeated = await service.start_suggested_free_chat(topic.id, request_id, user_id, LearningLanguageContext())
    assert repeated.conversation_id == first.conversation_id
    assert repeated.assistant_message_id == first.assistant_message_id
    with pytest.raises(NotFoundException):
        await service.start_suggested_free_chat(topic.id, str(uuid4()), user_id, LearningLanguageContext())


@pytest.mark.asyncio
async def test_topic_archived_during_ai_generation_does_not_create_chat(db, monkeypatch):
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner"))
    db.commit()
    topic = WeeklyTopicRepository(db).publish("ko", "en", "2026-09-28", [f"주제 {i}" for i in range(6)])[0]
    service = ConversationService(ConversationRepository(db))

    async def archive_then_answer(*_args):
        WeeklyTopicRepository(db).archive(topic.id)
        return "What do you enjoy?"

    monkeypatch.setattr(service, "generate_response", archive_then_answer)
    with pytest.raises(NotFoundException):
        await service.start_suggested_free_chat(topic.id, str(uuid4()), user_id, LearningLanguageContext())
    assert service.repository.count_conversations(user_id) == 0


@pytest.mark.asyncio
async def test_suggested_start_respects_slot_limit(db, monkeypatch):
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner"))
    db.commit()
    topic = WeeklyTopicRepository(db).publish("ko", "en", "2026-09-28", [f"주제 {i}" for i in range(6)])[0]
    service = ConversationService(ConversationRepository(db))

    async def answer(*_args):
        return "What do you enjoy?"

    monkeypatch.setattr(service, "generate_response", answer)
    import domains.conversation.service as service_module
    monkeypatch.setattr(service_module.settings, "conversation_access_enabled", True)
    first = await service.start_suggested_free_chat(topic.id, str(uuid4()), user_id, LearningLanguageContext())
    assert service.repository.count_user_turns(str(first.conversation_id)) == 0
    with pytest.raises(ConversationSlotsFull):
        await service.start_suggested_free_chat(topic.id, str(uuid4()), user_id, LearningLanguageContext())
    assert service.repository.count_conversations(user_id) == 1


def test_api_lists_pair_topics_and_starts_ai_first(db, monkeypatch):
    from domains.conversation import router as conversation_router
    from domains.conversation import topic_router
    from database import get_db

    user_id = str(uuid4())
    profile = ProfileModel(id=user_id, email=f"{user_id}@example.com", name="Learner")
    db.add(profile)
    db.commit()
    topics = WeeklyTopicRepository(db)
    own = topics.publish("ko", "en", "2026-09-28", [f"주제 {i}" for i in range(6)])
    topics.publish("en", "ko", "2026-09-28", [f"Topic {i}" for i in range(6)])
    service = ConversationService(ConversationRepository(db))

    async def answer(*_args):
        return "What do you like to do on weekends?"

    monkeypatch.setattr(service, "generate_response", answer)
    app = FastAPI()
    app.include_router(topic_router.router)
    app.include_router(conversation_router.router)
    app.dependency_overrides[topic_router.get_current_user] = lambda: profile
    app.dependency_overrides[conversation_router.get_current_user] = lambda: profile
    app.dependency_overrides[get_db] = lambda: db
    app.dependency_overrides[conversation_router.get_conversation_service] = lambda: service
    app.dependency_overrides[conversation_router.get_voice_service] = lambda: object()
    client = TestClient(app)

    listing = client.get("/api/conversation-topics/weekly/")
    assert listing.status_code == 200
    assert [item["id"] for item in listing.json()["data"]["topics"]] == [item.id for item in own]
    request_id = str(uuid4())
    started = client.post(
        "/api/conversations/start/free-chat/suggested/",
        json={"topic_id": own[0].id, "start_request_id": request_id},
    )
    assert started.status_code == 200
    data = started.json()["data"]
    assert data["assistant_message_id"]
    assert data["conversation_type"] == "FREE_CHAT"
    assert "message_id" not in data
    repeated = client.post(
        "/api/conversations/start/free-chat/suggested/",
        json={"topic_id": own[0].id, "start_request_id": request_id},
    )
    assert repeated.json()["data"]["conversation_id"] == data["conversation_id"]

from uuid import uuid4

import pytest

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel
from domains.conversation.stream_flow import prepare_generation


class _BackgroundTasks:
    def start(self, coroutine):
        coroutine.close()


@pytest.mark.parametrize("accent", ["us", "gb", "au"])
def test_stream_free_chat_stores_topic_as_title(monkeypatch, accent):
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    sessions = sessionmaker(bind=engine)
    user_id = str(uuid4())
    with sessions() as db:
        db.add(ProfileModel(id=user_id, email="stream-title@example.com", name="Learner"))
        db.commit()
    monkeypatch.setattr("domains.conversation.stream_flow.SessionLocal", sessions)

    prepared = prepare_generation(
        user_id=user_id,
        request_id=str(uuid4()),
        kind="free_chat_start",
        input_data={
            "text": "I want to discuss my trip.",
            "tts_accent": accent,
            "input_mode": "text",
            "topic": "  오사카 여행  ",
            "search_context": "오사카 여행 준비 요약",
            "conversation_direction": "CASUAL_CHAT",
            "custom_focus": "음식 이야기",
            "language": {
                "native_language": "ko",
                "target_language": "en",
                "feedback_language": "ko",
            },
        },
        http_client=None,
        background_tasks=_BackgroundTasks(),
    )

    with sessions() as db:
        conversation = db.get(ConversationModel, prepared.conversation_id)
        assert prepared.tts_accent == accent
        assert conversation.tts_accent == accent
        assert conversation.title == "오사카 여행"
        assert conversation.topic == "  오사카 여행  "
        assert conversation.topic_summary == "오사카 여행 준비 요약"
        assert conversation.conversation_direction == "CASUAL_CHAT"
        assert conversation.custom_focus == "음식 이야기"
    from domains.conversation.stream_turns import StreamTurnStore
    with sessions() as db:
        StreamTurnStore(db).fail(prepared.turn_id, "TEST_FAILURE")
    retried = prepare_generation(
        user_id=user_id, request_id=str(uuid4()), kind=None, input_data=None,
        retry_turn_id=prepared.turn_id, http_client=None, background_tasks=_BackgroundTasks(),
    )
    assert retried.conversation_id == prepared.conversation_id
    assert retried.tts_accent == accent
    engine.dispose()

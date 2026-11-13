from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel
from domains.conversation.stream_flow import prepare_generation


class _BackgroundTasks:
    def start(self, coroutine):
        coroutine.close()


def test_stream_free_chat_stores_topic_as_title(monkeypatch):
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
            "input_mode": "text",
            "topic": "  오사카 여행  ",
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
        assert conversation.title == "오사카 여행"
    engine.dispose()

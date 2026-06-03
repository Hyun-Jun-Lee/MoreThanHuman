from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_user
from domains.conversation.router import get_conversation_service, router
from domains.conversation.service import ConversationService


def _conversation_app_with_overrides(service) -> FastAPI:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id="user-1")
    app.dependency_overrides[get_conversation_service] = lambda: service
    return app


def test_free_chat_prompt_includes_topic_prep_handoff_context():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(
        search_context="The Dodgers won with a late home run.",
        topic="recent Dodgers game result",
        conversation_direction="DEBATE",
        selected_question="Was the manager's late-game decision right?",
    )

    assert "Topic Prep Handoff" in prompt
    assert "recent Dodgers game result" in prompt
    assert "DEBATE" in prompt
    assert "Was the manager's late-game decision right?" in prompt
    assert "counterarguments" in prompt


def test_free_chat_prompt_without_topic_prep_keeps_existing_shape():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(search_context=None)

    assert "Topic Prep Handoff" not in prompt
    assert "friendly and helpful English conversation learning assistant" in prompt


def test_start_free_chat_rejects_invalid_topic_prep_direction():
    class FakeService:
        async def start_free_chat_conversation(self, *args, **kwargs):
            raise AssertionError("Service should not run when request validation fails")

    client = TestClient(_conversation_app_with_overrides(FakeService()))

    response = client.post(
        "/api/conversations/start/free-chat/",
        json={
            "first_message": "I think the decision was right.",
            "conversation_direction": "INVALID_DIRECTION",
        },
    )

    assert response.status_code == 422

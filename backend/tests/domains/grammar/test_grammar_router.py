from datetime import UTC, datetime
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_user
from domains.grammar.router import get_grammar_service, router
from domains.grammar.schemas import GrammarFeedback
from domains.grammar.service import GrammarService
from shared.exceptions import NotFoundException


MESSAGE_ID = "550e8400-e29b-41d4-a716-446655440000"
FEEDBACK_ID = "550e8400-e29b-41d4-a716-446655440001"


def _feedback() -> GrammarFeedback:
    return GrammarFeedback(
        id=FEEDBACK_ID,
        message_id=MESSAGE_ID,
        original_text="I goes home",
        corrected_text="I go home",
        has_errors=True,
        errors=[],
        created_at=datetime.now(UTC),
    )


def _app_with_overrides(service, *, authenticated: bool = True) -> FastAPI:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_grammar_service] = lambda: service
    if authenticated:
        app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id="user-1")
    return app


def test_feedback_polling_returns_completed_feedback_for_authenticated_user():
    class FakeService:
        def get_feedback(self, message_id: str, user_id: str) -> GrammarFeedback:
            assert message_id == MESSAGE_ID
            assert user_id == "user-1"
            return _feedback()

    client = TestClient(_app_with_overrides(FakeService()))

    response = client.get(f"/api/grammar/message/{MESSAGE_ID}/")

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["message_id"] == MESSAGE_ID
    assert body["data"]["corrected_text"] == "I go home"


def test_feedback_polling_returns_404_for_pending_or_unowned_message():
    class FakeService:
        def get_feedback(self, message_id: str, user_id: str) -> GrammarFeedback:
            assert message_id == MESSAGE_ID
            assert user_id == "user-1"
            raise NotFoundException(f"Grammar feedback for message {message_id} not found")

    client = TestClient(_app_with_overrides(FakeService()))

    response = client.get(f"/api/grammar/message/{MESSAGE_ID}/")

    assert response.status_code == 404


def test_feedback_polling_requires_authorization_header():
    class FakeService:
        def get_feedback(self, _message_id: str, user_id: str) -> GrammarFeedback:
            raise AssertionError("service should not be called without auth")

    client = TestClient(_app_with_overrides(FakeService(), authenticated=False))

    response = client.get(f"/api/grammar/message/{MESSAGE_ID}/")

    assert response.status_code == 403


def test_grammar_service_checks_message_ownership_before_feedback_lookup():
    class FakeOwnershipRepository:
        checked = None

        def ensure_message_belongs_to_user(self, message_id: str, user_id: str) -> None:
            self.checked = (message_id, user_id)

    class FakeGrammarRepository:
        def find_by_message_id(self, message_id: str):
            assert message_id == MESSAGE_ID
            return SimpleNamespace(
                id=FEEDBACK_ID,
                message_id=MESSAGE_ID,
                original_text="I goes home",
                corrected_text="I go home",
                has_errors=True,
                errors=[],
                created_at=datetime.now(UTC),
            )

    ownership_repository = FakeOwnershipRepository()
    service = GrammarService(FakeGrammarRepository(), ownership_repository)

    feedback = service.get_feedback(MESSAGE_ID, user_id="user-1")

    assert ownership_repository.checked == (MESSAGE_ID, "user-1")
    assert feedback.message_id.hex == MESSAGE_ID.replace("-", "")


def test_grammar_service_hides_unowned_message_without_feedback_lookup():
    class FakeOwnershipRepository:
        def ensure_message_belongs_to_user(self, _message_id: str, _user_id: str) -> None:
            raise NotFoundException("Message not found")

    class FakeGrammarRepository:
        def find_by_message_id(self, _message_id: str):
            raise AssertionError("feedback lookup should not run for unowned messages")

    service = GrammarService(FakeGrammarRepository(), FakeOwnershipRepository())

    with pytest.raises(NotFoundException):
        service.get_feedback(MESSAGE_ID, user_id="user-1")

from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from config import get_settings
from domains.auth.dependencies import get_auth_service
from domains.auth.router import router
from domains.auth.schemas import TokenResponse
from domains.auth.service import AuthService
from domains.conversation.models import ConversationModel  # noqa: F401 - SQLAlchemy relationship registration
from domains.grammar.models import GrammarFeedbackModel  # noqa: F401 - SQLAlchemy relationship registration


@pytest.fixture(autouse=True)
def clear_settings_cache():
    yield
    get_settings.cache_clear()


def _client_with_service(service) -> TestClient:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_auth_service] = lambda: service
    return TestClient(app)


def test_dev_token_endpoint_issues_token_when_env_is_dev(monkeypatch):
    monkeypatch.setenv("ENV", "dev")
    get_settings.cache_clear()

    class FakeService:
        def issue_dev_token(self, email: str, name: str, device_id: str) -> TokenResponse:
            assert email == "swagger-test@example.com"
            assert name == "Swagger Test User"
            assert device_id == "swagger-local"
            return TokenResponse(access_token="access-token", refresh_token="refresh-token")

    client = _client_with_service(FakeService())

    response = client.post("/api/auth/dev/token", json={})

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["access_token"] == "access-token"
    assert body["data"]["token_type"] == "bearer"


def test_dev_token_endpoint_is_forbidden_when_env_is_not_dev(monkeypatch):
    monkeypatch.setenv("ENV", "prod")
    get_settings.cache_clear()

    class FakeService:
        def issue_dev_token(self, _email: str, _name: str, _device_id: str) -> TokenResponse:
            raise AssertionError("service should not be called outside dev env")

    client = _client_with_service(FakeService())

    response = client.post("/api/auth/dev/token", json={})

    assert response.status_code == 403


def test_dev_token_service_creates_user_and_issues_token(monkeypatch):
    monkeypatch.setenv("ENV", "dev")
    get_settings.cache_clear()

    class FakeRepository:
        saved_user = None

        def find_by_email(self, _email: str):
            return None

        def save(self, user):
            self.saved_user = user
            return user

        def revoke_active_refresh_tokens_for_user_device(self, *, user_id: str, device_id: str) -> int:
            assert user_id == self.saved_user.id
            assert device_id == "swagger-local"
            return 0

        def create_refresh_token(self, **kwargs):
            assert kwargs["user_id"] == self.saved_user.id
            assert kwargs["device_id"] == "swagger-local"
            return SimpleNamespace(**kwargs)

    repository = FakeRepository()
    service = AuthService(repository)

    token = service.issue_dev_token(
        email="swagger-test@example.com",
        name="Swagger Test User",
        device_id="swagger-local",
    )

    assert repository.saved_user.email == "swagger-test@example.com"
    assert repository.saved_user.oauth_provider == "dev"
    assert token.access_token
    assert token.refresh_token

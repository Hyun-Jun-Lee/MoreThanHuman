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
from shared.exceptions import AuthenticationException, ValidationException


@pytest.fixture(autouse=True)
def clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _client_with_service(service) -> TestClient:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_auth_service] = lambda: service
    return TestClient(app)


class FakeGoogleRepository:
    def __init__(self, *, oauth_user=None, email_user=None):
        self.oauth_user = oauth_user
        self.email_user = email_user
        self.saved_user = None

    def find_by_oauth(self, provider: str, provider_id: str):
        assert provider == "google"
        assert provider_id == "google-sub-1"
        return self.oauth_user

    def find_by_email(self, email: str):
        assert email == "google-user@example.com"
        return self.email_user

    def save(self, user):
        self.saved_user = user
        return user


def _stub_google_verifier(service: AuthService, *, email_verified=True):
    def verify_google_id_token(google_id_token: str, audience: str) -> dict:
        assert google_id_token == "id-token"
        assert audience == "mobile-client-id"
        return {
            "sub": "google-sub-1",
            "email": "google-user@example.com",
            "email_verified": email_verified,
            "name": "Google User",
        }

    service._verify_google_id_token = verify_google_id_token


def _stub_token_issuer(service: AuthService):
    issued = {}

    def issue_token_pair(*, user_id: str, device_id: str) -> TokenResponse:
        issued["user_id"] = user_id
        issued["device_id"] = device_id
        return TokenResponse(access_token="access-token", refresh_token="refresh-token")

    service._issue_token_pair = issue_token_pair
    return issued


def test_google_mobile_service_creates_user_and_issues_token(monkeypatch):
    monkeypatch.setenv("GOOGLE_CLIENT_ID", "mobile-client-id")
    get_settings.cache_clear()
    repository = FakeGoogleRepository()
    service = AuthService(repository)
    _stub_google_verifier(service)
    issued = _stub_token_issuer(service)

    token = service.login_with_google_id_token("id-token", "device-1")

    assert repository.saved_user.email == "google-user@example.com"
    assert repository.saved_user.name == "Google User"
    assert repository.saved_user.oauth_provider == "google"
    assert repository.saved_user.oauth_provider_id == "google-sub-1"
    assert issued["user_id"] == repository.saved_user.id
    assert issued["device_id"] == "device-1"
    assert token.access_token == "access-token"


def test_google_mobile_service_reuses_existing_google_user(monkeypatch):
    monkeypatch.setenv("GOOGLE_CLIENT_ID", "mobile-client-id")
    get_settings.cache_clear()
    oauth_user = SimpleNamespace(id="user-1", is_active=True)
    repository = FakeGoogleRepository(oauth_user=oauth_user)
    service = AuthService(repository)
    _stub_google_verifier(service)
    issued = _stub_token_issuer(service)

    token = service.login_with_google_id_token("id-token", "device-1")

    assert repository.saved_user is None
    assert issued["user_id"] == "user-1"
    assert token.refresh_token == "refresh-token"


def test_google_mobile_service_rejects_existing_email_without_auto_link(monkeypatch):
    monkeypatch.setenv("GOOGLE_CLIENT_ID", "mobile-client-id")
    get_settings.cache_clear()
    email_user = SimpleNamespace(id="email-user-1", is_active=True)
    repository = FakeGoogleRepository(email_user=email_user)
    service = AuthService(repository)
    _stub_google_verifier(service)
    _stub_token_issuer(service)

    with pytest.raises(ValidationException) as exc_info:
        service.login_with_google_id_token("id-token", "device-1")

    assert exc_info.value.details["code"] == "EMAIL_EXISTS"
    assert repository.saved_user is None


def test_google_mobile_service_rejects_unverified_google_email(monkeypatch):
    monkeypatch.setenv("GOOGLE_CLIENT_ID", "mobile-client-id")
    get_settings.cache_clear()
    repository = FakeGoogleRepository()
    service = AuthService(repository)
    _stub_google_verifier(service, email_verified=False)
    _stub_token_issuer(service)

    with pytest.raises(AuthenticationException):
        service.login_with_google_id_token("id-token", "device-1")


def test_google_mobile_endpoint_issues_token():
    class FakeService:
        def login_with_google_id_token(self, google_id_token: str, device_id: str) -> TokenResponse:
            assert google_id_token == "id-token"
            assert device_id == "device-1"
            return TokenResponse(access_token="access-token", refresh_token="refresh-token")

    client = _client_with_service(FakeService())

    response = client.post(
        "/api/auth/google/mobile",
        json={"id_token": "id-token", "device_id": "device-1"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["access_token"] == "access-token"
    assert body["message"] == "Google 모바일 로그인 성공"


def test_google_mobile_endpoint_returns_conflict_for_existing_email():
    class FakeService:
        def login_with_google_id_token(self, _google_id_token: str, _device_id: str) -> TokenResponse:
            raise ValidationException(
                "이미 이메일로 가입된 계정입니다",
                details={"code": "EMAIL_EXISTS"},
            )

    client = _client_with_service(FakeService())

    response = client.post(
        "/api/auth/google/mobile",
        json={"id_token": "id-token", "device_id": "device-1"},
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "이미 이메일로 가입된 계정입니다"

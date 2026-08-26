import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from config import get_settings
from domains.auth.dependencies import get_auth_service
from domains.auth.router import router
from domains.auth.schemas import TokenResponse
from domains.auth.service import AuthService
import domains.auth.service as auth_service_module
from shared.exceptions import AuthenticationException


@pytest.fixture(autouse=True)
def clear_settings_cache():
    yield
    get_settings.cache_clear()


def _client_with_service(service) -> TestClient:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_auth_service] = lambda: service
    return TestClient(app)


def test_swagger_token_endpoint_issues_token_in_dev(monkeypatch):
    monkeypatch.setenv("ENV", "dev")
    get_settings.cache_clear()

    class FakeService:
        async def issue_swagger_token(self, *, email: str, password: str) -> TokenResponse:
            assert email == "swagger-test@example.com"
            assert password == "password"
            return TokenResponse(
                access_token="supabase-access",
                refresh_token="supabase-refresh",
                expires_in=3600,
            )

    client = _client_with_service(FakeService())

    response = client.post(
        "/api/auth/swagger/token",
        json={"email": "swagger-test@example.com", "password": "password"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["access_token"] == "supabase-access"
    assert body["data"]["refresh_token"] == "supabase-refresh"
    assert body["data"]["token_type"] == "bearer"
    assert body["data"]["expires_in"] == 3600


def test_swagger_token_endpoint_is_disabled_in_prod_by_default(monkeypatch):
    monkeypatch.setenv("ENV", "prod")
    monkeypatch.delenv("SWAGGER_TOKEN_ISSUER_ENABLED", raising=False)
    get_settings.cache_clear()

    class FakeService:
        async def issue_swagger_token(self, *, email: str, password: str) -> TokenResponse:
            raise AssertionError("service should not be called when issuer is disabled")

    client = _client_with_service(FakeService())

    response = client.post(
        "/api/auth/swagger/token",
        json={"email": "swagger-test@example.com", "password": "password"},
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Swagger token issuer is disabled."


def test_swagger_token_endpoint_requires_secret_outside_dev(monkeypatch):
    monkeypatch.setenv("ENV", "prod")
    monkeypatch.setenv("SWAGGER_TOKEN_ISSUER_ENABLED", "true")
    monkeypatch.setenv("SWAGGER_TOKEN_ISSUER_SECRET", "expected-secret")
    get_settings.cache_clear()

    class FakeService:
        async def issue_swagger_token(self, *, email: str, password: str) -> TokenResponse:
            raise AssertionError("service should not be called with a bad secret")

    client = _client_with_service(FakeService())

    response = client.post(
        "/api/auth/swagger/token",
        json={
            "email": "swagger-test@example.com",
            "password": "password",
            "secret": "wrong-secret",
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Invalid Swagger token issuer secret."


def test_swagger_token_endpoint_allows_enabled_prod_with_secret(monkeypatch):
    monkeypatch.setenv("ENV", "prod")
    monkeypatch.setenv("SWAGGER_TOKEN_ISSUER_ENABLED", "true")
    monkeypatch.setenv("SWAGGER_TOKEN_ISSUER_SECRET", "expected-secret")
    get_settings.cache_clear()

    class FakeService:
        async def issue_swagger_token(self, *, email: str, password: str) -> TokenResponse:
            assert email == "swagger-test@example.com"
            assert password == "password"
            return TokenResponse(access_token="supabase-access")

    client = _client_with_service(FakeService())

    response = client.post(
        "/api/auth/swagger/token",
        json={
            "email": "swagger-test@example.com",
            "password": "password",
            "secret": "expected-secret",
        },
    )

    assert response.status_code == 200
    assert response.json()["data"]["access_token"] == "supabase-access"


class _FakeResponse:
    def __init__(self, status_code: int, json_data: dict | None = None, json_error: Exception | None = None):
        self.status_code = status_code
        self._json_data = json_data
        self._json_error = json_error

    def json(self):
        if self._json_error is not None:
            raise self._json_error
        return self._json_data


class _FakeAsyncClient:
    def __init__(self, response: _FakeResponse):
        self.response = response
        self.requests = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def post(self, url: str, *, headers: dict, json: dict):
        self.requests.append({"url": url, "headers": headers, "json": json})
        return self.response


@pytest.mark.asyncio
async def test_swagger_token_service_calls_supabase_password_grant(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://project.supabase.co")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "publishable-key")
    get_settings.cache_clear()

    fake_client = _FakeAsyncClient(
        _FakeResponse(
            200,
            {
                "access_token": "supabase-access",
                "refresh_token": "supabase-refresh",
                "token_type": "bearer",
                "expires_in": 3600,
            },
        )
    )
    monkeypatch.setattr(
        auth_service_module.httpx,
        "AsyncClient",
        lambda *, timeout: fake_client,
    )

    token = await AuthService(repository=None).issue_swagger_token(
        email="learner@example.com",
        password="password",
    )

    assert token.access_token == "supabase-access"
    assert token.refresh_token == "supabase-refresh"
    assert token.expires_in == 3600
    assert fake_client.requests == [
        {
            "url": "https://project.supabase.co/auth/v1/token?grant_type=password",
            "headers": {
                "apikey": "publishable-key",
                "Content-Type": "application/json",
            },
            "json": {"email": "learner@example.com", "password": "password"},
        }
    ]


@pytest.mark.asyncio
async def test_swagger_token_service_rejects_bad_supabase_credentials(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://project.supabase.co")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "publishable-key")
    get_settings.cache_clear()

    fake_client = _FakeAsyncClient(_FakeResponse(400, {"error": "invalid_grant"}))
    monkeypatch.setattr(
        auth_service_module.httpx,
        "AsyncClient",
        lambda *, timeout: fake_client,
    )

    with pytest.raises(AuthenticationException, match="Invalid Supabase email/password"):
        await AuthService(repository=None).issue_swagger_token(
            email="learner@example.com",
            password="wrong-password",
        )


@pytest.mark.asyncio
async def test_swagger_token_service_rejects_invalid_supabase_response(monkeypatch):
    monkeypatch.setenv("SUPABASE_URL", "https://project.supabase.co")
    monkeypatch.setenv("SUPABASE_PUBLISHABLE_KEY", "publishable-key")
    get_settings.cache_clear()

    fake_client = _FakeAsyncClient(_FakeResponse(200, json_error=ValueError("bad json")))
    monkeypatch.setattr(
        auth_service_module.httpx,
        "AsyncClient",
        lambda *, timeout: fake_client,
    )

    with pytest.raises(AuthenticationException, match="Invalid Supabase token response"):
        await AuthService(repository=None).issue_swagger_token(
            email="learner@example.com",
            password="password",
        )

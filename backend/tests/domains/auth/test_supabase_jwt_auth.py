from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.auth.dependencies import get_supabase_auth_verifier
from domains.auth.router import router
from domains.auth.service import SupabaseUserClaims
from shared.exceptions import AuthenticationException


class FakeVerifier:
    def __init__(self, claims=None, error: Exception | None = None):
        self.claims = claims
        self.error = error
        self.token = None

    async def verify_access_token(self, token: str):
        self.token = token
        if self.error is not None:
            raise self.error
        return self.claims


def _client(verifier: FakeVerifier) -> TestClient:
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session_factory = sessionmaker(bind=engine)

    def override_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_supabase_auth_verifier] = lambda: verifier
    return TestClient(app)


def test_me_creates_profile_from_valid_supabase_token():
    verifier = FakeVerifier(
        SupabaseUserClaims(
            sub="550e8400-e29b-41d4-a716-446655440000",
            email="learner@example.com",
            name="Learner",
            oauth_provider="google",
            avatar_url="https://example.com/avatar.png",
        )
    )
    client = _client(verifier)

    response = client.get("/api/auth/me", headers={"Authorization": "Bearer supabase-token"})

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["id"] == "550e8400-e29b-41d4-a716-446655440000"
    assert body["data"]["email"] == "learner@example.com"
    assert body["data"]["oauth_provider"] == "google"
    assert verifier.token == "supabase-token"


def test_me_rejects_invalid_supabase_token():
    verifier = FakeVerifier(error=AuthenticationException("Invalid Supabase access token"))
    client = _client(verifier)

    response = client.get("/api/auth/me", headers={"Authorization": "Bearer stale-token"})

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid Supabase access token"


def test_me_requires_authorization_header():
    verifier = FakeVerifier(error=AssertionError("verifier should not be called"))
    client = _client(verifier)

    response = client.get("/api/auth/me")

    assert response.status_code == 403

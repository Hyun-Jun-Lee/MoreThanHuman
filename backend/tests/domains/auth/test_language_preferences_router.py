from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.auth.dependencies import get_supabase_auth_verifier
from domains.auth.router import router
from domains.auth.service import SupabaseUserClaims


class FakeVerifier:
    def __init__(self):
        self.claims = SupabaseUserClaims(
            sub="550e8400-e29b-41d4-a716-446655440000",
            email="learner@example.com",
            name="Learner",
            oauth_provider="google",
        )

    async def verify_access_token(self, token: str):
        return self.claims


def _client() -> TestClient:
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
    app.dependency_overrides[get_supabase_auth_verifier] = lambda: FakeVerifier()
    return TestClient(app)


def test_me_includes_default_language_preferences():
    client = _client()

    response = client.get("/api/auth/me", headers={"Authorization": "Bearer token"})

    assert response.status_code == 200
    assert response.json()["data"]["language"] == {
        "native_language": "ko",
        "target_language": "en",
        "feedback_language": "ko",
    }


def test_language_preferences_update_is_narrow_and_idempotent():
    client = _client()

    response = client.put(
        "/api/auth/me/language-preferences",
        headers={"Authorization": "Bearer token"},
        json={
            "native_language": "en",
            "target_language": "ko",
            "feedback_language": "en",
        },
    )
    repeat = client.put(
        "/api/auth/me/language-preferences",
        headers={"Authorization": "Bearer token"},
        json={
            "native_language": "en",
            "target_language": "ko",
            "feedback_language": "en",
        },
    )

    assert response.status_code == 200
    assert repeat.status_code == 200
    assert response.json()["data"] == repeat.json()["data"]
    assert response.json()["data"]["target_language"] == "ko"


def test_language_preferences_reject_unsupported_pair_without_mutation():
    client = _client()
    headers = {"Authorization": "Bearer token"}

    valid = client.put(
        "/api/auth/me/language-preferences",
        headers=headers,
        json={
            "native_language": "zh",
            "target_language": "en",
            "feedback_language": "zh",
        },
    )
    invalid = client.put(
        "/api/auth/me/language-preferences",
        headers=headers,
        json={
            "native_language": "en",
            "target_language": "zh",
            "feedback_language": "en",
        },
    )
    current = client.get("/api/auth/me/language-preferences", headers=headers)

    assert valid.status_code == 200
    assert invalid.status_code == 422
    assert current.json()["data"]["native_language"] == "zh"
    assert current.json()["data"]["target_language"] == "en"


def test_language_preferences_reject_overposted_profile_fields():
    client = _client()

    response = client.put(
        "/api/auth/me/language-preferences",
        headers={"Authorization": "Bearer token"},
        json={
            "native_language": "en",
            "target_language": "ko",
            "feedback_language": "en",
            "email": "attacker@example.com",
            "is_active": False,
        },
    )

    assert response.status_code == 422

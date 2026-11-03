from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.auth.models import ProfileModel
from shared.http_clients import get_auth_http_client
from domains.auth.dependencies import get_current_profile, get_current_user, get_supabase_auth_verifier
from domains.auth.router import router
from domains.auth.service import SupabaseUserClaims
from domains.conversation.models import ConversationModel  # noqa: F401 - SQLAlchemy relationship registration
from domains.grammar.models import GrammarFeedbackModel  # noqa: F401 - SQLAlchemy relationship registration
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
    # verifier는 fake이며 이 테스트는 HTTP 호출 없이 profile 저장만 검증해요.
    app.dependency_overrides[get_auth_http_client] = lambda: None
    app.include_router(router)

    @app.get("/api/id-only")
    def id_only(user=Depends(get_current_user)):
        return {"id": user.id}

    @app.get("/api/profile-required")
    def profile_required(profile=Depends(get_current_profile)):
        return {"id": profile.id}
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_supabase_auth_verifier] = lambda: verifier
    app.state.session_factory = session_factory
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


def test_bootstrap_creates_profile_with_pending_language_and_preserves_it_on_restore():
    verifier = FakeVerifier(
        SupabaseUserClaims(
            sub="550e8400-e29b-41d4-a716-446655440000",
            email="learner@example.com",
            name="Learner",
        )
    )
    client = _client(verifier)
    headers = {"Authorization": "Bearer supabase-token"}
    language = {
        "native_language": "en",
        "target_language": "ko",
        "feedback_language": "en",
    }

    created = client.post("/api/auth/bootstrap", headers=headers, json={"language": language})
    restored = client.post("/api/auth/bootstrap", headers=headers, json={})

    assert created.status_code == 200
    assert created.json()["data"]["language"] == language
    assert restored.status_code == 200
    assert restored.json()["data"]["language"] == language


def test_inactive_profile_does_not_block_authenticated_requests():
    verifier = FakeVerifier(
        SupabaseUserClaims(
            sub="550e8400-e29b-41d4-a716-446655440000",
            email="learner@example.com",
            name="Learner",
        )
    )
    client = _client(verifier)
    headers = {"Authorization": "Bearer supabase-token"}
    assert client.post("/api/auth/bootstrap", headers=headers, json={}).status_code == 200
    with client.app.state.session_factory() as db:
        profile = db.get(ProfileModel, verifier.claims.sub)
        profile.is_active = False
        db.commit()

    response = client.get("/api/auth/me", headers=headers)

    assert response.status_code == 200
    assert response.json()["data"]["is_active"] is False


def test_identity_request_does_not_create_profile():
    verifier = FakeVerifier(
        SupabaseUserClaims(
            sub="550e8400-e29b-41d4-a716-446655440000",
            email="learner@example.com",
            name="Learner",
        )
    )
    client = _client(verifier)
    headers = {"Authorization": "Bearer supabase-token"}

    identity = client.get("/api/id-only", headers=headers)
    required = client.get("/api/profile-required", headers=headers)
    with client.app.state.session_factory() as db:
        profile = db.get(ProfileModel, verifier.claims.sub)

    assert identity.status_code == 200
    assert required.status_code == 409
    assert profile is None


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

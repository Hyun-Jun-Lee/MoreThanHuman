from datetime import datetime

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.auth.dependencies import get_supabase_auth_verifier
from domains.auth.models import ProfileModel
from domains.auth.service import SupabaseUserClaims
from domains.conversation.models import ConversationModel  # noqa: F401 - relationship registration
from domains.grammar.models import GrammarFeedbackModel  # noqa: F401 - relationship registration
from domains.language_snacks.dependencies import get_language_snack_operations_key
from domains.language_snacks.models import LanguageSnackModel
from domains.language_snacks.repository import LanguageSnackRepository
from domains.language_snacks.router import router


class FakeVerifier:
    def __init__(self):
        self.claims_by_token = {
            "korean-token": SupabaseUserClaims(
                sub="550e8400-e29b-41d4-a716-446655440000",
                email="korean@example.com",
                name="Korean learner",
                oauth_provider="google",
            ),
            "english-token": SupabaseUserClaims(
                sub="660e8400-e29b-41d4-a716-446655440000",
                email="english@example.com",
                name="English learner",
                oauth_provider="google",
            ),
        }

    async def verify_access_token(self, token: str):
        return self.claims_by_token[token]


def _client(operations_key: str | None = "operations-key") -> tuple[TestClient, sessionmaker]:
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
    app.dependency_overrides[get_language_snack_operations_key] = lambda: operations_key
    return TestClient(app), session_factory


def _create_payload(**overrides: str) -> dict[str, str]:
    values = {
        "category": "Vocabulary",
        "left_label": "British English",
        "left_word": "crisps",
        "right_label": "American English",
        "right_word": "chips",
        "meaning": "둘 다 감자칩을 뜻해요.",
        "example": "Would you like a bag of crisps?",
    }
    values.update(overrides)
    return values


def _seed_published_snack(session_factory: sessionmaker) -> None:
    session = session_factory()
    try:
        repository = LanguageSnackRepository(session)
        repository.save(
            LanguageSnackModel(
                id="00000000-0000-0000-0000-000000000001",
                category="Vocabulary",
                left_label="British English",
                left_word="crisps",
                right_label="American English",
                right_word="chips",
                meaning="둘 다 감자칩을 뜻해요.",
                example="Would you like a bag of crisps?",
                published_at=datetime(2026, 9, 6, 12, 0, 0),
            )
        )
    finally:
        session.close()


def _count_snacks(session_factory: sessionmaker) -> int:
    session = session_factory()
    try:
        return session.query(LanguageSnackModel).count()
    finally:
        session.close()


def test_authenticated_users_receive_the_same_common_published_list():
    client, session_factory = _client()
    _seed_published_snack(session_factory)

    client.get("/api/language-snacks/", headers={"Authorization": "Bearer korean-token"})
    client.get("/api/language-snacks/", headers={"Authorization": "Bearer english-token"})
    session = session_factory()
    try:
        korean_profile = session.get(ProfileModel, "550e8400-e29b-41d4-a716-446655440000")
        english_profile = session.get(ProfileModel, "660e8400-e29b-41d4-a716-446655440000")
        korean_profile.native_language = "ko"
        korean_profile.target_language = "en"
        english_profile.native_language = "en"
        english_profile.target_language = "ko"
        session.commit()
    finally:
        session.close()

    korean_response = client.get(
        "/api/language-snacks/",
        headers={"Authorization": "Bearer korean-token"},
    )
    english_response = client.get(
        "/api/language-snacks/",
        headers={"Authorization": "Bearer english-token"},
    )

    assert korean_response.status_code == 200
    assert english_response.status_code == 200
    assert korean_response.json()["success"] is True
    assert korean_response.json()["data"] == english_response.json()["data"]
    assert korean_response.json()["data"][0]["left_word"] == "crisps"


def test_create_with_valid_operations_key_publishes_snack_for_subsequent_list():
    client, _ = _client()

    created = client.post(
        "/api/language-snacks/",
        headers={"X-Operations-Key": "operations-key"},
        json=_create_payload(),
    )
    listed = client.get(
        "/api/language-snacks/",
        headers={"Authorization": "Bearer korean-token"},
    )

    assert created.status_code == 201
    assert created.json()["success"] is True
    assert created.json()["data"]["published_at"] is not None
    assert listed.status_code == 200
    assert [snack["id"] for snack in listed.json()["data"]] == [
        created.json()["data"]["id"]
    ]


def test_create_rejects_missing_or_invalid_operations_key_without_mutation():
    client, session_factory = _client()

    missing = client.post("/api/language-snacks/", json=_create_payload())
    invalid = client.post(
        "/api/language-snacks/",
        headers={"X-Operations-Key": "wrong-key"},
        json=_create_payload(),
    )

    assert missing.status_code == 403
    assert invalid.status_code == 403
    assert _count_snacks(session_factory) == 0


def test_create_rejects_when_operations_key_is_not_configured_without_mutation():
    client, session_factory = _client(operations_key=None)

    response = client.post(
        "/api/language-snacks/",
        headers={"X-Operations-Key": "operations-key"},
        json=_create_payload(),
    )

    assert response.status_code == 403
    assert _count_snacks(session_factory) == 0


def test_create_rejects_invalid_content_without_partial_row():
    client, session_factory = _client()

    response = client.post(
        "/api/language-snacks/",
        headers={"X-Operations-Key": "operations-key"},
        json=_create_payload(meaning="   "),
    )

    assert response.status_code == 422
    assert _count_snacks(session_factory) == 0


def test_list_requires_the_existing_bearer_authentication_boundary():
    client, _ = _client()

    response = client.get("/api/language-snacks/")

    assert response.status_code == 403

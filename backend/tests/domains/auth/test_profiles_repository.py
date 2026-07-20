from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import ProfileModel
from domains.auth.repository import AuthRepository


def _repository():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    return AuthRepository(session)


def test_upsert_profile_creates_profile_from_supabase_identity():
    repository = _repository()

    profile = repository.upsert_profile(
        profile_id="550e8400-e29b-41d4-a716-446655440000",
        email="learner@example.com",
        name="Learner",
        oauth_provider="google",
        avatar_url="https://example.com/avatar.png",
    )

    assert profile.id == "550e8400-e29b-41d4-a716-446655440000"
    assert profile.email == "learner@example.com"
    assert profile.oauth_provider == "google"
    assert profile.avatar_url == "https://example.com/avatar.png"
    assert profile.native_language == "ko"
    assert profile.target_language == "en"
    assert profile.feedback_language == "ko"


def test_upsert_profile_updates_existing_profile_without_duplicate():
    repository = _repository()
    profile_id = "550e8400-e29b-41d4-a716-446655440000"

    repository.upsert_profile(
        profile_id=profile_id,
        email="old@example.com",
        name="Old",
        oauth_provider="google",
    )
    profile = repository.upsert_profile(
        profile_id=profile_id,
        email="new@example.com",
        name="New",
        oauth_provider="google",
    )

    assert profile.email == "new@example.com"
    assert profile.name == "New"
    assert repository.db.query(ProfileModel).count() == 1


def test_upsert_profile_preserves_language_preferences():
    repository = _repository()
    profile_id = "550e8400-e29b-41d4-a716-446655440000"
    repository.upsert_profile(
        profile_id=profile_id,
        email="learner@example.com",
        name="Learner",
        oauth_provider="google",
    )
    repository.update_language_preferences(
        profile_id=profile_id,
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    profile = repository.upsert_profile(
        profile_id=profile_id,
        email="new@example.com",
        name="New",
        oauth_provider="google",
    )

    assert profile.native_language == "en"
    assert profile.target_language == "ko"
    assert profile.feedback_language == "en"

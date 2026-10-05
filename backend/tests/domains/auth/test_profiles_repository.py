from datetime import datetime

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


def test_get_or_create_profile_creates_profile_from_supabase_identity():
    repository = _repository()

    profile = repository.get_or_create_profile(
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


def test_get_or_create_profile_keeps_existing_profile_unchanged():
    repository = _repository()
    profile_id = "550e8400-e29b-41d4-a716-446655440000"

    original = repository.get_or_create_profile(
        profile_id=profile_id,
        email="old@example.com",
        name="Old",
        oauth_provider="google",
    )
    original_updated_at = original.updated_at
    profile = repository.get_or_create_profile(
        profile_id=profile_id,
        email="new@example.com",
        name="New",
        oauth_provider="google",
    )

    assert profile.email == "old@example.com"
    assert profile.name == "Old"
    assert profile.updated_at == original_updated_at
    assert repository.db.query(ProfileModel).count() == 1


def test_get_or_create_profile_preserves_explicit_language_changes():
    repository = _repository()
    profile_id = "550e8400-e29b-41d4-a716-446655440000"
    repository.get_or_create_profile(
        profile_id=profile_id,
        email="learner@example.com",
        name="Learner",
        oauth_provider="google",
    )
    updated = repository.update_language_preferences(
        profile_id=profile_id,
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    updated_at = updated.updated_at
    profile = repository.get_or_create_profile(
        profile_id=profile_id,
        email="new@example.com",
        name="New",
        oauth_provider="google",
    )

    assert profile.native_language == "en"
    assert profile.target_language == "ko"
    assert profile.feedback_language == "en"
    assert profile.updated_at == updated_at


def test_profile_settings_update_timestamp_only_when_values_change():
    repository = _repository()
    profile_id = "550e8400-e29b-41d4-a716-446655440000"
    profile = repository.get_or_create_profile(
        profile_id=profile_id,
        email="learner@example.com",
        name="Learner",
        oauth_provider="google",
    )
    profile.updated_at = datetime(2020, 1, 1)
    repository.db.commit()

    same_language = repository.update_language_preferences(
        profile_id=profile_id,
        native_language="ko",
        target_language="en",
        feedback_language="ko",
    )
    assert same_language.updated_at == datetime(2020, 1, 1)

    changed_language = repository.update_language_preferences(
        profile_id=profile_id,
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )
    changed_at = changed_language.updated_at
    assert changed_at > datetime(2020, 1, 1)

    repository.update_language_preferences(
        profile_id=profile_id,
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )
    assert repository.find_by_id(profile_id).updated_at == changed_at

    changed_locale = repository.update_app_locale(profile_id=profile_id, app_locale="en")
    changed_at = changed_locale.updated_at
    repository.update_app_locale(profile_id=profile_id, app_locale="en")
    assert repository.find_by_id(profile_id).updated_at == changed_at

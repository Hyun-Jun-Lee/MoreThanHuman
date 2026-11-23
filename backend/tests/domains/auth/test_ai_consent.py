from datetime import datetime
from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.consent import AIConsentService
from domains.auth.dependencies import get_current_ai_profile
from domains.auth.models import ProfileModel, UserConsentModel
from domains.conversation.models import ConversationModel  # noqa: F401
from domains.grammar.models import GrammarFeedbackModel  # noqa: F401


def _session():
    engine = create_engine("sqlite:///:memory:")

    @event.listens_for(engine, "connect")
    def _foreign_keys(connection, _record):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine)()


def _settings():
    return SimpleNamespace(
        privacy_policy_version="privacy-v1",
        ai_data_processing_version="ai-v1",
        privacy_policy_url="https://example.com/privacy",
        privacy_policy_url_en="https://example.com/en/privacy",
    )


def test_accept_current_consent_is_idempotent_for_guest_and_member():
    db = _session()
    db.add_all(
        [
            ProfileModel(id="guest", name="Guest", is_guest=True, last_active_at=datetime.utcnow()),
            ProfileModel(
                id="member",
                email="member@example.com",
                name="Member",
                is_guest=False,
                last_active_at=datetime.utcnow(),
            ),
        ]
    )
    db.commit()
    service = AIConsentService(db, _settings())

    status = service.status("guest")
    assert status["privacy_policy_url"] == "https://example.com/privacy"
    assert status["privacy_policy_url_en"] == "https://example.com/en/privacy"

    for user_id in ("guest", "member"):
        assert service.status(user_id)["accepted"] is False
        assert service.accept_current(user_id)["accepted"] is True
        assert service.accept_current(user_id)["accepted"] is True

    assert db.query(UserConsentModel).count() == 4


def test_old_version_is_rejected_by_common_ai_guard(monkeypatch):
    monkeypatch.setattr(
        "domains.auth.dependencies.get_settings",
        lambda: SimpleNamespace(ai_consent_required=True),
    )
    db = _session()
    profile = ProfileModel(
        id="guest", name="Guest", is_guest=True, last_active_at=datetime.utcnow()
    )
    db.add(profile)
    db.add_all(
        [
            UserConsentModel(
                id="old-privacy",
                user_id="guest",
                consent_kind="privacy_policy",
                version="old",
                accepted_at=datetime.utcnow(),
            ),
            UserConsentModel(
                id="old-ai",
                user_id="guest",
                consent_kind="ai_data_processing",
                version="old",
                accepted_at=datetime.utcnow(),
            ),
        ]
    )
    db.commit()

    with pytest.raises(HTTPException) as error:
        get_current_ai_profile(profile, db)

    assert error.value.status_code == 403
    assert error.value.detail["code"] == "CONSENT_REQUIRED"

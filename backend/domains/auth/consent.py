"""Versioned privacy and AI-processing consent."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from config import Settings, get_settings
from domains.auth.models import UserConsentModel

PRIVACY_POLICY = "privacy_policy"
AI_DATA_PROCESSING = "ai_data_processing"


class AIConsentService:
    def __init__(self, db: Session, settings: Settings | None = None):
        self.db = db
        self.settings = settings or get_settings()

    @property
    def required_versions(self) -> dict[str, str]:
        return {
            PRIVACY_POLICY: self.settings.privacy_policy_version,
            AI_DATA_PROCESSING: self.settings.ai_data_processing_version,
        }

    def status(self, user_id: str) -> dict:
        required = self.required_versions
        accepted_rows = (
            self.db.query(UserConsentModel)
            .filter(
                UserConsentModel.user_id == user_id,
                UserConsentModel.revoked_at.is_(None),
            )
            .all()
        )
        accepted = {
            row.consent_kind: row.version
            for row in accepted_rows
            if required.get(row.consent_kind) == row.version
        }
        missing = [kind for kind, version in required.items() if accepted.get(kind) != version]
        return {
            "accepted": not missing,
            "required_versions": required,
            "accepted_versions": accepted,
            "missing": missing,
            "privacy_policy_url": self.settings.privacy_policy_url,
            "privacy_policy_url_en": self.settings.privacy_policy_url_en,
        }

    def accept_current(self, user_id: str, *, accepted_at: datetime | None = None) -> dict:
        accepted_at = accepted_at or datetime.utcnow()
        for kind, version in self.required_versions.items():
            row = (
                self.db.query(UserConsentModel)
                .filter_by(user_id=user_id, consent_kind=kind, version=version)
                .one_or_none()
            )
            if row is None:
                self.db.add(
                    UserConsentModel(
                        id=str(uuid4()),
                        user_id=user_id,
                        consent_kind=kind,
                        version=version,
                        accepted_at=accepted_at,
                    )
                )
            else:
                row.accepted_at = accepted_at
                row.revoked_at = None
        self.db.commit()
        return self.status(user_id)

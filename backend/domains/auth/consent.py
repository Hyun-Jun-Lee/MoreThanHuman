"""Versioned privacy and AI-processing consent."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from config import Settings, get_settings
from domains.auth.models import ProfileModel, UserConsentModel

PRIVACY_POLICY = "privacy_policy"
AI_DATA_PROCESSING = "ai_data_processing"
PRIVACY_NOTICE = "privacy_notice"


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
        missing = [] if AI_DATA_PROCESSING in accepted else [AI_DATA_PROCESSING]
        notice_acknowledged = PRIVACY_POLICY in accepted or any(
            row.consent_kind == PRIVACY_NOTICE
            and row.version == required[PRIVACY_POLICY]
            for row in accepted_rows
        )
        return {
            "accepted": not missing,
            "required_versions": required,
            "accepted_versions": accepted,
            "missing": missing,
            "notice_acknowledged": notice_acknowledged,
            "privacy_policy_url": self.settings.privacy_policy_url,
            "privacy_policy_url_en": self.settings.privacy_policy_url_en,
        }

    def accept_current(self, user_id: str, *, accepted_at: datetime | None = None) -> dict:
        self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one()
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

    def record_choice(
        self, user_id: str, *, privacy_version: str, ai_version: str, accept_ai: bool,
    ) -> dict:
        """안내 확인과 AI 처리 수락을 구분하고 화면에 표시한 버전만 기록해요."""
        if (privacy_version != self.settings.privacy_policy_version
                or ai_version != self.settings.ai_data_processing_version):
            raise ValueError("The notices have changed. Review the current versions.")
        # 같은 계정의 중복 제출을 직렬화해 UNIQUE 충돌을 방지해요.
        self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one()
        choices = {PRIVACY_NOTICE: privacy_version}
        if accept_ai:
            choices[AI_DATA_PROCESSING] = ai_version
        for kind, version in choices.items():
            row = self.db.query(UserConsentModel).filter_by(
                user_id=user_id, consent_kind=kind, version=version,
            ).one_or_none()
            if row is None:
                self.db.add(UserConsentModel(
                    id=str(uuid4()), user_id=user_id, consent_kind=kind,
                    version=version, accepted_at=datetime.utcnow(),
                ))
            elif row.revoked_at is not None:
                row.revoked_at = None
                row.accepted_at = datetime.utcnow()
        self.db.commit()
        return self.status(user_id)

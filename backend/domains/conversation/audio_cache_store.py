"""DB manifest와 다중 워커 TTS lease를 관리해요."""

import json
from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.conversation.models import ConversationAudioCacheModel


LEASE_DURATION = timedelta(minutes=5)


class AudioCacheStore:
    def __init__(self, db: Session):
        self.db = db

    def manifest(self, message_id: str) -> dict | None:
        row = self.db.get(ConversationAudioCacheModel, message_id)
        if row is None or row.status != "ready" or not row.manifest_json:
            return None
        try:
            return json.loads(row.manifest_json)
        except (TypeError, ValueError):
            return None

    def claim(self, message_id: str, *, expected_manifest: dict | None = None) -> str | None:
        now = datetime.utcnow()
        lease_id = str(uuid4())
        try:
            with self.db.begin_nested():
                self.db.add(ConversationAudioCacheModel(
                    message_id=message_id, status="generating", lease_id=lease_id,
                    lease_until=now + LEASE_DURATION, updated_at=now,
                ))
                self.db.flush()
            self.db.commit()
            return lease_id
        except IntegrityError:
            self.db.rollback()
        claimable = [ConversationAudioCacheModel.status == "failed",
                     (ConversationAudioCacheModel.status == "generating") & (
                         (ConversationAudioCacheModel.lease_until <= now) |
                         ConversationAudioCacheModel.lease_until.is_(None))]
        if expected_manifest is not None:
            claimable.append((ConversationAudioCacheModel.status == "ready") & (
                ConversationAudioCacheModel.manifest_json == json.dumps(expected_manifest, ensure_ascii=False)))
        updated = self.db.query(ConversationAudioCacheModel).filter(
            ConversationAudioCacheModel.message_id == message_id,
            or_(*claimable),
        ).update({
            "status": "generating", "lease_id": lease_id,
            "lease_until": now + LEASE_DURATION, "updated_at": now,
        }, synchronize_session=False)
        self.db.commit()
        return lease_id if updated else None

    def publish(self, message_id: str, lease_id: str, manifest: dict) -> bool:
        updated = self.db.query(ConversationAudioCacheModel).filter_by(
            message_id=message_id, status="generating", lease_id=lease_id,
        ).update({
            "manifest_json": json.dumps(manifest, ensure_ascii=False),
            "status": "ready", "lease_id": None, "lease_until": None,
            "updated_at": datetime.utcnow(),
        }, synchronize_session=False)
        self.db.commit()
        return bool(updated)

    def renew(self, message_id: str, lease_id: str) -> bool:
        now = datetime.utcnow()
        updated = self.db.query(ConversationAudioCacheModel).filter_by(
            message_id=message_id, status="generating", lease_id=lease_id,
        ).update({"lease_until": now + LEASE_DURATION, "updated_at": now}, synchronize_session=False)
        self.db.commit()
        return bool(updated)

    def release(self, message_id: str, lease_id: str) -> None:
        self.db.query(ConversationAudioCacheModel).filter_by(
            message_id=message_id, status="generating", lease_id=lease_id,
        ).update({"status": "failed", "lease_id": None, "lease_until": None,
                  "updated_at": datetime.utcnow()}, synchronize_session=False)
        self.db.commit()

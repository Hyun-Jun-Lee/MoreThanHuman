"""음성 스트림의 영속 상태와 시도 기록."""

import json
import re
from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.conversation.models import StreamAttemptModel, StreamTurnModel
from shared.logging_config import log_event


TURN_DEADLINE = timedelta(minutes=5)


class StreamTurnConflict(Exception):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


class StreamTurnStore:
    def __init__(self, db: Session):
        self.db = db

    def get(self, user_id: str, turn_id: str) -> StreamTurnModel | None:
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id, user_id=user_id).one_or_none()
        if turn is not None:
            self._expire(turn)
        return turn

    def unresolved(self, user_id: str, conversation_id: str) -> list[StreamTurnModel]:
        turns = self.db.query(StreamTurnModel).filter_by(
            user_id=user_id, conversation_id=conversation_id
        ).order_by(StreamTurnModel.created_at.desc()).all()
        for turn in turns:
            self._expire(turn)
        return [turn for turn in turns if turn.status != "completed" or turn.audio_status == "failed"]

    def reserve(self, *, user_id: str, request_id: str, kind: str, input_data: dict) -> StreamTurnModel:
        existing = self.db.query(StreamTurnModel).filter_by(user_id=user_id, request_id=request_id).one_or_none()
        if existing is not None:
            self._expire(existing)
            raise StreamTurnConflict(self._conflict_code(existing))
        reused_attempt = self.db.query(StreamAttemptModel).filter_by(
            user_id=user_id, request_id=request_id,
        ).one_or_none()
        if reused_attempt is not None:
            raise StreamTurnConflict("IDEMPOTENCY_KEY_REUSED")
        now = datetime.utcnow()
        turn = StreamTurnModel(
            id=str(uuid4()), user_id=user_id, request_id=request_id, kind=kind,
            input_json=json.dumps(input_data, ensure_ascii=False),
            conversation_id=input_data.get("conversation_id"),
            status="pending", audio_status="pending", attempt_id=str(uuid4()),
            deadline_at=now + TURN_DEADLINE, created_at=now, updated_at=now,
        )
        attempt = StreamAttemptModel(
            id=turn.attempt_id, user_id=user_id, turn_id=turn.id, request_id=request_id,
            status="pending", started_at=now,
        )
        try:
            self.db.add(turn)
            self.db.flush()
            self.db.add(attempt)
            self.db.commit()
        except IntegrityError as error:
            self.db.rollback()
            existing = self.db.query(StreamTurnModel).filter_by(user_id=user_id, request_id=request_id).one_or_none()
            if existing is not None:
                self._expire(existing)
                raise StreamTurnConflict(self._conflict_code(existing)) from None
            conversation_id = input_data.get("conversation_id")
            unresolved = []
            if conversation_id:
                unresolved = self.db.query(StreamTurnModel.status).filter_by(
                    user_id=user_id, conversation_id=conversation_id,
                ).filter(StreamTurnModel.status.in_(["pending", "failed"])).all()
            log_event(
                "conversation.stream.conflict", source="reserve_integrity",
                pending_count=sum(status == "pending" for (status,) in unresolved),
                failed_count=sum(status == "failed" for (status,) in unresolved),
                **self._safe_integrity_fields(error),
            )
            if unresolved:
                raise StreamTurnConflict("PREVIOUS_TURN_UNRESOLVED") from None
            reused_attempt = self.db.query(StreamAttemptModel).filter_by(
                user_id=user_id, request_id=request_id,
            ).one_or_none()
            if reused_attempt is not None:
                raise StreamTurnConflict("IDEMPOTENCY_KEY_REUSED") from None
            raise
        return turn

    @staticmethod
    def _safe_integrity_fields(error: IntegrityError) -> dict[str, str]:
        diag = getattr(error.orig, "diag", None)
        raw = {
            "db_sqlstate": getattr(error.orig, "pgcode", None),
            "db_constraint": getattr(diag, "constraint_name", None),
            "db_table": getattr(diag, "table_name", None),
            "db_column": getattr(diag, "column_name", None),
        }
        return {
            key: value for key, value in raw.items()
            if isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_]{1,64}", value)
        }

    def complete_text(
        self, turn_id: str, *, conversation_id: str, assistant_message_id: str,
        attempt_id: str | None = None,
    ) -> None:
        query = self.db.query(StreamTurnModel).filter_by(id=turn_id, status="pending")
        if attempt_id is not None:
            query = query.filter_by(attempt_id=attempt_id)
        turn = query.one()
        turn.conversation_id = conversation_id
        turn.assistant_message_id = assistant_message_id
        turn.status = "completed"
        turn.deadline_at = datetime.utcnow() + TURN_DEADLINE
        turn.updated_at = datetime.utcnow()
        self._finish_attempt(turn, "completed", None)
        self.db.commit()

    def complete_audio(
        self, turn_id: str, *, error_code: str | None = None,
        attempt_id: str | None = None, audio_attempt_id: str | None = None,
    ) -> None:
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id).one()
        if (turn.audio_status == "pending"
                and (attempt_id is None or turn.attempt_id == attempt_id)
                and (audio_attempt_id is None or turn.audio_attempt_id == audio_attempt_id)):
            turn.audio_status = "failed" if error_code else "completed"
            turn.error_code = error_code
            turn.updated_at = datetime.utcnow()
            self.db.commit()

    def fail(self, turn_id: str, code: str, *, attempt_id: str | None = None) -> None:
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id).one()
        if turn.status == "pending" and (attempt_id is None or turn.attempt_id == attempt_id):
            turn.status = "failed"
            turn.audio_status = "failed"
            turn.error_code = code
            turn.updated_at = datetime.utcnow()
            self._finish_attempt(turn, "failed", code)
            self.db.commit()

    def retry(self, *, user_id: str, turn_id: str, request_id: str) -> StreamTurnModel:
        """같은 입력·사용자 메시지를 유지한 채 실패한 생성 시도만 교체해요."""
        turn = self.get(user_id, turn_id)
        if turn is None:
            raise LookupError(turn_id)
        if turn.status != "failed":
            raise StreamTurnConflict(self._conflict_code(turn))
        reused_turn = self.db.query(StreamTurnModel).filter_by(
            user_id=user_id, request_id=request_id,
        ).one_or_none()
        if reused_turn is not None:
            raise StreamTurnConflict("IDEMPOTENCY_KEY_REUSED")
        now = datetime.utcnow()
        attempt_id = str(uuid4())
        changed = self.db.query(StreamTurnModel).filter_by(id=turn_id, user_id=user_id, status="failed").update({
            "status": "pending", "audio_status": "pending", "error_code": None,
            "attempt_id": attempt_id, "audio_attempt_id": None,
            "deadline_at": now + TURN_DEADLINE, "updated_at": now,
        })
        if changed != 1:
            self.db.rollback()
            raise StreamTurnConflict("TURN_IN_PROGRESS")
        try:
            self.db.add(StreamAttemptModel(
                id=attempt_id, user_id=user_id, turn_id=turn_id, request_id=request_id,
                status="pending", started_at=now,
            ))
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            raise StreamTurnConflict("TURN_IN_PROGRESS") from None
        return self.get(user_id, turn_id)

    def retry_audio(self, *, user_id: str, turn_id: str) -> StreamTurnModel:
        turn = self.get(user_id, turn_id)
        if turn is None:
            raise LookupError(turn_id)
        if turn.status != "completed" or turn.audio_status not in {"failed", "completed"}:
            raise StreamTurnConflict("AUDIO_RETRY_NOT_AVAILABLE")
        now = datetime.utcnow()
        audio_attempt_id = str(uuid4())
        changed = self.db.query(StreamTurnModel).filter_by(
            id=turn_id, user_id=user_id, status="completed", audio_status=turn.audio_status
        ).update({
            "audio_status": "pending", "error_code": None,
            "audio_attempt_id": audio_attempt_id,
            "deadline_at": now + TURN_DEADLINE, "updated_at": now,
        })
        if changed != 1:
            self.db.rollback()
            raise StreamTurnConflict("AUDIO_RETRY_IN_PROGRESS")
        self.db.commit()
        return self.get(user_id, turn_id)

    def renew_audio(self, turn_id: str, audio_attempt_id: str) -> bool:
        now = datetime.utcnow()
        changed = self.db.query(StreamTurnModel).filter_by(
            id=turn_id, status="completed", audio_status="pending",
            audio_attempt_id=audio_attempt_id,
        ).update({"deadline_at": now + TURN_DEADLINE, "updated_at": now}, synchronize_session=False)
        self.db.commit()
        return bool(changed)

    def _expire(self, turn: StreamTurnModel) -> None:
        if turn.deadline_at >= datetime.utcnow():
            return
        if turn.status == "pending":
            self.fail(turn.id, "TURN_EXPIRED")
        elif turn.status == "completed" and turn.audio_status == "pending":
            self.complete_audio(turn.id, error_code="AUDIO_EXPIRED")

    def _finish_attempt(self, turn: StreamTurnModel, status: str, code: str | None) -> None:
        attempt = self.db.query(StreamAttemptModel).filter_by(id=turn.attempt_id).one()
        attempt.status = status
        attempt.error_code = code
        attempt.finished_at = datetime.utcnow()

    @staticmethod
    def _conflict_code(turn: StreamTurnModel) -> str:
        if turn.status == "pending":
            return "TURN_IN_PROGRESS"
        if turn.status == "completed":
            return "TURN_ALREADY_COMPLETED"
        return "TURN_FAILED_RETRY_REQUIRED"


def turn_status(turn: StreamTurnModel) -> dict:
    return {
        "turn_id": turn.id, "kind": turn.kind, "status": turn.status,
        "attempt_id": turn.attempt_id, "conversation_id": turn.conversation_id,
        "user_message_id": turn.user_message_id,
        "assistant_message_id": turn.assistant_message_id,
        "audio_status": turn.audio_status, "error_code": turn.error_code,
        "retryable": turn.status == "failed",
    }

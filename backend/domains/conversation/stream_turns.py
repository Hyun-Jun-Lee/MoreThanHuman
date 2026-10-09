"""음성 스트림의 영속 상태와 시도 기록."""

import json
from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.conversation.models import StreamAttemptModel, StreamTurnModel


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
        now = datetime.utcnow()
        turn = StreamTurnModel(
            id=str(uuid4()), user_id=user_id, request_id=request_id, kind=kind,
            input_json=json.dumps(input_data, ensure_ascii=False),
            status="pending", audio_status="pending", attempt_id=str(uuid4()),
            deadline_at=now + TURN_DEADLINE, created_at=now, updated_at=now,
        )
        attempt = StreamAttemptModel(
            id=turn.attempt_id, user_id=user_id, turn_id=turn.id, request_id=request_id,
            status="pending", started_at=now,
        )
        try:
            self.db.add_all([turn, attempt])
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            existing = self.db.query(StreamTurnModel).filter_by(user_id=user_id, request_id=request_id).one_or_none()
            if existing is None:
                raise StreamTurnConflict("IDEMPOTENCY_KEY_REUSED") from None
            self._expire(existing)
            raise StreamTurnConflict(self._conflict_code(existing)) from None
        return turn

    def complete_text(self, turn_id: str, *, conversation_id: str, assistant_message_id: str) -> None:
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id, status="pending").one()
        turn.conversation_id = conversation_id
        turn.assistant_message_id = assistant_message_id
        turn.status = "completed"
        turn.deadline_at = datetime.utcnow() + TURN_DEADLINE
        turn.updated_at = datetime.utcnow()
        self._finish_attempt(turn, "completed", None)
        self.db.commit()

    def link_user_message(self, turn_id: str, *, conversation_id: str, user_message_id: str) -> None:
        """확정 발화만 연결해 이후 생성 실패·재시도에도 같은 메시지를 가리켜요."""
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id, status="pending").one()
        if turn.user_message_id is not None and turn.user_message_id != user_message_id:
            raise StreamTurnConflict("USER_MESSAGE_ALREADY_COMMITTED")
        turn.conversation_id = conversation_id
        turn.user_message_id = user_message_id
        turn.updated_at = datetime.utcnow()
        self.db.commit()

    def complete_audio(self, turn_id: str, *, error_code: str | None = None) -> None:
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id).one()
        if turn.audio_status == "pending":
            turn.audio_status = "failed" if error_code else "completed"
            turn.error_code = error_code
            turn.updated_at = datetime.utcnow()
            self.db.commit()

    def fail(self, turn_id: str, code: str) -> None:
        turn = self.db.query(StreamTurnModel).filter_by(id=turn_id).one()
        if turn.status == "pending":
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
        now = datetime.utcnow()
        attempt_id = str(uuid4())
        changed = self.db.query(StreamTurnModel).filter_by(id=turn_id, user_id=user_id, status="failed").update({
            "status": "pending", "audio_status": "pending", "error_code": None,
            "attempt_id": attempt_id, "deadline_at": now + TURN_DEADLINE, "updated_at": now,
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

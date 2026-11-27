from datetime import datetime
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import ConversationType, MessageRole
from domains.conversation.models import ConversationModel, GuestTurnUsageModel, MessageModel, StreamAttemptModel, StreamTurnModel
from domains.conversation.repository import ConversationLocked, ConversationTurnsFull, GuestTurnsFull, PreviousTurnUnresolved
from domains.conversation.stream_flow import complete_generated_text, prepare_generation
from domains.conversation.stream_turns import StreamTurnConflict, StreamTurnStore
from shared.exceptions import NotFoundException


class _CountingSession(Session):
    commits = 0

    def commit(self):
        _CountingSession.commits += 1
        return super().commit()


class _BackgroundTasks:
    def start(self, coroutine):
        coroutine.close()


@pytest.fixture
def stream_db(monkeypatch):
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine, class_=_CountingSession)
    user_id = str(uuid4())
    conversation_id = str(uuid4())
    with sessions() as db:
        db.add(ProfileModel(id=user_id, email="stream-transaction@example.com", name="Learner",
                            slot_limit_snapshot=1))
        db.add(ConversationModel(
            id=conversation_id, user_id=user_id, conversation_type=ConversationType.FREE_CHAT,
            slot_active=True,
        ))
        db.add_all([
            MessageModel(id=str(uuid4()), conversation_id=conversation_id,
                         role=MessageRole.USER, content="Hello"),
            MessageModel(id=str(uuid4()), conversation_id=conversation_id,
                         role=MessageRole.ASSISTANT, content="How are you?"),
        ])
        db.commit()
    _CountingSession.commits = 0
    monkeypatch.setattr("domains.conversation.stream_flow.SessionLocal", sessions)
    monkeypatch.setattr("domains.conversation.stream_flow.settings.conversation_access_enabled", True)
    yield engine, sessions, user_id, conversation_id
    engine.dispose()


def _prepare(user_id: str, conversation_id: str, *, request_id: str | None = None, kind: str = "turn"):
    return prepare_generation(
        user_id=user_id, request_id=request_id or str(uuid4()), kind=kind,
        input_data={"conversation_id": conversation_id, "text": "I'm well.", "input_mode": "text"},
        http_client=None, background_tasks=_BackgroundTasks(),
    )


def test_guest_cannot_start_stream_roleplay_after_five_account_turns(stream_db):
    _engine, sessions, user_id, _conversation_id = stream_db
    with sessions() as db:
        profile = db.get(ProfileModel, user_id)
        profile.is_guest = True
        profile.email = None
        for index in range(5):
            db.add(
                GuestTurnUsageModel(
                    id=str(uuid4()),
                    user_id=user_id,
                    request_key=f"used-{index}",
                    status="committed",
                    committed_at=datetime.utcnow(),
                )
            )
        db.commit()

    with pytest.raises(GuestTurnsFull):
        prepare_generation(
            user_id=user_id,
            request_id=str(uuid4()),
            kind="roleplay_start",
            input_data={"role_character": "Barista"},
            http_client=None,
            background_tasks=_BackgroundTasks(),
        )


@pytest.mark.parametrize("kind", ["turn", "message"])
def test_new_turn_reads_history_once_and_commits_all_rows_together(stream_db, kind):
    engine, sessions, user_id, conversation_id = stream_db
    with sessions() as db:
        db.get(ConversationModel, conversation_id).topic_summary = "Initial cafe background"
        db.commit()
    _CountingSession.commits = 0
    statements = []

    def capture(_connection, _cursor, statement, _parameters, _context, _many):
        statements.append(statement.lower())

    event.listen(engine, "before_cursor_execute", capture)
    try:
        prepared = _prepare(user_id, conversation_id, kind=kind)
    finally:
        event.remove(engine, "before_cursor_execute", capture)

    assert _CountingSession.commits == 1
    assert sum(
        "from messages" in sql and sql.lstrip().startswith("select") and "count(" not in sql
        for sql in statements
    ) == 1
    assert prepared.history == [
        {"role": "user", "content": "Hello"},
        {"role": "assistant", "content": "How are you?"},
    ]
    assert "Initial cafe background" in prepared.system_prompt
    assert "Prioritize the user's current message and recent conversation" in prepared.system_prompt
    with sessions() as db:
        turn = db.get(StreamTurnModel, prepared.turn_id)
        assert turn.user_message_id == prepared.user_message_id
        assert db.get(StreamAttemptModel, prepared.attempt_id).turn_id == turn.id
        assert db.get(MessageModel, prepared.user_message_id).content == "I'm well."


def test_user_message_insert_failure_rolls_back_reservation(stream_db):
    engine, sessions, user_id, conversation_id = stream_db

    def fail_message_insert(_connection, _cursor, statement, _parameters, _context, _many):
        if statement.lower().lstrip().startswith("insert into messages"):
            raise RuntimeError("simulated insert failure")

    event.listen(engine, "before_cursor_execute", fail_message_insert)
    try:
        with pytest.raises(RuntimeError, match="simulated insert failure"):
            _prepare(user_id, conversation_id)
    finally:
        event.remove(engine, "before_cursor_execute", fail_message_insert)

    with sessions() as db:
        assert db.query(StreamTurnModel).count() == 0
        assert db.query(StreamAttemptModel).count() == 0
        assert db.query(MessageModel).filter_by(role=MessageRole.USER).count() == 1


def test_pending_turn_blocks_another_message_and_retry_reuses_user_message(stream_db):
    _engine, sessions, user_id, conversation_id = stream_db
    prepared = _prepare(user_id, conversation_id)

    with pytest.raises(PreviousTurnUnresolved):
        _prepare(user_id, conversation_id)
    with sessions() as db:
        StreamTurnStore(db).fail(prepared.turn_id, "LLM_FAILED")

    retried = prepare_generation(
        user_id=user_id, request_id=str(uuid4()), kind=None, input_data=None,
        retry_turn_id=prepared.turn_id, http_client=None, background_tasks=_BackgroundTasks(),
    )
    assert retried.user_message_id == prepared.user_message_id
    with sessions() as db:
        assert db.query(MessageModel).filter_by(role=MessageRole.USER).count() == 2
        assert db.query(StreamTurnModel).count() == 1


def test_member_legacy_locked_conversation_can_continue(stream_db):
    _engine, sessions, user_id, conversation_id = stream_db
    with sessions() as db:
        db.get(ConversationModel, conversation_id).slot_active = False
        db.commit()
    _prepare(user_id, conversation_id)
    with sessions() as db:
        assert db.query(StreamTurnModel).count() == 1


def test_turn_limit_creates_no_turn_or_message(stream_db):
    from shared.credit_ledger import CreditLedger, CreditsExhausted
    _engine, sessions, user_id, conversation_id = stream_db
    with sessions() as db:
        ledger = CreditLedger(db)
        profile = ledger.lock(user_id)
        for index in range(10):
            ledger.reserve(profile, str(index))
            ledger.commit(user_id, str(index))
        db.commit()
    with pytest.raises(CreditsExhausted):
        _prepare(user_id, conversation_id)
    with sessions() as db:
        assert db.query(StreamTurnModel).count() == 0
        assert db.query(MessageModel).count() == 2


def test_other_users_conversation_creates_no_turn(stream_db):
    _engine, sessions, _user_id, conversation_id = stream_db
    other_user_id = str(uuid4())
    with sessions() as db:
        db.add(ProfileModel(id=other_user_id, email="other-stream@example.com", name="Other",
                            slot_limit_snapshot=1))
        db.commit()

    with pytest.raises(NotFoundException):
        _prepare(other_user_id, conversation_id)
    with sessions() as db:
        assert db.query(StreamTurnModel).count() == 0


def test_missing_profile_cannot_access_conversation(stream_db):
    _engine, sessions, _user_id, conversation_id = stream_db
    with pytest.raises(NotFoundException):
        _prepare(str(uuid4()), conversation_id)
    with sessions() as db:
        assert db.query(StreamTurnModel).count() == 0


def test_completed_request_key_cannot_create_another_message(stream_db):
    _engine, sessions, user_id, conversation_id = stream_db
    request_id = str(uuid4())
    prepared = _prepare(user_id, conversation_id, request_id=request_id)
    complete_generated_text(user_id, prepared, "I'm glad to hear that.")

    with pytest.raises(StreamTurnConflict) as error:
        _prepare(user_id, conversation_id, request_id=request_id)
    assert error.value.code == "TURN_ALREADY_COMPLETED"
    with sessions() as db:
        assert db.query(StreamTurnModel).count() == 1
        assert db.query(MessageModel).filter_by(role=MessageRole.USER).count() == 2

def test_assistant_storage_failure_does_not_commit_credit(stream_db):
    from shared.billing_models import TurnReservationModel
    _engine, sessions, user_id, conversation_id = stream_db
    prepared = _prepare(user_id, conversation_id)
    def fail_assistant(_connection, _cursor, statement, _parameters, _context, _many):
        if statement.lower().lstrip().startswith("insert into messages"):
            raise RuntimeError("assistant storage failed")
    event.listen(_engine, "before_cursor_execute", fail_assistant)
    try:
        with pytest.raises(RuntimeError, match="assistant storage failed"):
            complete_generated_text(user_id, prepared, "A usable reply")
    finally:
        event.remove(_engine, "before_cursor_execute", fail_assistant)
    with sessions() as db:
        assert db.query(TurnReservationModel).one().status == "reserved"
        assert db.query(MessageModel).filter_by(role=MessageRole.ASSISTANT).count() == 1
        StreamTurnStore(db).fail(prepared.turn_id, "STORE_FAILED")
        assert db.query(TurnReservationModel).one().status == "released"


def test_empty_text_cannot_commit_and_pending_turn_blocks_delete(stream_db):
    from domains.conversation.repository import ConversationRepository
    from shared.billing_models import TurnReservationModel
    _engine, sessions, user_id, conversation_id = stream_db
    prepared = _prepare(user_id, conversation_id)
    with pytest.raises(ValueError, match="Empty assistant"):
        complete_generated_text(user_id, prepared, "  ")
    with sessions() as db:
        assert db.query(TurnReservationModel).one().status == "reserved"
        with pytest.raises(StreamTurnConflict) as error:
            ConversationRepository(db).delete_by_id(conversation_id, user_id)
        assert error.value.code == "TURN_IN_PROGRESS"
        db.rollback()
        StreamTurnStore(db).fail(prepared.turn_id, "CANCELED")
        ConversationRepository(db).delete_by_id(conversation_id, user_id)
        assert db.get(ConversationModel, conversation_id) is None
        assert db.query(TurnReservationModel).one().status == "released"


def test_successful_text_credit_survives_conversation_deletion(stream_db):
    from domains.conversation.repository import ConversationRepository
    from shared.credit_ledger import CreditLedger
    _engine, sessions, user_id, conversation_id = stream_db
    prepared = _prepare(user_id, conversation_id)
    complete_generated_text(user_id, prepared, "A usable reply")
    with sessions() as db:
        ConversationRepository(db).delete_by_id(conversation_id, user_id)
        ledger = CreditLedger(db)
        assert ledger.balance(ledger.lock(user_id))["remaining_turns"] == 9

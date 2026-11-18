import json
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import ConversationType
from domains.conversation.models import ConversationModel
from domains.conversation.router import _prepare_stream_or_http_error
from shared.latency import LatencyMiddleware


class _BackgroundTasks:
    def start(self, coroutine):
        coroutine.close()


@pytest.mark.asyncio
async def test_turn_preparation_logs_each_stage_without_message_content(monkeypatch, capsys):
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine)
    user_id = str(uuid4())
    conversation_id = str(uuid4())
    with sessions() as db:
        db.add(ProfileModel(id=user_id, email="latency@example.com", name="Learner"))
        db.add(ConversationModel(
            id=conversation_id, user_id=user_id, conversation_type=ConversationType.FREE_CHAT,
        ))
        db.commit()
    monkeypatch.setattr("domains.conversation.stream_flow.SessionLocal", sessions)

    app = FastAPI()
    app.add_middleware(LatencyMiddleware)

    @app.post("/api/test-stream-preparation/")
    def prepare():
        prepared = _prepare_stream_or_http_error(
            user_id=user_id, request_id=str(uuid4()), kind="turn",
            input_data={
                "conversation_id": conversation_id,
                "text": "private learner message",
                "input_mode": "text",
            },
            http_client=None, background_tasks=_BackgroundTasks(),
        )
        return {"turn_id": prepared.turn_id}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        success = await client.post("/api/test-stream-preparation/")
    assert success.status_code == 200
    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines() if line.startswith("{")]
    stages = {row.get("stage"): row for row in rows if row.get("stage")}
    expected = {
        "stream_prepare", "stream_precheck", "stream_reserve",
        "stream_precheck.ownership", "stream_precheck.access", "stream_precheck.unresolved",
        "stream_context.conversation", "stream_context.history_before",
        "stream_context.user_message", "stream_context.history_after",
        "stream_context.prompt",
    }
    assert expected <= stages.keys()
    assert all(stages[stage]["status"] == "ok" for stage in expected)
    assert all(stages[stage]["operation"] == "turn" for stage in expected)
    assert all(stages[stage]["start_offset_ms"] >= 0 for stage in expected)
    assert stages["stream_prepare"]["start_offset_ms"] <= stages["stream_precheck"]["start_offset_ms"]
    assert stages["stream_precheck"]["start_offset_ms"] <= stages["stream_reserve"]["start_offset_ms"]
    assert "private learner message" not in json.dumps(rows)
    engine.dispose()

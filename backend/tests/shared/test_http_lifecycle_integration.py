import importlib
import json
from contextlib import nullcontext
from types import SimpleNamespace

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from config import get_settings
from database import Base, get_db
from domains.conversation.router import router as conversation_router
from domains.grammar.models import GrammarFeedbackModel
from main import lifespan


def test_real_conversation_chain_uses_lifespan_clients_and_task_owned_db(monkeypatch):
    main_module = importlib.import_module("main")
    http_module = importlib.import_module("shared.http_clients")
    conversation_module = importlib.import_module("domains.conversation.service")
    monkeypatch.setattr(main_module.settings, "auto_create_tables", False)
    settings = get_settings()
    monkeypatch.setattr(settings, "supabase_url", "https://auth.test")
    monkeypatch.setattr(settings, "supabase_publishable_key", "test-public-key")
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    sessions, closed = [], []

    class TrackedSession(Session):
        def __init__(self, **kwargs):
            super().__init__(**kwargs)
            sessions.append(self)

        def close(self):
            closed.append(self)
            super().close()

    factory = sessionmaker(bind=engine, class_=TrackedSession)
    monkeypatch.setattr(conversation_module, "SessionLocal", factory)

    def request_db():
        with factory() as session:
            yield session

    created_clients, requests = [], []
    client_class = httpx.AsyncClient

    def make_client(**kwargs):
        pool_index = len(created_clients)

        def upstream(request):
            requests.append((pool_index, request.url.path))
            if request.url.path.endswith("/user"):
                return httpx.Response(200, json={
                    "id": "550e8400-e29b-41d4-a716-446655440000", "email": "learner@example.com",
                })
            if request.url.path.endswith("/transcriptions"):
                return httpx.Response(200, json={"text": "Hello there."})
            if request.url.path.endswith("/speech"):
                return httpx.Response(200, content=b"mp3", headers={"content-type": "audio/mpeg"})
            payload = json.loads(request.content)
            content = "Hello! How are you?"
            if len(payload["messages"]) == 1:
                content = json.dumps({"has_errors": False, "errors": [], "corrected_sentence": "Hello there."})
            return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})

        client = client_class(**kwargs, transport=httpx.MockTransport(upstream))
        created_clients.append(client)
        return client

    monkeypatch.setattr(http_module.httpx, "AsyncClient", make_client)
    app = FastAPI(lifespan=lifespan)
    app.include_router(conversation_router)
    app.dependency_overrides[get_db] = request_db
    try:
        with TestClient(app) as client:
            for _ in range(2):
                response = client.post(
                    "/api/conversations/start/free-chat/",
                    headers={"Authorization": "Bearer test-token"},
                    files={"audio_file": ("test.wav", b"RIFF\0\0\0\0WAVEfmt " + b"w" * 2048, "audio/wav")},
                    data={"include_audio_response": "true"},
                )
                assert response.status_code == 200, response.text
                assert response.json()["data"]["audio"]
                assert len(created_clients) == 2
                assert all(not outbound.is_closed for outbound in created_clients)
        assert all(outbound.is_closed for outbound in created_clients)
        assert all(pool == (1 if path.endswith("/user") else 0) for pool, path in requests)
        # 요청 2개와 문법 저장 2개가 각각 자신의 session을 생성·종료해요.
        assert len(sessions) == len(closed) == 4
        with Session(engine) as db:
            assert len(db.scalars(select(GrammarFeedbackModel)).all()) == 2
    finally:
        engine.dispose()


@pytest.mark.asyncio
@pytest.mark.parametrize("fail", [False, True])
async def test_cli_shares_one_client_across_languages_and_closes_it(monkeypatch, fail):
    cli = importlib.import_module("scripts.generate_language_snacks")
    clients = []
    monkeypatch.setattr(cli, "SessionLocal", lambda: nullcontext(object()))
    monkeypatch.setattr(cli, "LanguageSnackRepository", lambda db: db)

    class Generator:
        def __init__(self, repository, *, http_client):
            assert not http_client.is_closed
            clients.append(http_client)

        async def generate(self, *args):
            if fail:
                raise RuntimeError("test generation failure")
            return {"status": "succeeded"}

    monkeypatch.setattr(cli, "SnackGenerator", Generator)
    result = await cli.run(SimpleNamespace(language="all", run_key="test", per_type=1, dry_run=True))
    assert result == (1 if fail else 0)
    assert len(clients) == 2 and clients[0] is clients[1]
    assert clients[0].is_closed

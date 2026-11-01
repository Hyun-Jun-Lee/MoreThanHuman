from types import SimpleNamespace
from uuid import uuid4

import httpx
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.deletion import AccountDeletionService, supabase_admin_headers
from domains.auth.dependencies import get_verified_claims
from domains.auth.router import router
from domains.auth.models import AccountDeletionModel, ProfileModel
from domains.auth.repository import AuthRepository
from domains.conversation.enums import MessageRole
from domains.conversation.models import ConversationModel, MessageModel
from shared.subscription import AppleSubscriptionModel
from shared.exceptions import AuthenticationException
from database import get_db
from shared.http_clients import get_auth_http_client


def _db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_supabase_secret_key_is_only_sent_as_api_key():
    assert supabase_admin_headers("sb_secret_example") == {"apikey": "sb_secret_example"}


@pytest.mark.asyncio
async def test_delete_blocks_old_jwt_and_removes_learning_data(monkeypatch):
    db = _db()
    user_id = str(uuid4())
    conversation_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email="delete@example.com", name="Delete"))
    db.add(ConversationModel(id=conversation_id, user_id=user_id))
    db.add(MessageModel(id=str(uuid4()), conversation_id=conversation_id,
                        role=MessageRole.USER, content="hello"))
    db.add(AppleSubscriptionModel(original_transaction_id="100", user_id=user_id,
                                 last_transaction_id="101", product_id="Plus",
                                 environment="Sandbox", status="active"))
    db.commit()
    monkeypatch.setattr("domains.auth.deletion.cache_files", lambda: None)
    monkeypatch.setattr("domains.auth.deletion.get_settings", lambda: SimpleNamespace(
        supabase_secret_key="server-secret", supabase_auth_url="https://supabase.test/auth/v1",
        supabase_auth_timeout_seconds=1.0))
    calls = []
    def handle(request):
        calls.append(request)
        return httpx.Response(204)
    async with httpx.AsyncClient(transport=httpx.MockTransport(handle)) as client:
        service = AccountDeletionService(db, client)
        receipt = service.start(user_id)
        assert service.status(receipt) == "processing"
        assert service.status("bad") is None
        assert service.status("한" * 40) is None
        class Verifier:
            async def verify_access_token(self, _token):
                return SimpleNamespace(sub=user_id)
        with pytest.raises(HTTPException) as error:
            await get_verified_claims(HTTPAuthorizationCredentials(scheme="Bearer", credentials="old"), Verifier(), db)
        assert error.value.status_code == 401
        await service.process(user_id)
        assert service.status(receipt) == "completed"
        assert db.query(ProfileModel).count() == 0
        assert db.query(ConversationModel).count() == 0
        assert db.query(MessageModel).count() == 0
        assert db.query(AppleSubscriptionModel).count() == 0
        assert db.query(AccountDeletionModel).count() == 1
        with pytest.raises(AuthenticationException):
            AuthRepository(db).get_or_create_profile(
                profile_id=user_id, email="delete@example.com", name="Again", oauth_provider="google",
            )
        assert len(calls) == 1
        assert calls[0].headers["authorization"] == "Bearer server-secret"


@pytest.mark.asyncio
async def test_failed_auth_deletion_stays_processing_for_retry(monkeypatch):
    db = _db()
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email="retry@example.com", name="Retry"))
    db.commit()
    monkeypatch.setattr("domains.auth.deletion.cache_files", lambda: None)
    monkeypatch.setattr("domains.auth.deletion.get_settings", lambda: SimpleNamespace(
        supabase_secret_key="server-secret", supabase_auth_url="https://supabase.test/auth/v1",
        supabase_auth_timeout_seconds=1.0))
    responses = iter([httpx.Response(503), httpx.Response(204)])
    async with httpx.AsyncClient(transport=httpx.MockTransport(lambda _: next(responses))) as client:
        service = AccountDeletionService(db, client)
        receipt = service.start(user_id)
        with pytest.raises(RuntimeError):
            await service.process(user_id)
        db.rollback()
        assert service.status(receipt) == "processing"
        assert db.query(ProfileModel).count() == 0
        await service.process(user_id)
        assert service.status(receipt) == "completed"


@pytest.mark.asyncio
async def test_delete_route_returns_processing_receipt_when_admin_is_unavailable(monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    user_id = str(uuid4())
    with factory() as db:
        db.add(ProfileModel(id=user_id, email="route@example.com", name="Route", oauth_provider="google"))
        db.commit()
    settings = SimpleNamespace(supabase_secret_key="server-secret",
                               supabase_auth_url="https://supabase.test/auth/v1",
                               supabase_auth_timeout_seconds=1.0)
    monkeypatch.setattr("domains.auth.router.get_settings", lambda: settings)
    monkeypatch.setattr("domains.auth.deletion.get_settings", lambda: settings)
    monkeypatch.setattr("domains.auth.deletion.cache_files", lambda: None)
    app = FastAPI()
    app.include_router(router)

    def session():
        with factory() as db:
            yield db

    app.dependency_overrides[get_db] = session
    app.dependency_overrides[get_verified_claims] = lambda: SimpleNamespace(sub=user_id, oauth_provider="google")
    async with httpx.AsyncClient(transport=httpx.MockTransport(lambda _: httpx.Response(503))) as admin:
        app.dependency_overrides[get_auth_http_client] = lambda: admin
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
            deleted = await client.request("DELETE", "/api/auth/me", json={})
            assert deleted.status_code == 202
            data = deleted.json()["data"]
            assert data["status"] == "processing"
            assert len(data["receipt"]) >= 32
            status = await client.get(f"/api/auth/deletion-status/{data['receipt']}")
            assert status.json()["data"] == {"status": "processing"}

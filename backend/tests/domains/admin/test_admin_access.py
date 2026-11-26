from datetime import datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

import pytest
from pydantic import ValidationError
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from config import Settings
from database import Base, get_db
from domains.admin.models import AdminAccessSessionModel
from domains.admin.router import access_router, router as admin_router
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel  # noqa: F401 - mapper 등록


@pytest.fixture(autouse=True)
def admin_code_settings(monkeypatch):
    settings = SimpleNamespace(admin_access_code="test-shared-admin-code", is_dev=True)
    monkeypatch.setattr("domains.admin.access.get_settings", lambda: settings)
    return settings


def _client():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    user_id = str(uuid4())
    db.add(ProfileModel(id=user_id, email="user@example.com", name="User"))
    db.commit()
    app = FastAPI()
    app.include_router(admin_router)
    app.include_router(access_router)
    app.dependency_overrides[get_db] = lambda: db
    return db, TestClient(app), user_id


def test_admin_code_loads_from_environment_without_length_limit(monkeypatch):
    required = {
        "openrouter_api_key": "test", "openrouter_model": "test",
        "jwt_secret_key": "test", "grammar_model_provider": "openrouter",
    }
    for code in ("x", "x" * 300, ""):
        monkeypatch.setenv("ADMIN_ACCESS_CODE", code)
        assert Settings(_env_file=None, **required).admin_access_code == code
    monkeypatch.setenv("ADMIN_ACCESS_CODE", " has-surrounding-space ")
    with pytest.raises(ValidationError) as space_error:
        Settings(_env_file=None, **required)
    assert " has-surrounding-space " not in str(space_error.value)


def test_short_and_long_codes_unlock_admin_api(admin_code_settings):
    _, client, _ = _client()
    for code in ("x", "x" * 300):
        admin_code_settings.admin_access_code = code
        assert client.post("/api/admin/access/verify/", json={"code": code}).status_code == 200
        assert client.get("/api/admin/users/").status_code == 200


def test_code_alone_unlocks_admin_apis_and_writes_require_csrf():
    db, client, user_id = _client()
    assert client.get("/api/admin/users/").status_code == 401
    assert client.post("/api/admin/access/verify/", json={"code": "wrong"}).status_code == 403
    verified = client.post("/api/admin/access/verify/", json={"code": "test-shared-admin-code"})
    assert verified.status_code == 200
    csrf = verified.json()["data"]["csrf_token"]
    assert client.get("/api/admin/users/").status_code == 200
    path = f"/api/admin/users/{user_id}/manual-entitlement/"
    assert client.put(path, json={"plan": "plus"}).status_code == 403
    assert client.put(path, json={"plan": "plus"}, headers={
        "X-CSRF-Token": csrf, "Origin": "https://elsewhere.example",
    }).status_code == 403
    assert client.put(path, json={'request_id': str(uuid4()), 'resource_kind': 'slots', 'quantity': 3}, headers={"X-CSRF-Token": csrf}).status_code == 200
    assert client.post("/api/admin/access/logout/", headers={"X-CSRF-Token": csrf}).status_code == 200
    assert client.get("/api/admin/users/").status_code == 401


def test_missing_code_configuration_and_rotation(admin_code_settings):
    _, client, _ = _client()
    admin_code_settings.admin_access_code = None
    assert client.post("/api/admin/access/verify/", json={"code": "anything"}).status_code == 503
    admin_code_settings.admin_access_code = ""
    assert client.post("/api/admin/access/verify/", json={"code": "anything"}).status_code == 503
    admin_code_settings.admin_access_code = "test-shared-admin-code"
    assert client.post("/api/admin/access/verify/",
                       json={"code": "test-shared-admin-code"}).status_code == 200
    admin_code_settings.admin_access_code = "next-shared-admin-code"
    assert client.get("/api/admin/users/").status_code == 401
    assert client.post("/api/admin/access/verify/",
                       json={"code": "next-shared-admin-code"}).status_code == 200


def test_idle_session_expires_on_server():
    db, client, _ = _client()
    assert client.post("/api/admin/access/verify/",
                       json={"code": "test-shared-admin-code"}).status_code == 200
    session = db.query(AdminAccessSessionModel).one()
    session.last_seen_at = datetime.utcnow() - timedelta(minutes=31)
    db.commit()
    assert client.get("/api/admin/users/").status_code == 401


def test_five_wrong_codes_lock_only_the_request_ip():
    _, client, _ = _client()
    for _ in range(5):
        assert client.post("/api/admin/access/verify/", json={"code": "wrong"},
                           headers={"X-Real-IP": "192.0.2.1"}).status_code == 403
    assert client.post("/api/admin/access/verify/", json={"code": "test-shared-admin-code"},
                       headers={"X-Real-IP": "192.0.2.1"}).status_code == 429
    assert client.post("/api/admin/access/verify/", json={"code": "test-shared-admin-code"},
                       headers={"X-Real-IP": "192.0.2.2"}).status_code == 200

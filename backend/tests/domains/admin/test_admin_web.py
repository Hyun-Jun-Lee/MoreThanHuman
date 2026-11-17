from types import SimpleNamespace
from uuid import uuid4

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.admin.router import access_router, router as admin_router
from domains.admin.web import router as admin_web_router
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel  # noqa: F401 - mapper 등록


def test_admin_page_uses_only_shared_code(monkeypatch):
    monkeypatch.setattr("domains.admin.access.get_settings", lambda: SimpleNamespace(
        admin_access_code="test-shared-admin-code", is_dev=True,
    ))
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    db.add(ProfileModel(id=str(uuid4()), email="learner@example.com", name="Learner"))
    db.commit()
    app = FastAPI()
    app.include_router(admin_router)
    app.include_router(access_router)
    app.include_router(admin_web_router)
    app.dependency_overrides[get_db] = lambda: db
    client = TestClient(app)

    assert client.get("/admin", follow_redirects=False).headers["location"] == "/admin/login"
    login = client.get("/admin/login")
    assert "관리자 입장 코드" in login.text
    assert "maxlength=" not in login.text
    assert "Google로 로그인" not in login.text
    assert client.get("/api/admin/users/").status_code == 401

    verified = client.post("/api/admin/access/verify/", json={"code": "test-shared-admin-code"})
    assert verified.status_code == 200
    assert "사용자 권한 관리" in client.get("/admin").text
    assert client.get("/api/admin/users/").status_code == 200
    assert client.get("/api/admin/access/status/").json()["data"]["verified"] is True
    assert client.post("/api/admin/access/logout/", headers={
        "X-CSRF-Token": verified.json()["data"]["csrf_token"],
    }).status_code == 200
    assert client.get("/admin", follow_redirects=False).status_code == 303

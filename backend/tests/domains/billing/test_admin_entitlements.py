from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.admin.router import router as admin_router, access_router
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel  # noqa: F401 - mapper 등록
from shared.subscription import AppleSubscriptionModel, ManualEntitlementGrantModel, entitlement_for_user


@pytest.fixture(autouse=True)
def admin_code_settings(monkeypatch):
    monkeypatch.setattr("domains.admin.access.get_settings", lambda: SimpleNamespace(
        admin_access_code="test-shared-admin-code", is_dev=True,
    ))


def _setup():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    db = sessionmaker(bind=engine)()
    admin_id, user_id = str(uuid4()), str(uuid4())
    db.add_all([
        ProfileModel(id=admin_id, email="admin@example.com", name="Admin", is_admin=True),
        ProfileModel(id=user_id, email="learner@example.com", name="Learner", nickname="Tomato"),
    ])
    db.commit()
    app = FastAPI()
    app.include_router(admin_router)
    app.include_router(access_router)
    app.dependency_overrides[get_db] = lambda: db
    client = TestClient(app)
    verified = client.post("/api/admin/access/verify/", json={"code": "test-shared-admin-code"})
    assert verified.status_code == 200
    client.headers.update({"X-CSRF-Token": verified.json()["data"]["csrf_token"]})
    return db, client, app, admin_id, user_id


def test_admin_grant_update_scheduled_revoke_and_immediate_revoke():
    db, client, _, admin_id, user_id = _setup()
    revoke_at = (datetime.now(timezone.utc) + timedelta(days=2)).isoformat()
    path = f"/api/admin/users/{user_id}/manual-entitlement/"

    created = client.put(path, json={"plan": "advance", "revoke_at": revoke_at})
    assert created.status_code == 200
    assert created.json()["data"]["effective"]["plan"] == "advance"
    assert created.json()["data"]["effective"]["source"] == "manual"
    assert client.put(path, json={"plan": "advance", "revoke_at": revoke_at}).status_code == 200
    assert db.query(ManualEntitlementGrantModel).count() == 1

    updated = client.put(path, json={"plan": "plus", "revoke_at": revoke_at})
    assert updated.json()["data"]["effective"]["plan"] == "plus"
    history = client.get(f"/api/admin/users/{user_id}/manual-entitlement/history/")
    assert history.status_code == 200
    assert history.json()["data"]["total_count"] == 2
    assert history.json()["data"]["results"][1]["revoked_by"] is None
    assert history.json()["data"]["results"][0]["granted_by"] is None

    removed = client.delete(path)
    assert removed.status_code == 200
    assert removed.json()["data"]["effective"]["plan"] == "free"
    assert client.delete(path).status_code == 200
    assert db.query(ManualEntitlementGrantModel).count() == 2
    assert entitlement_for_user(db, user_id, now=datetime.fromisoformat(revoke_at).replace(tzinfo=None))['plan'] == 'free'


def test_apple_and_manual_choose_higher_plan_and_admin_is_unlimited():
    db, client, _, admin_id, user_id = _setup()
    db.add(AppleSubscriptionModel(
        original_transaction_id="apple-1", user_id=user_id, last_transaction_id="apple-2",
        product_id="Plus", environment="Sandbox", status="active",
        expires_at=datetime.utcnow() + timedelta(days=3),
    ))
    db.commit()
    path = f"/api/admin/users/{user_id}/manual-entitlement/"
    assert client.put(path, json={"plan": "advance", "revoke_at": None}).status_code == 200
    assert client.get(f"/api/admin/users/{user_id}/entitlement/").json()["data"]["effective"]["source"] == "apple"
    db.query(AppleSubscriptionModel).one().expires_at = datetime.utcnow() - timedelta(seconds=1)
    db.commit()
    assert entitlement_for_user(db, user_id)["plan"] == "advance"
    admin = entitlement_for_user(db, admin_id)
    assert admin["unlimited"] is True
    assert admin["slot_limit"] is None
    assert admin["turn_limit"] is None


def test_scheduled_revoke_falls_back_to_apple_without_a_job():
    db, client, _, _, user_id = _setup()
    expires = datetime.now(timezone.utc) + timedelta(days=1)
    db.add(AppleSubscriptionModel(
        original_transaction_id="apple-3", user_id=user_id, last_transaction_id="apple-4",
        product_id="Advance", environment="Sandbox", status="active",
        expires_at=datetime.utcnow() + timedelta(days=3),
    ))
    db.commit()
    response = client.put(f"/api/admin/users/{user_id}/manual-entitlement/",
                          json={"plan": "plus", "revoke_at": expires.isoformat()})
    assert response.status_code == 200
    before = entitlement_for_user(db, user_id, now=expires.replace(tzinfo=None) - timedelta(microseconds=1))
    after = entitlement_for_user(db, user_id, now=expires.replace(tzinfo=None))
    assert before["plan"] == "plus"
    assert after["plan"] == "advance"
    assert after["source"] == "apple"


def test_admin_unlimited_unlocks_all_conversations_and_demoting_relocks():
    from domains.conversation.repository import ConversationRepository
    from domains.conversation.enums import ConversationType

    db, _, _, admin_id, _ = _setup()
    admin = db.get(ProfileModel, admin_id)
    admin.is_admin = False
    db.commit()
    repository = ConversationRepository(db)
    for _ in range(3):
        db.add(ConversationModel(id=str(uuid4()), user_id=admin_id,
                                 conversation_type=ConversationType.FREE_CHAT))
    db.commit()
    assert repository.access_summary(admin_id, enabled=True)["locked_count"] == 2
    admin.is_admin = True
    db.commit()
    access = repository.access_summary(admin_id, enabled=True)
    assert access["slot_limit"] is None
    assert access["remaining_slots"] is None
    assert access["locked_count"] == 0
    assert access["can_create"] is True
    repository.create_with_access(ConversationModel(
        id=str(uuid4()), user_id=admin_id, conversation_type=ConversationType.FREE_CHAT,
    ), enabled=True)
    admin.is_admin = False
    db.commit()
    assert repository.access_summary(admin_id, enabled=True)["locked_count"] == 3


def test_manual_change_while_access_disabled_does_not_skip_later_slot_setup(monkeypatch):
    from domains.conversation.repository import ConversationRepository
    from domains.conversation.enums import ConversationType

    monkeypatch.setattr("domains.admin.service.get_settings", lambda: SimpleNamespace(
        conversation_access_enabled=False,
    ))
    db, client, _, _, user_id = _setup()
    path = f"/api/admin/users/{user_id}/manual-entitlement/"
    assert client.put(path, json={"plan": "plus"}).status_code == 200
    assert client.delete(path).status_code == 200
    assert db.get(ProfileModel, user_id).slot_limit_snapshot is None
    for _ in range(2):
        db.add(ConversationModel(id=str(uuid4()), user_id=user_id,
                                 conversation_type=ConversationType.FREE_CHAT, slot_active=False))
    db.commit()
    access = ConversationRepository(db).access_summary(user_id, enabled=True)
    assert access["slot_limit"] == 1
    assert access["locked_count"] == 1
    assert db.get(ProfileModel, user_id).slot_limit_snapshot == 1


def test_manual_change_reconciles_slots_immediately_when_access_enabled(monkeypatch):
    from domains.conversation.repository import ConversationRepository
    from domains.conversation.enums import ConversationType

    monkeypatch.setattr("domains.admin.service.get_settings", lambda: SimpleNamespace(
        conversation_access_enabled=True,
    ))
    db, client, _, _, user_id = _setup()
    for _ in range(2):
        db.add(ConversationModel(id=str(uuid4()), user_id=user_id,
                                 conversation_type=ConversationType.FREE_CHAT, slot_active=False))
    db.commit()
    repository = ConversationRepository(db)
    assert repository.access_summary(user_id, enabled=True)["locked_count"] == 1
    path = f"/api/admin/users/{user_id}/manual-entitlement/"
    assert client.put(path, json={"plan": "advance"}).status_code == 200
    assert db.query(ConversationModel).filter_by(user_id=user_id, slot_active=True).count() == 2
    assert client.delete(path).status_code == 200
    assert db.query(ConversationModel).filter_by(user_id=user_id, slot_active=True).count() == 1


def test_admin_user_list_detail_and_access_control():
    db, client, app, _, user_id = _setup()
    listing = client.get("/api/admin/users/", params={"q": "Tomato", "plan": "free", "source": "free"})
    assert listing.status_code == 200
    assert listing.json()["data"]["total_count"] == 1
    assert listing.json()["data"]["results"][0]["id"] == user_id
    assert client.put(f"/api/admin/users/{user_id}/manual-entitlement/",
                      json={"plan": "plus"}).status_code == 200
    manual_listing = client.get("/api/admin/users/", params={"plan": "plus", "source": "manual"})
    assert manual_listing.json()["data"]["total_count"] == 1
    assert manual_listing.json()["data"]["results"][0]["id"] == user_id
    detail = client.get(f"/api/admin/users/{user_id}/")
    assert detail.status_code == 200
    assert detail.json()["data"]["email"] == "learner@example.com"
    assert client.get(f"/api/admin/users/{uuid4()}/").status_code == 404
    client.cookies.clear()
    assert client.post("/api/admin/access/verify/",
                       json={"code": "wrong"}).status_code == 403
    assert client.get("/api/admin/users/").status_code == 401
    assert client.put(f"/api/admin/users/{user_id}/manual-entitlement/",
                      json={"plan": "plus"}).status_code == 401
    assert client.post("/api/admin/access/verify/",
                       json={"code": "test-shared-admin-code"}).status_code == 200
    assert client.get("/api/admin/users/").status_code == 200
    assert db.query(ManualEntitlementGrantModel).count() == 1


def test_filtered_user_list_batches_entitlement_queries():
    from domains.admin.service import AdminEntitlementService

    db, _, _, _, _ = _setup()
    db.add_all(ProfileModel(id=str(uuid4()), email=f"user-{index}@example.com", name="Learner")
               for index in range(204))
    db.commit()
    entitlement_queries = []

    def count_entitlement_query(_conn, _cursor, statement, _parameters, _context, _executemany):
        if statement.lstrip().lower().startswith("select") and (
            "apple_subscriptions" in statement or "manual_entitlement_grants" in statement
        ):
            entitlement_queries.append(statement)

    event.listen(db.get_bind(), "before_cursor_execute", count_entitlement_query)
    try:
        result = AdminEntitlementService(db).list_users(
            q=None, plan="free", source="free", is_admin=False, limit=3, offset=200,
        )
    finally:
        event.remove(db.get_bind(), "before_cursor_execute", count_entitlement_query)
    assert result["total_count"] == 205
    assert len(result["results"]) == 3
    assert len(entitlement_queries) <= 6


def test_grant_rejects_invalid_plan_and_revoke_time():
    db, client, _, _, user_id = _setup()
    path = f"/api/admin/users/{user_id}/manual-entitlement/"
    for payload in (
        {"plan": "free"},
        {"plan": "plus", "revoke_at": "2020-01-01T00:00:00Z"},
        {"plan": "plus", "revoke_at": "2099-01-01T00:00:00"},
    ):
        assert client.put(path, json=payload).status_code == 422
    assert db.query(ManualEntitlementGrantModel).count() == 0

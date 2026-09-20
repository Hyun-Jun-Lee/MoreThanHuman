from uuid import UUID, uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from domains.auth.dependencies import get_current_user
from domains.auth.models import ProfileModel
from domains.language_snacks.basket_reset import BasketResetRepository
from domains.language_snacks.dependencies import get_language_snack_operations_key
from domains.language_snacks.models import LanguageSnackBasketResetModel
from domains.language_snacks.router import router

PATH = "/api/v2/language-snacks/basket-reset/"
AUTH = {"X-Operations-Key": "test-operations-key"}


@pytest.fixture
def reset_client(repository):
    users = [
        ProfileModel(id=str(uuid4()), email=f"learner-{i}@example.com", name="Learner")
        for i in range(2)
    ]
    repository.db.add_all(users)
    repository.db.commit()
    current = [users[0]]
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_db] = lambda: repository.db
    app.dependency_overrides[get_current_user] = lambda: current[0]
    app.dependency_overrides[get_language_snack_operations_key] = lambda: (
        "test-operations-key"
    )
    return TestClient(app), users, current


def test_reset_is_persistent_scoped_and_replaces_only_latest_marker(
    reset_client, repository
):
    http, users, current = reset_client
    assert http.get(PATH).headers["Cache-Control"] == "no-store"
    assert http.get(PATH).json()["data"]["reset_id"] is None
    payload = {"user_id": users[0].id, "content_language": "en"}
    first = http.post(PATH, json=payload, headers=AUTH)
    assert first.status_code == 200, first.text
    marker = first.json()["data"]
    assert UUID(marker["reset_id"])
    assert marker["reset_at"]
    assert http.get(PATH).json()["data"] == marker
    assert (
        BasketResetRepository(repository.db).read(users[0].id, "en").reset_id
        == marker["reset_id"]
    )
    current[0] = users[1]
    assert http.get(PATH).json()["data"]["reset_id"] is None
    current[0] = users[0]
    users[0].target_language = "ko"
    assert http.get(PATH).json()["data"]["reset_id"] is None
    users[0].target_language = "en"
    second = http.post(PATH, json=payload, headers=AUTH).json()["data"]
    assert second["reset_id"] != marker["reset_id"]
    assert http.get(PATH).json()["data"] == second
    assert repository.db.query(LanguageSnackBasketResetModel).count() == 1
    korean = http.post(
        PATH, json={**payload, "content_language": "ko"}, headers=AUTH
    ).json()["data"]
    assert korean["reset_id"] != second["reset_id"]
    assert http.get(PATH).json()["data"] == second
    users[0].target_language = "ko"
    assert http.get(PATH).json()["data"] == korean
    assert repository.db.query(LanguageSnackBasketResetModel).count() == 2


def test_reset_requires_operations_key_and_valid_existing_user(reset_client):
    http, users, _ = reset_client
    payload = {"user_id": users[0].id, "content_language": "en"}
    for headers in [
        {},
        {"X-Operations-Key": "wrong"},
        {"Authorization": "Bearer learner"},
    ]:
        assert http.post(PATH, json=payload, headers=headers).status_code == 403
    assert (
        http.post(
            PATH, json={**payload, "user_id": str(uuid4())}, headers=AUTH
        ).status_code
        == 404
    )
    assert (
        http.post(
            PATH, json={**payload, "user_id": "invalid"}, headers=AUTH
        ).status_code
        == 422
    )
    assert (
        http.post(
            PATH, json={**payload, "content_language": "zh"}, headers=AUTH
        ).status_code
        == 422
    )


def test_read_requires_bearer_not_operations_key():
    app = FastAPI()
    app.include_router(router)
    assert TestClient(app).get(PATH, headers=AUTH).status_code == 403

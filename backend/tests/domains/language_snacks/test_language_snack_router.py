from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from domains.auth.dependencies import get_current_user
from domains.language_snacks.dependencies import get_language_snack_operations_key
from domains.language_snacks.generation_schemas import DedupeResult, QualityResult
from domains.language_snacks.generation_service import SnackGenerator
from domains.language_snacks.models import LanguageSnackModel
from domains.language_snacks.router import get_snack_generator, router


class TestGenerator(SnackGenerator):
    __test__ = False

    async def ask(self, instruction, data, schema):
        return (
            DedupeResult(decision="new")
            if schema is DedupeResult
            else QualityResult(valid=True, reason="Valid.")
        )


@pytest.fixture
def client(repository):
    app = FastAPI()
    app.include_router(router)
    user = SimpleNamespace(target_language="en")
    app.dependency_overrides[get_db] = lambda: repository.db
    app.dependency_overrides[get_current_user] = lambda: user
    app.dependency_overrides[get_language_snack_operations_key] = lambda: (
        "operations-key"
    )
    app.dependency_overrides[get_snack_generator] = lambda: TestGenerator(
        repository, provider=SimpleNamespace(get_provider_name=lambda: "fake")
    )
    return TestClient(app), user


def test_v2_creation_filter_archive_and_duplicate(client, sample, repository):
    http, user = client
    auth = {"X-Operations-Key": "operations-key"}
    response = http.post("/api/v2/language-snacks/", json=sample, headers=auth)
    assert response.status_code == 201, response.text
    assert "identity" not in response.json()["data"]
    assert len(http.get("/api/v2/language-snacks/").json()["data"]) == 1
    user.target_language = "ko"
    assert http.get("/api/v2/language-snacks/").json()["data"] == []
    key = response.json()["data"]["id"]
    assert (
        http.patch(
            f"/api/v2/language-snacks/{key}/status/",
            json={"status": "archived"},
            headers=auth,
        ).status_code
        == 200
    )
    assert (
        http.post("/api/v2/language-snacks/", json=sample, headers=auth).status_code
        == 409
    )
    assert repository.db.query(LanguageSnackModel).count() == 1


def test_operations_auth_validation_and_legacy(client, sample):
    http, _ = client
    assert http.post("/api/v2/language-snacks/", json=sample).status_code == 403
    assert (
        http.post(
            "/api/v2/language-snacks/",
            json=sample,
            headers={"X-Operations-Key": "wrong"},
        ).status_code
        == 403
    )
    assert http.get("/api/language-snacks/").json()["data"] == []
    assert (
        http.post(
            "/api/language-snacks/", headers={"X-Operations-Key": "operations-key"}
        ).status_code
        == 410
    )
    assert http.get("/api/v2/language-snacks/?limit=31").status_code == 422


def test_real_bearer_boundary():
    app = FastAPI()
    app.include_router(router)
    assert TestClient(app).get("/api/v2/language-snacks/").status_code == 403

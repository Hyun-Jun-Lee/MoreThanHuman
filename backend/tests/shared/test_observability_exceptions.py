import json

import httpx
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException
from starlette.background import BackgroundTask
from starlette.responses import Response

from main import (
    app_exception_handler, authentication_exception_handler, http_error_handler,
    not_found_exception_handler, validation_error_handler,
)
from shared.exceptions import AppException, AuthenticationException, ExternalAPIException, NotFoundException
from shared.latency import LatencyMiddleware
from shared.logging_config import log_exception


def _events(capsys):
    return [
        json.loads(line) for line in capsys.readouterr().out.splitlines()
        if line.startswith("{")
    ]


def _app():
    app = FastAPI()
    app.add_middleware(LatencyMiddleware)
    app.add_exception_handler(StarletteHTTPException, http_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(AuthenticationException, authentication_exception_handler)
    app.add_exception_handler(NotFoundException, not_found_exception_handler)
    app.add_exception_handler(AppException, app_exception_handler)
    return app


@pytest.mark.asyncio
async def test_http_and_validation_errors_are_logged_once_without_body(capsys):
    app = _app()

    class Input(BaseModel):
        name: str

    @app.get("/api/protected/")
    async def protected():
        raise HTTPException(status_code=401, detail="private-token")

    @app.post("/api/items/")
    async def create_item(value: Input):
        return value

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        unauthorized = await client.get("/api/protected/")
        invalid = await client.post("/api/items/", json={"name": {"private": "body-secret"}})

    rows = _events(capsys)
    assert [unauthorized.status_code, invalid.status_code] == [401, 422]
    assert sorted(row["status_code"] for row in rows if "method" in row) == [401, 422]
    assert sorted(row["error_code"] for row in rows if "error_code" in row) == ["HTTP_401", "REQUEST_VALIDATION_ERROR"]
    assert "private-token" not in json.dumps(rows)
    assert "body-secret" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_app_exceptions_preserve_response_and_log_safe_codes(capsys):
    app = _app()

    @app.get("/api/app-error/{kind}/")
    async def app_error(kind: str):
        errors = {
            "auth": AuthenticationException("private-auth"),
            "missing": NotFoundException("private-missing"),
            "other": AppException("private-other"),
        }
        raise errors[kind]

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        responses = [await client.get(f"/api/app-error/{kind}/")
                     for kind in ("auth", "missing", "other")]
    rows = _events(capsys)
    assert [response.status_code for response in responses] == [401, 404, 400]
    assert [response.json()["error"] for response in responses] == [
        "private-auth", "private-missing", "private-other"
    ]
    errors = [row for row in rows if "error_code" in row]
    assert {row["error_code"] for row in errors} == {
        "AUTHENTICATION_FAILED", "NOT_FOUND", "AppException"
    }
    assert len(errors) == 3
    assert "private-auth" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_unhandled_500_records_safe_stack_and_request_completion(capsys):
    app = _app()

    @app.get("/api/broken/")
    async def broken():
        local_secret = "local-secret"
        raise RuntimeError("message-secret " + local_secret)

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app, raise_app_exceptions=False), base_url="http://test"
    ) as client:
        response = await client.get("/api/broken/")

    rows = _events(capsys)
    assert response.status_code == 500
    assert len([row for row in rows if "method" in row]) == 1
    exception = next(row for row in rows if "error_code" in row)
    assert exception["exception_type"] == "RuntimeError"
    assert exception["stack_frames"][-1]["function"] == "broken"
    assert "message-secret" not in json.dumps(rows)
    assert "local-secret" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_converted_502_preserves_cause_without_duplicate_exception(capsys):
    app = _app()

    @app.get("/api/upstream/")
    async def upstream():
        try:
            raise ExternalAPIException("provider-secret")
        except ExternalAPIException as error:
            log_exception(error, status_code=502, error_code="EXTERNAL_API_FAILED")
            raise HTTPException(status_code=502, detail=error.message)

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        response = await client.get("/api/upstream/")
    rows = _events(capsys)
    errors = [row for row in rows if "error_code" in row]
    assert response.status_code == 502
    assert len(errors) == 1
    assert errors[0]["exception_type"] == "ExternalAPIException"
    assert "provider-secret" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_http_exception_handler_preserves_implicit_cause(capsys):
    app = _app()

    @app.get("/api/implicit-cause/")
    async def implicit_cause():
        try:
            raise ValueError("sensitive-value")
        except ValueError:
            raise HTTPException(status_code=503, detail="Unavailable")

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        response = await client.get("/api/implicit-cause/")
    rows = _events(capsys)
    errors = [row for row in rows if "error_code" in row]
    assert response.status_code == 503
    assert len(errors) == 1
    assert errors[0]["exception_type"] == "ValueError"
    assert errors[0]["stack_frames"][-1]["function"] == "implicit_cause"
    assert "sensitive-value" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_post_response_failure_is_separate_from_request_time(capsys):
    app = _app()

    def fail_after_response():
        raise RuntimeError("background-secret")

    @app.get("/api/background/")
    async def background():
        return Response(status_code=200, background=BackgroundTask(fail_after_response))

    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app, raise_app_exceptions=False), base_url="http://test"
    ) as client:
        response = await client.get("/api/background/")
    rows = _events(capsys)
    completed = next(row for row in rows if "method" in row)
    failed = next(row for row in rows if "exception_type" in row and "status_code" not in row)
    assert response.status_code == 200
    assert completed["response_complete"] is True
    assert completed["request_id"] == failed["request_id"]
    assert rows.index(completed) < rows.index(failed)
    assert "background-secret" not in json.dumps(rows)

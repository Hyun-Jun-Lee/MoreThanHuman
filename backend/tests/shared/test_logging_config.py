import json
import logging

import pytest
from config import get_settings

from shared.logging_config import configure_logging, log_event, log_exception


def test_json_logging_is_idempotent_and_omits_free_form_secrets(capsys, monkeypatch):
    monkeypatch.setattr(get_settings(), "env", "prod")
    configure_logging()
    configure_logging()
    logging.getLogger("domain.example").error(
        "private token %s", "super-secret", exc_info=ValueError("private exception")
    )
    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    matching = [row for row in rows if row.get("logger") == "domain.example"]
    assert len(matching) == 1
    assert matching[0]["service"] == "api"
    assert "super-secret" not in json.dumps(matching)
    assert "private exception" not in json.dumps(matching)


def test_exception_stack_has_locations_without_message_or_locals(capsys):
    try:
        local_secret = "local-secret"
        raise ValueError("message-secret")
    except ValueError as error:
        log_exception(error, status_code=500, error_code="UNHANDLED_EXCEPTION")
    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    exception = next(row for row in rows if row.get("error_code") == "UNHANDLED_EXCEPTION")
    assert exception["exception_type"] == "ValueError"
    assert exception["stack_frames"][-1]["function"] == "test_exception_stack_has_locations_without_message_or_locals"
    assert "message-secret" not in json.dumps(exception)
    assert local_secret not in json.dumps(exception)


def test_search_decision_logs_boolean_without_topic(capsys):
    log_event("search.pipeline", stage="search_decision", status="ok",
              search_required=False, topic="private resignation story")

    row = json.loads(capsys.readouterr().out.splitlines()[-1])
    assert row["search_required"] is False
    assert "private resignation story" not in json.dumps(row)


@pytest.mark.parametrize("environment", ["dev", "development", "local"])
def test_local_logger_prints_message_and_traceback(capsys, monkeypatch, environment):
    monkeypatch.setattr(get_settings(), "env", environment)
    configure_logging()
    try:
        raise RuntimeError("Missing startup configuration")
    except RuntimeError:
        logging.getLogger("uvicorn.error").exception("Application startup failed")
    row = json.loads(capsys.readouterr().out.splitlines()[-1])
    assert row["environment"] == environment
    assert row["message"] == "Application startup failed"
    assert "RuntimeError: Missing startup configuration" in row["traceback"]
    assert "test_local_logger_prints_message_and_traceback" in row["traceback"]


def test_uvicorn_preformatted_traceback_is_visible_and_secrets_redacted(capsys, monkeypatch):
    monkeypatch.setattr(get_settings(), "env", "dev")
    monkeypatch.setattr(get_settings(), "jwt_secret_key", "private-jwt-test-secret")
    monkeypatch.setattr(get_settings(), "billing_hmac_keys", {"v1": "private-hmac-test-secret"})
    configure_logging()
    logging.getLogger("uvicorn.error").error(
        "Traceback (most recent call last):\nRuntimeError: missing configuration %s %s",
        "private-jwt-test-secret", "private-hmac-test-secret",
    )
    row = json.loads(capsys.readouterr().out.splitlines()[-1])
    assert "Traceback" in row["message"]
    assert "missing configuration" in row["message"]
    assert "private-jwt-test-secret" not in row["message"]
    assert "private-hmac-test-secret" not in row["message"]

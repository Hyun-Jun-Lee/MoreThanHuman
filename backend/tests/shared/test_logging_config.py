import json
import logging

from shared.logging_config import configure_logging, log_exception


def test_json_logging_is_idempotent_and_omits_free_form_secrets(capsys):
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

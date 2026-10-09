"""API에서 허용한 필드만 JSON 한 줄로 stdout에 기록해요."""

import json
import logging
import os
import sys
from contextvars import ContextVar
from datetime import datetime, timezone
from pathlib import Path
from traceback import extract_tb
from typing import Any


request_context: ContextVar[dict[str, str] | None] = ContextVar("request_log_context", default=None)
exception_logged: ContextVar[bool] = ContextVar("request_exception_logged", default=False)
_project_root = Path(__file__).resolve().parents[1]
_allowed_fields = {
    "method", "route", "status_code", "duration_ms", "response_complete",
    "stage", "status", "error_code", "exception_type", "stack_frames",
    "proxy_request_id", "source", "provider", "model", "input_chars",
    "output_chars", "input_bytes", "output_bytes", "prompt_tokens",
    "completion_tokens", "logger", "file", "function", "line",
    "source_count", "accepted_count", "rejected_count", "response_chars",
    "recency_intent", "sufficient", "pending_count", "failed_count",
    "db_sqlstate", "db_constraint", "db_table", "db_column",
}


def safe_stack_frames(error: BaseException) -> list[dict[str, str | int]]:
    """예외 메시지·소스 코드·지역 변수 없이 호출 위치만 남겨요."""
    frames = []
    for frame in extract_tb(error.__traceback__)[-20:]:
        path = Path(frame.filename)
        try:
            file = str(path.resolve().relative_to(_project_root))
        except (OSError, ValueError):
            file = path.name
        frames.append({"file": file, "function": frame.name, "line": frame.lineno})
    return frames


def _safe_fields(fields: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in fields.items():
        if key not in _allowed_fields:
            continue
        if key == "stack_frames":
            if isinstance(value, list):
                result[key] = [
                    {name: frame[name] for name in ("file", "function", "line") if name in frame}
                    for frame in value[:20] if isinstance(frame, dict)
                ]
        elif isinstance(value, (str, int, float, bool)) or value is None:
            result[key] = value[:128] if isinstance(value, str) else value
    return result


class JsonLogHandler(logging.Handler):
    """자유 형식 메시지와 exc_info는 출력하지 않아요."""

    def emit(self, record: logging.LogRecord) -> None:
        try:
            context = request_context.get() or {}
            structured = getattr(record, "structured_fields", {})
            fields = _safe_fields(structured) if isinstance(structured, dict) else {}
            if not getattr(record, "event", None):
                fields = {
                    "logger": record.name,
                    "file": Path(record.pathname).name,
                    "function": record.funcName,
                    "line": record.lineno,
                }
            payload = {
                "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "level": record.levelname,
                "service": "api",
                "environment": os.getenv("ENV", "dev"),
                "trace_id": context.get("trace_id"),
                "request_id": context.get("request_id"),
                **fields,
            }
            if context.get("proxy_request_id"):
                payload["proxy_request_id"] = context["proxy_request_id"]
            sys.stdout.write(json.dumps(payload, ensure_ascii=True, separators=(",", ":")) + "\n")
            sys.stdout.flush()
        except (OSError, TypeError, ValueError):
            # 로그 출력 장애가 HTTP 응답을 바꾸지 않도록 해요.
            pass


def configure_logging() -> None:
    root = logging.getLogger()
    handler = next((item for item in root.handlers if isinstance(item, JsonLogHandler)), None)
    root.handlers[:] = [handler or JsonLogHandler()]
    root.setLevel(logging.INFO)
    for name in ("uvicorn", "uvicorn.error", "uvicorn.access"):
        logger = logging.getLogger(name)
        logger.handlers.clear()
        logger.propagate = True
    for name in ("httpx", "httpcore", "sqlalchemy.engine"):
        logging.getLogger(name).setLevel(logging.WARNING)


def log_event(event: str, *, level: int = logging.INFO, **fields: Any) -> None:
    handlers = logging.getLogger().handlers
    if len(handlers) != 1 or not isinstance(handlers[0], JsonLogHandler):
        configure_logging()
    logging.getLogger("api.observability").log(
        level, event, extra={"event": event, "structured_fields": fields}
    )


def log_exception(error: BaseException, *, status_code: int, error_code: str) -> None:
    if request_context.get() is not None:
        if exception_logged.get():
            return
        exception_logged.set(True)
    fields: dict[str, Any] = {
        "status_code": status_code,
        "error_code": error_code,
        "exception_type": type(error).__name__,
    }
    if status_code >= 500:
        fields["stack_frames"] = safe_stack_frames(error)
    log_event("http.exception", level=logging.ERROR if status_code >= 500 else logging.WARNING, **fields)

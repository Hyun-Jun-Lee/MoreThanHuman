"""요청 전체 시간과 내부 단계 시간을 구조화 로그로 기록해요."""

import asyncio
import logging
import re
from collections.abc import Iterator
from contextlib import contextmanager
from time import perf_counter
from uuid import uuid4

from starlette.types import ASGIApp, Message, Receive, Scope, Send

from shared.logging_config import (
    configure_logging, exception_logged, log_event, log_exception,
    request_context, safe_stack_frames,
)


_turn_path = re.compile(
    r"^/api/conversations/(?:start/(?:free-chat(?:/suggested)?|roleplay)|[^/]+/(?:turn|message))(?:/stream)?/?$"
)
_valid_id = re.compile(r"[a-f0-9]{32}")
LogValue = str | int | float | bool | None


def current_trace_id() -> str | None:
    context = request_context.get()
    return context["trace_id"] if context else None


def _emit_stage(stage: str, started: float, status: str = "ok", **fields: LogValue) -> None:
    if request_context.get() is None:
        return
    log_event(
        "http.stage.completed", level=logging.INFO if status == "ok" else logging.WARNING,
        stage=stage, status=status, duration_ms=round((perf_counter() - started) * 1000, 1),
        **fields,
    )


@contextmanager
def latency_span(stage: str, **fields: LogValue) -> Iterator[dict[str, LogValue]]:
    """예외를 그대로 전파하고 단계별 성공·실패 시간을 한 번 기록해요."""
    started = perf_counter()
    status = "error"
    try:
        yield fields
        status = "ok"
    finally:
        _emit_stage(stage, started, status, **fields)


class LatencyMiddleware:
    """본문을 버퍼링하지 않고 인증 전부터 최종 응답 body까지 측정해요."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app
        configure_logging()

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or not (
            scope["path"].startswith("/api/") or scope["path"] == "/health"
        ):
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers", []))
        candidate = headers.get(b"x-request-id", b"").decode("ascii", errors="replace")
        trace_id = candidate if _valid_id.fullmatch(candidate) else uuid4().hex
        proxy_candidate = headers.get(b"x-proxy-request-id", b"").decode("ascii", errors="replace")
        context = {"trace_id": trace_id, "request_id": uuid4().hex}
        if _valid_id.fullmatch(proxy_candidate):
            context["proxy_request_id"] = proxy_candidate
        token = request_context.set(context)
        exception_token = exception_logged.set(False)
        started = perf_counter()
        status_code = 500
        response_complete = False
        completion_logged = False
        cancelled = False

        def emit_completed() -> None:
            nonlocal completion_logged
            if completion_logged:
                return
            completion_logged = True
            route = getattr(scope.get("route"), "path", "<unmatched>")
            log_event(
                "http.request.completed",
                level=logging.INFO if status_code < 400 and response_complete else logging.WARNING,
                method=scope["method"], route=route, status_code=status_code,
                duration_ms=round((perf_counter() - started) * 1000, 1),
                response_complete=response_complete,
                status="cancelled" if cancelled else "ok" if status_code < 400 and response_complete else "error",
            )
            if scope["method"] == "POST" and _turn_path.fullmatch(scope["path"]):
                _emit_stage("server_total", started, "ok" if status_code < 400 and response_complete else "error", status_code=status_code, response_complete=response_complete)

        async def timed_send(message: Message) -> None:
            nonlocal status_code, response_complete
            if message["type"] == "http.response.start":
                status_code = message["status"]
                response_headers = [
                    (key, value) for key, value in message.get("headers", [])
                    if key.lower() != b"x-request-id"
                ]
                message = {
                    **message,
                    "headers": response_headers + [(b"x-request-id", trace_id.encode("ascii"))],
                }
            await send(message)
            if message["type"] == "http.response.body" and not message.get("more_body", False):
                response_complete = True
                emit_completed()

        try:
            await self.app(scope, receive, timed_send)
        except asyncio.CancelledError:
            cancelled = True
            raise
        except Exception as error:
            if response_complete:
                log_event("background_task.failed", level=logging.ERROR,
                          exception_type=type(error).__name__, stack_frames=safe_stack_frames(error))
            else:
                log_exception(error, status_code=500, error_code="UNHANDLED_EXCEPTION")
            raise
        finally:
            emit_completed()
            exception_logged.reset(exception_token)
            request_context.reset(token)

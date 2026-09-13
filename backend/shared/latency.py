"""음성 대화의 요청별 경과 시간을 stdout에 기록해요."""
import json
import re
from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from time import perf_counter
from uuid import uuid4

from starlette.types import ASGIApp, Message, Receive, Scope, Send


_request_context: ContextVar[dict[str, str] | None] = ContextVar("latency_context", default=None)
_turn_path = re.compile(
    r"^/api/conversations/(?:start/(?:free-chat|roleplay)|[^/]+/(?:turn|message))/?$"
)
LogValue = str | int | float | bool | None


def _emit(stage: str, started: float, status: str = "ok", **fields: LogValue) -> None:
    context = _request_context.get()
    if context is None:
        return
    record = {
        **context,
        "source": "server",
        "stage": stage,
        "status": status,
        "elapsed_ms": round((perf_counter() - started) * 1000, 1),
        **fields,
    }
    try:
        print("[latency] " + json.dumps(record, ensure_ascii=True), flush=True)
    except OSError:
        # 로그 출력 실패가 대화 응답을 바꾸지 않도록 해요.
        pass


@contextmanager
def latency_span(stage: str, **fields: LogValue) -> Iterator[dict[str, LogValue]]:
    """예외를 그대로 전파하고 성공·실패 경과 시간을 한 번 기록해요."""
    started = perf_counter()
    status = "error"
    try:
        yield fields
        status = "ok"
    finally:
        _emit(stage, started, status, **fields)


class LatencyMiddleware:
    """본문을 버퍼링하지 않고 인증 전부터 응답 전송까지 측정해요."""

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if (
            scope["type"] != "http"
            or scope["method"] != "POST"
            or not _turn_path.fullmatch(scope["path"])
        ):
            await self.app(scope, receive, send)
            return

        headers = dict(scope.get("headers", []))
        candidate = headers.get(b"x-request-id", b"").decode("ascii", errors="replace")
        trace_id = candidate if re.fullmatch(r"[a-f0-9]{32}", candidate) else uuid4().hex
        token = _request_context.set({"trace_id": trace_id, "request_id": uuid4().hex})
        started = perf_counter()
        status_code = 500
        finished = False

        async def timed_send(message: Message) -> None:
            nonlocal status_code, finished
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
                finished = True
                _emit("server_total", started, "ok" if status_code < 400 else "error", status_code=status_code)

        try:
            await self.app(scope, receive, timed_send)
        finally:
            if not finished:
                _emit("server_total", started, "error", status_code=status_code, response_complete=False)
            _request_context.reset(token)

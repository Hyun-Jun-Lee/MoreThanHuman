"""요청별 SQL 실행 통계를 민감한 SQL 텍스트 없이 수집해요."""

from contextvars import ContextVar
from dataclasses import dataclass, field
from threading import Lock
from time import perf_counter

from sqlalchemy import event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import QueuePool
from sqlalchemy.util import queue as sqla_queue

from shared.logging_config import log_event


_SLOW_QUERY_MS = 250.0
_QUERY_KINDS = {"SELECT", "INSERT", "UPDATE", "DELETE"}
_commit_started_key = "_api_latency_commit_started"


@dataclass
class DbRequestStats:
    """스레드풀로 복사된 ContextVar에서도 같은 요청 객체를 공유해요."""

    query_count: int = 0
    query_total_ms: float = 0.0
    max_query_ms: float = 0.0
    checkout_count: int = 0
    acquire_total_ms: float = 0.0
    max_acquire_ms: float = 0.0
    pool_wait_count: int = 0
    pool_wait_total_ms: float = 0.0
    pool_wait_max_ms: float = 0.0
    connect_count: int = 0
    connect_total_ms: float = 0.0
    connect_max_ms: float = 0.0
    commit_count: int = 0
    commit_total_ms: float = 0.0
    closed: bool = False
    _lock: Lock = field(default_factory=Lock, repr=False)

    def add_query(self, elapsed_ms: float) -> None:
        with self._lock:
            if self.closed:
                return
            self.query_count += 1
            self.query_total_ms += elapsed_ms
            self.max_query_ms = max(self.max_query_ms, elapsed_ms)

    def add_checkout(self) -> None:
        with self._lock:
            if not self.closed:
                self.checkout_count += 1

    def add_acquire(self, elapsed_ms: float) -> None:
        with self._lock:
            if not self.closed:
                self.acquire_total_ms += elapsed_ms
                self.max_acquire_ms = max(self.max_acquire_ms, elapsed_ms)

    def add_pool_wait(self, elapsed_ms: float) -> None:
        with self._lock:
            if not self.closed:
                self.pool_wait_count += 1
                self.pool_wait_total_ms += elapsed_ms
                self.pool_wait_max_ms = max(self.pool_wait_max_ms, elapsed_ms)

    def add_connect(self, elapsed_ms: float) -> None:
        with self._lock:
            if not self.closed:
                self.connect_count += 1
                self.connect_total_ms += elapsed_ms
                self.connect_max_ms = max(self.connect_max_ms, elapsed_ms)

    def add_commit(self, elapsed_ms: float) -> None:
        with self._lock:
            if not self.closed:
                self.commit_count += 1
                self.commit_total_ms += elapsed_ms

    def finish(self) -> dict[str, int | float]:
        with self._lock:
            self.closed = True
            if not (self.query_count or self.checkout_count or self.commit_count
                    or self.pool_wait_count or self.connect_count):
                return {}
            return {
                "db_query_count": self.query_count,
                "db_query_total_ms": round(self.query_total_ms, 1),
                "db_max_query_ms": round(self.max_query_ms, 1),
                "db_checkout_count": self.checkout_count,
                "db_acquire_total_ms": round(self.acquire_total_ms, 1),
                "db_max_acquire_ms": round(self.max_acquire_ms, 1),
                "db_pool_wait_count": self.pool_wait_count,
                "db_pool_wait_total_ms": round(self.pool_wait_total_ms, 1),
                "db_pool_wait_max_ms": round(self.pool_wait_max_ms, 1),
                "db_connect_count": self.connect_count,
                "db_connect_total_ms": round(self.connect_total_ms, 1),
                "db_connect_max_ms": round(self.connect_max_ms, 1),
                "db_acquire_other_ms": round(max(
                    0.0, self.acquire_total_ms - self.pool_wait_total_ms - self.connect_total_ms
                ), 1),
                "db_commit_count": self.commit_count,
                "db_commit_total_ms": round(self.commit_total_ms, 1),
            }


db_request_stats: ContextVar[DbRequestStats | None] = ContextVar("db_request_stats", default=None)


class TimedPoolQueue(sqla_queue.Queue):
    """풀이 포화되어 블로킹 큐 조회를 할 때 걸린 시간을 남겨요."""

    def get(self, block=True, timeout=None):
        if not block:
            return super().get(block, timeout)
        started = perf_counter()
        try:
            return super().get(block, timeout)
        finally:
            stats = db_request_stats.get()
            if stats is not None:
                stats.add_pool_wait((perf_counter() - started) * 1000)


class TimedQueuePool(QueuePool):
    """전체 획득·블로킹 큐 조회·새 DBAPI 연결 생성 시간을 남겨요."""

    _queue_class = TimedPoolQueue

    def __init__(self, creator, **kwargs):
        super().__init__(creator, **kwargs)
        invoke_creator = self._invoke_creator

        def timed_creator(record):
            started = perf_counter()
            try:
                return invoke_creator(record)
            finally:
                stats = db_request_stats.get()
                if stats is not None:
                    stats.add_connect((perf_counter() - started) * 1000)

        self._invoke_creator = timed_creator

    def connect(self):
        started = perf_counter()
        try:
            return super().connect()
        finally:
            stats = db_request_stats.get()
            if stats is not None:
                stats.add_acquire((perf_counter() - started) * 1000)


def _query_kind(statement: str) -> str:
    parts = statement.lstrip().split(None, 1)
    kind = parts[0].upper() if parts else ""
    return kind if kind in _QUERY_KINDS else "OTHER"


def install_db_latency(engine: Engine) -> None:
    """엔진 하나에 커서·풀 이벤트를 한 번 연결해요."""

    @event.listens_for(engine, "before_cursor_execute")
    def before_query(connection, cursor, statement, parameters, context, executemany):
        if db_request_stats.get() is not None:
            context._api_latency_query_started = (perf_counter(), _query_kind(statement))

    def finish_query(context) -> None:
        started = getattr(context, "_api_latency_query_started", None)
        stats = db_request_stats.get()
        if started is None or stats is None or stats.closed:
            return
        context._api_latency_query_started = None
        started_at, kind = started
        elapsed_ms = (perf_counter() - started_at) * 1000
        stats.add_query(elapsed_ms)
        if elapsed_ms >= _SLOW_QUERY_MS:
            log_event("db.slow_query", stage="db_slow_query",
                      query_kind=kind, duration_ms=round(elapsed_ms, 1))

    @event.listens_for(engine, "after_cursor_execute")
    def after_query(connection, cursor, statement, parameters, context, executemany):
        finish_query(context)

    @event.listens_for(engine, "handle_error")
    def failed_query(exception_context):
        if exception_context.execution_context is not None:
            finish_query(exception_context.execution_context)

    @event.listens_for(engine.pool, "checkout")
    def checkout(connection, record, proxy):
        stats = db_request_stats.get()
        if stats is not None:
            stats.add_checkout()


@event.listens_for(Session, "before_commit")
def _before_commit(session):
    if db_request_stats.get() is not None:
        session.info[_commit_started_key] = perf_counter()


@event.listens_for(Session, "after_commit")
def _after_commit(session):
    started = session.info.pop(_commit_started_key, None)
    stats = db_request_stats.get()
    if started is not None and stats is not None:
        stats.add_commit((perf_counter() - started) * 1000)


@event.listens_for(Session, "after_soft_rollback")
def _failed_commit(session, previous_transaction):
    session.info.pop(_commit_started_key, None)

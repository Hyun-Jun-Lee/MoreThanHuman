"""모든 스낵 쓰기를 직렬화하는 세션 락."""

from contextlib import contextmanager
from threading import Lock

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.pool import NullPool

from config import get_settings
from shared.exceptions import AppException

LOCK_ID = 761249831
_local_lock = Lock()


class SnackError(AppException):
    def __init__(self, code, status_code=503):
        super().__init__(code)
        self.code = code
        self.status_code = status_code


class Guard:
    def __init__(self, connection=None, pid=None):
        self.connection = connection
        self.pid = pid

    def check(self):
        if self.connection is not None:
            if self.connection.closed or self.connection.invalidated:
                raise SnackError("lock_connection_lost")
            try:
                if self.connection.scalar(text("SELECT pg_backend_pid()")) != self.pid:
                    raise SnackError("lock_connection_lost")
            except SQLAlchemyError:
                raise SnackError("lock_connection_lost") from None


@contextmanager
def mutation_lock(bind):
    if bind.dialect.name == "sqlite":
        # SQLite는 개발·단위 테스트용이며 다중 프로세스 worker를 지원하지 않아요.
        if not _local_lock.acquire(blocking=False):
            raise SnackError("generation_busy")
        try:
            yield Guard()
        finally:
            _local_lock.release()
        return
    settings = get_settings()
    engine = create_engine(
        settings.language_snacks_lock_database_url or bind.url,
        poolclass=NullPool,
        isolation_level="AUTOCOMMIT",
    )
    try:
        with engine.connect() as connection:
            if not connection.scalar(
                text("SELECT pg_try_advisory_lock(:key)"), {"key": LOCK_ID}
            ):
                raise SnackError("generation_busy")
            guard = Guard(
                connection, connection.scalar(text("SELECT pg_backend_pid()"))
            )
            try:
                yield guard
            finally:
                if not connection.closed and not connection.invalidated:
                    connection.execute(
                        text("SELECT pg_advisory_unlock(:key)"), {"key": LOCK_ID}
                    )
    finally:
        engine.dispose()

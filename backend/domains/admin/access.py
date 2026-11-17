import hashlib
import hmac
import secrets
from datetime import datetime, timedelta

from fastapi import Request, Response
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from config import get_settings
from domains.admin.models import (
    AdminAccessAttemptModel,
    AdminAccessSessionModel,
)

SESSION_IDLE = timedelta(minutes=30)
SESSION_LIFETIME = timedelta(hours=8)
ATTEMPT_WINDOW = timedelta(minutes=15)
MAX_FAILED_ATTEMPTS = 5


class AdminAccessDenied(Exception):
    pass


class AdminAccessLocked(Exception):
    pass


class AdminCodeUnavailable(Exception):
    pass


def cookie_name() -> str:
    return "tomatalk-admin" if get_settings().is_dev else "__Host-tomatalk-admin"


def set_session_cookie(response: Response, token: str) -> None:
    response.set_cookie(
        cookie_name(), token, max_age=int(SESSION_LIFETIME.total_seconds()),
        httponly=True, secure=not get_settings().is_dev, samesite="strict", path="/",
    )


def clear_session_cookie(response: Response) -> None:
    response.delete_cookie(cookie_name(), path="/", secure=not get_settings().is_dev,
                           httponly=True, samesite="strict")


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def session_token_hash(token: str, code: str) -> str:
    return hmac.new(code.encode("utf-8"), token.encode("utf-8"), hashlib.sha256).hexdigest()


def attempt_key(request: Request) -> str:
    client_ip = request.headers.get("x-real-ip") or (request.client.host if request.client else "unknown")
    return token_hash(client_ip)


class AdminAccessService:
    def __init__(self, db: Session):
        self.db = db

    def session(self, token: str | None) -> AdminAccessSessionModel | None:
        code = get_settings().admin_access_code
        if not token or not code:
            return None
        row = self.db.get(AdminAccessSessionModel, session_token_hash(token, code))
        if row is None:
            return None
        now = datetime.utcnow()
        if now >= row.expires_at or now - row.last_seen_at >= SESSION_IDLE:
            self.db.delete(row)
            self.db.commit()
            return None
        row.last_seen_at = now
        self.db.commit()
        return row

    def create_session(self, code: str, *, previous_token: str | None = None) -> tuple[AdminAccessSessionModel, str]:
        now = datetime.utcnow()
        self.db.query(AdminAccessSessionModel).filter(AdminAccessSessionModel.expires_at <= now).delete()
        token = secrets.token_urlsafe(32)
        row = AdminAccessSessionModel(
            token_hash=session_token_hash(token, code),
            csrf_token=secrets.token_urlsafe(32), created_at=now, last_seen_at=now,
            expires_at=now + SESSION_LIFETIME,
        )
        if previous_token:
            previous = self.db.get(AdminAccessSessionModel, session_token_hash(previous_token, code))
            if previous is not None:
                self.db.delete(previous)
        self.db.add(row)
        self.db.commit()
        return row, token

    def verify_code(self, code: str, client_key: str, *, previous_token: str | None = None) -> tuple[AdminAccessSessionModel, str]:
        configured_code = get_settings().admin_access_code
        if not configured_code:
            raise AdminCodeUnavailable
        now = datetime.utcnow()
        dialect = self.db.get_bind().dialect.name
        insert = pg_insert if dialect == "postgresql" else sqlite_insert
        statement = insert(AdminAccessAttemptModel).values(
            client_key=client_key, failed_count=0, window_started_at=now,
        ).on_conflict_do_nothing(index_elements=["client_key"])
        self.db.execute(statement)
        attempt = self.db.query(AdminAccessAttemptModel).filter_by(client_key=client_key).with_for_update().one()
        if attempt.locked_until is not None and now < attempt.locked_until:
            raise AdminAccessLocked
        if now - attempt.window_started_at >= ATTEMPT_WINDOW:
            attempt.failed_count = 0
            attempt.window_started_at = now
            attempt.locked_until = None
        if not secrets.compare_digest(code.encode("utf-8"), configured_code.encode("utf-8")):
            attempt.failed_count += 1
            if attempt.failed_count >= MAX_FAILED_ATTEMPTS:
                attempt.locked_until = now + ATTEMPT_WINDOW
            self.db.commit()
            raise AdminAccessDenied
        attempt.failed_count = 0
        attempt.window_started_at = now
        attempt.locked_until = None
        return self.create_session(configured_code, previous_token=previous_token)

    def logout(self, row: AdminAccessSessionModel) -> None:
        self.db.delete(row)
        self.db.commit()

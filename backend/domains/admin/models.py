from datetime import datetime

from sqlalchemy import Column, DateTime, Integer, String

from database import Base


class AdminAccessSessionModel(Base):
    __tablename__ = "admin_access_sessions"

    token_hash = Column(String(64), primary_key=True)
    csrf_token = Column(String(64), nullable=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    last_seen_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=False)


class AdminAccessAttemptModel(Base):
    __tablename__ = "admin_access_attempts"

    client_key = Column(String(64), primary_key=True)
    failed_count = Column(Integer, nullable=False, default=0)
    window_started_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    locked_until = Column(DateTime, nullable=True)

"""스낵 표시 데이터, 지식 예약 및 생성 실행 기록."""

from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSONB

from database import Base


def utcnow():
    return datetime.now(UTC)


def json_type():
    return JSON(none_as_null=True).with_variant(JSONB(none_as_null=True), "postgresql")


class LanguageSnackRunModel(Base):
    __tablename__ = "language_snack_generation_runs"
    id = Column(String(36), primary_key=True)
    run_key = Column(String(160), nullable=False, unique=True)
    content_language = Column(String(8), nullable=False)
    status = Column(String(20), nullable=False, default="running")
    target_per_type = Column(Integer, nullable=False)
    metrics = Column(json_type(), nullable=False, default=dict)
    started_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    finished_at = Column(DateTime(timezone=True))


class LanguageSnackModel(Base):
    __tablename__ = "language_snacks"
    __table_args__ = (
        Index(
            "ix_language_snacks_feed",
            "content_language",
            "status",
            "published_at",
            "id",
        ),
        CheckConstraint(
            "content_type IN ('regional_variant','usage_contrast','homonym')",
            name="ck_snack_type",
        ),
        CheckConstraint(
            "status IN ('reserved','draft','published','archived')",
            name="ck_snack_status",
        ),
        CheckConstraint(
            "status NOT IN ('draft','published') OR payload IS NOT NULL",
            name="ck_snack_payload",
        ),
        CheckConstraint(
            "status != 'published' OR published_at IS NOT NULL",
            name="ck_snack_published",
        ),
        CheckConstraint(
            "content_language IN ('en','ko') AND explanation_language IN ('en','ko')",
            name="ck_snack_language",
        ),
    )
    id = Column(String(36), primary_key=True)
    content_type = Column(String(32), nullable=False)
    schema_version = Column(Integer, nullable=False, default=1)
    content_language = Column(String(8), nullable=False)
    explanation_language = Column(String(8), nullable=False)
    identity = Column(json_type(), nullable=False)
    identity_version = Column(Integer, nullable=False, default=1)
    knowledge_key = Column(String(64), nullable=False, unique=True)
    knowledge_summary = Column(Text, nullable=False)
    payload = Column(json_type())
    status = Column(String(20), nullable=False, default="reserved")
    origin = Column(String(20), nullable=False)
    generation_run_id = Column(
        String(36), ForeignKey("language_snack_generation_runs.id")
    )
    generation_metadata = Column(json_type(), nullable=False, default=dict)
    published_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    updated_at = Column(
        DateTime(timezone=True), nullable=False, default=utcnow, onupdate=utcnow
    )

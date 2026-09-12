"""Replace disposable v1 snacks with typed content and generation history.

Revision ID: 20260912_0001
Revises: 20260906_0002
Both upgrade and downgrade discard snack content, never other domain data.
"""

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

from alembic import op

revision = "20260912_0001"
down_revision = "20260906_0002"
branch_labels = None
depends_on = None


def upgrade():
    op.drop_table("language_snacks")
    json_type = sa.JSON(none_as_null=True).with_variant(
        JSONB(none_as_null=True), "postgresql"
    )
    op.create_table(
        "language_snack_generation_runs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("run_key", sa.String(160), nullable=False, unique=True),
        sa.Column("content_language", sa.String(8), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("target_per_type", sa.Integer(), nullable=False),
        sa.Column("metrics", json_type, nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True)),
    )
    op.create_table(
        "language_snacks",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("content_type", sa.String(32), nullable=False),
        sa.Column("schema_version", sa.Integer(), nullable=False),
        sa.Column("content_language", sa.String(8), nullable=False),
        sa.Column("explanation_language", sa.String(8), nullable=False),
        sa.Column("identity", json_type, nullable=False),
        sa.Column("identity_version", sa.Integer(), nullable=False),
        sa.Column("knowledge_key", sa.String(64), nullable=False, unique=True),
        sa.Column("knowledge_summary", sa.Text(), nullable=False),
        sa.Column("payload", json_type),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("origin", sa.String(20), nullable=False),
        sa.Column(
            "generation_run_id",
            sa.String(36),
            sa.ForeignKey("language_snack_generation_runs.id"),
        ),
        sa.Column("generation_metadata", json_type, nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "content_type IN ('regional_variant','usage_contrast','homonym')",
            name="ck_snack_type",
        ),
        sa.CheckConstraint(
            "status IN ('reserved','draft','published','archived')",
            name="ck_snack_status",
        ),
        sa.CheckConstraint(
            "status NOT IN ('draft','published') OR payload IS NOT NULL",
            name="ck_snack_payload",
        ),
        sa.CheckConstraint(
            "status != 'published' OR published_at IS NOT NULL",
            name="ck_snack_published",
        ),
        sa.CheckConstraint(
            "content_language IN ('en','ko') AND explanation_language IN ('en','ko')",
            name="ck_snack_language",
        ),
    )
    op.create_index(
        "ix_language_snacks_feed",
        "language_snacks",
        ["content_language", "status", "published_at", "id"],
    )


def downgrade():
    op.drop_table("language_snacks")
    op.drop_table("language_snack_generation_runs")
    op.create_table(
        "language_snacks",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("left_label", sa.String(48), nullable=False),
        sa.Column("left_word", sa.String(80), nullable=False),
        sa.Column("right_label", sa.String(48), nullable=False),
        sa.Column("right_word", sa.String(80), nullable=False),
        sa.Column("meaning", sa.String(160), nullable=False),
        sa.Column("example", sa.String(240), nullable=False),
        sa.Column("published_at", sa.DateTime()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index(
        "ix_language_snacks_published_at_id", "language_snacks", ["published_at", "id"]
    )

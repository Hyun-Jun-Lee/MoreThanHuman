"""Publish weekly conversation topics and reserve suggested starts."""

import sqlalchemy as sa
from alembic import op

revision = "20261003_0001"
down_revision = "20261001_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "weekly_topic_batches",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("native_language", sa.String(8), nullable=False),
        sa.Column("target_language", sa.String(8), nullable=False),
        sa.Column("week_start", sa.Date(), nullable=False),
        sa.Column("published_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("native_language", "target_language", "week_start", name="uq_weekly_topic_batch_pair_week"),
    )
    op.create_table(
        "weekly_topics",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("batch_id", sa.String(36), sa.ForeignKey("weekly_topic_batches.id", ondelete="CASCADE"), nullable=False),
        sa.Column("text", sa.String(200), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("archived_at", sa.DateTime()),
    )
    op.create_index("ix_weekly_topics_batch_id", "weekly_topics", ["batch_id"])
    op.create_table(
        "suggested_starts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column("topic_id", sa.String(36), sa.ForeignKey("weekly_topics.id"), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("conversations.id", ondelete="CASCADE")),
        sa.Column("assistant_message_id", sa.String(36), sa.ForeignKey("messages.id", ondelete="CASCADE")),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("user_id", "request_id", name="uq_suggested_start_user_request"),
    )
    op.create_index("ix_suggested_starts_user_id", "suggested_starts", ["user_id"])


def downgrade():
    op.drop_index("ix_suggested_starts_user_id", table_name="suggested_starts")
    op.drop_table("suggested_starts")
    op.drop_index("ix_weekly_topics_batch_id", table_name="weekly_topics")
    op.drop_table("weekly_topics")
    op.drop_table("weekly_topic_batches")

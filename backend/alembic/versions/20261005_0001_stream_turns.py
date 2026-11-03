"""Persist voice stream turns and attempts."""

from alembic import op
import sqlalchemy as sa

revision = "20261005_0001"
down_revision = "20261004_0002"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "stream_turns",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column("kind", sa.String(32), nullable=False),
        sa.Column("input_json", sa.Text(), nullable=False),
        sa.Column("conversation_id", sa.String(36), sa.ForeignKey("conversations.id", ondelete="CASCADE")),
        sa.Column("user_message_id", sa.String(36), sa.ForeignKey("messages.id", ondelete="SET NULL")),
        sa.Column("assistant_message_id", sa.String(36), sa.ForeignKey("messages.id", ondelete="SET NULL")),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("audio_status", sa.String(16), nullable=False),
        sa.Column("error_code", sa.String(64)),
        sa.Column("attempt_id", sa.String(36), nullable=False),
        sa.Column("deadline_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("user_id", "request_id", name="uq_stream_turn_user_request"),
    )
    op.create_index("ix_stream_turns_user_id", "stream_turns", ["user_id"])
    op.create_index("ix_stream_turns_conversation_id", "stream_turns", ["conversation_id"])
    op.create_table(
        "stream_attempts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("turn_id", sa.String(36), sa.ForeignKey("stream_turns.id", ondelete="CASCADE"), nullable=False),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("error_code", sa.String(64)),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("finished_at", sa.DateTime()),
        sa.UniqueConstraint("user_id", "request_id", name="uq_stream_attempt_user_request"),
    )
    op.create_index("ix_stream_attempts_turn_id", "stream_attempts", ["turn_id"])


def downgrade():
    op.drop_index("ix_stream_attempts_turn_id", table_name="stream_attempts")
    op.drop_table("stream_attempts")
    op.drop_index("ix_stream_turns_conversation_id", table_name="stream_turns")
    op.drop_index("ix_stream_turns_user_id", table_name="stream_turns")
    op.drop_table("stream_turns")

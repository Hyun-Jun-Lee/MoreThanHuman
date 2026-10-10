"""Persist a file manifest and generation lease for conversation audio."""

from alembic import op
import sqlalchemy as sa

revision = "20261010_0001"
down_revision = "20261009_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "conversation_audio_cache",
        sa.Column("message_id", sa.String(36), sa.ForeignKey("messages.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("manifest_json", sa.Text(), nullable=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("lease_id", sa.String(36), nullable=True),
        sa.Column("lease_until", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_stream_turns_assistant_message_id", "stream_turns", ["assistant_message_id"])


def downgrade():
    op.drop_index("ix_stream_turns_assistant_message_id", table_name="stream_turns")
    op.drop_table("conversation_audio_cache")

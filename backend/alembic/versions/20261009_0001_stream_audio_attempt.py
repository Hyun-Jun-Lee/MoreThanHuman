"""Track the active audio-only retry separately from AI attempts."""

from alembic import op
import sqlalchemy as sa

revision = "20261009_0001"
down_revision = "20261005_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("stream_turns", sa.Column("audio_attempt_id", sa.String(36), nullable=True))
    predicate = sa.text("status IN ('pending','failed') AND conversation_id IS NOT NULL")
    op.create_index(
        "uq_stream_turn_unresolved_conversation", "stream_turns",
        ["user_id", "conversation_id"], unique=True,
        sqlite_where=predicate, postgresql_where=predicate,
    )


def downgrade():
    op.drop_index("uq_stream_turn_unresolved_conversation", table_name="stream_turns")
    op.drop_column("stream_turns", "audio_attempt_id")

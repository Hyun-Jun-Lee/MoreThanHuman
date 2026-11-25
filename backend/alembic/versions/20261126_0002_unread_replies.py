"""기존 AI 답변은 읽음으로 이관하고 새 답변의 읽음 시각을 보관해요."""
from alembic import op
import sqlalchemy as sa

revision = "20261126_0002"
down_revision = "20261126_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("messages", sa.Column("read_at", sa.DateTime(), nullable=True))
    op.execute("UPDATE messages SET read_at = created_at WHERE role = 'ASSISTANT'")
    op.create_index("ix_messages_conversation_role_read", "messages", ["conversation_id", "role", "read_at"])


def downgrade():
    op.drop_index("ix_messages_conversation_role_read", table_name="messages")
    op.drop_column("messages", "read_at")

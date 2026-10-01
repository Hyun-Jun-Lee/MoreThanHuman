"""Add legacy conversation allowance and permanent slot grants."""

import sqlalchemy as sa
from alembic import op

revision = "20261001_0001"
down_revision = "20260919_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("profiles", sa.Column("legacy_conversation_slots", sa.Integer(), nullable=True))
    op.create_table(
        "conversation_slot_grants",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("purchase_key", sa.String(255), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
    )
    op.create_index("ix_conversation_slot_grants_user_id", "conversation_slot_grants", ["user_id"])


def downgrade():
    op.drop_index("ix_conversation_slot_grants_user_id", table_name="conversation_slot_grants")
    op.drop_table("conversation_slot_grants")
    op.drop_column("profiles", "legacy_conversation_slots")

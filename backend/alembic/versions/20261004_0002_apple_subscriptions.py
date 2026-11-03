"""Add Apple subscriptions and active conversation selection."""

from alembic import op
import sqlalchemy as sa

revision = "20261004_0002"
down_revision = "20261004_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("profiles", sa.Column("slot_limit_snapshot", sa.Integer(), nullable=True))
    op.add_column("conversations", sa.Column("slot_active", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_index("ix_conversations_user_slot_active", "conversations", ["user_id", "slot_active"])
    op.create_table(
        "apple_subscriptions",
        sa.Column("original_transaction_id", sa.String(64), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("last_transaction_id", sa.String(64), nullable=False),
        sa.Column("product_id", sa.String(32), nullable=False),
        sa.Column("environment", sa.String(16), nullable=False),
        sa.Column("status", sa.String(32), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=True),
        sa.Column("grace_expires_at", sa.DateTime(), nullable=True),
        sa.Column("verified_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_apple_subscriptions_user_id", "apple_subscriptions", ["user_id"])
    op.create_index("ix_apple_subscriptions_user_status", "apple_subscriptions", ["user_id", "status"])
    op.create_table(
        "apple_subscription_notifications",
        sa.Column("notification_uuid", sa.String(64), primary_key=True),
        sa.Column("original_transaction_id", sa.String(64), nullable=True),
        sa.Column("received_at", sa.DateTime(), nullable=False),
    )


def downgrade():
    op.drop_table("apple_subscription_notifications")
    op.drop_index("ix_apple_subscriptions_user_status", table_name="apple_subscriptions")
    op.drop_index("ix_apple_subscriptions_user_id", table_name="apple_subscriptions")
    op.drop_table("apple_subscriptions")
    op.drop_index("ix_conversations_user_slot_active", table_name="conversations")
    op.drop_column("conversations", "slot_active")
    op.drop_column("profiles", "slot_limit_snapshot")

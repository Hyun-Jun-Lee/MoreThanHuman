"""Persist account deletion requests so previously issued JWTs stay blocked."""

from alembic import op
import sqlalchemy as sa

revision = "20261101_0001"
down_revision = "20261018_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "account_deletions",
        sa.Column("user_id", sa.String(36), primary_key=True),
        sa.Column("receipt_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
    )


def downgrade():
    op.drop_table("account_deletions")

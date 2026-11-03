"""Add per-user and language basket reset markers without deleting snacks."""

import sqlalchemy as sa

from alembic import op

revision = "20260919_0001"
down_revision = "20260912_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "language_snack_basket_resets",
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("profiles.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("content_language", sa.String(8), primary_key=True),
        sa.Column("reset_id", sa.String(36), nullable=False),
        sa.Column("reset_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "content_language IN ('en','ko')", name="ck_snack_basket_reset_language"
        ),
    )


def downgrade():
    op.drop_table("language_snack_basket_resets")

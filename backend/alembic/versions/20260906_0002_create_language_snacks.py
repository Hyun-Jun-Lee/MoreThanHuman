"""create language snacks

Revision ID: 20260906_0002
Revises: 20260906_0001
Create Date: 2026-09-06 21:30:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260906_0002"
down_revision: Union[str, Sequence[str], None] = "20260906_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create the persistent, common language snack store."""
    op.create_table(
        "language_snacks",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("category", sa.String(length=40), nullable=False),
        sa.Column("left_label", sa.String(length=48), nullable=False),
        sa.Column("left_word", sa.String(length=80), nullable=False),
        sa.Column("right_label", sa.String(length=48), nullable=False),
        sa.Column("right_word", sa.String(length=80), nullable=False),
        sa.Column("meaning", sa.String(length=160), nullable=False),
        sa.Column("example", sa.String(length=240), nullable=False),
        sa.Column("published_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_language_snacks_published_at_id",
        "language_snacks",
        ["published_at", "id"],
        unique=False,
    )


def downgrade() -> None:
    """Drop only the language snack structure."""
    op.drop_index("ix_language_snacks_published_at_id", table_name="language_snacks")
    op.drop_table("language_snacks")

"""add language context

Revision ID: 20260720_0001
Revises: 20260718_0001
Create Date: 2026-07-20 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260720_0001"
down_revision: Union[str, Sequence[str], None] = "20260718_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "profiles",
        sa.Column("native_language", sa.String(length=8), nullable=False, server_default="ko"),
    )
    op.add_column(
        "profiles",
        sa.Column("target_language", sa.String(length=8), nullable=False, server_default="en"),
    )
    op.add_column(
        "profiles",
        sa.Column("feedback_language", sa.String(length=8), nullable=False, server_default="ko"),
    )
    op.add_column(
        "conversations",
        sa.Column("native_language", sa.String(length=8), nullable=False, server_default="ko"),
    )
    op.add_column(
        "conversations",
        sa.Column("target_language", sa.String(length=8), nullable=False, server_default="en"),
    )
    op.add_column(
        "conversations",
        sa.Column("feedback_language", sa.String(length=8), nullable=False, server_default="ko"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("conversations", "feedback_language")
    op.drop_column("conversations", "target_language")
    op.drop_column("conversations", "native_language")
    op.drop_column("profiles", "feedback_language")
    op.drop_column("profiles", "target_language")
    op.drop_column("profiles", "native_language")

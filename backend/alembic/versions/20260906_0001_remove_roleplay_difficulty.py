"""remove roleplay difficulty

Revision ID: 20260906_0001
Revises: 20260828_0001
Create Date: 2026-09-06 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260906_0001"
down_revision: Union[str, Sequence[str], None] = "20260828_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


ROLEPLAY_DIFFICULTY_VALUES = (
    "EASY",
    "NORMAL",
    "CHALLENGE",
)
ROLEPLAY_DIFFICULTY_ENUM_NAME = "roleplaydifficulty"


def _roleplay_difficulty_type() -> sa.Enum:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        return postgresql.ENUM(
            *ROLEPLAY_DIFFICULTY_VALUES,
            name=ROLEPLAY_DIFFICULTY_ENUM_NAME,
            create_type=False,
        )
    return sa.Enum(*ROLEPLAY_DIFFICULTY_VALUES, name=ROLEPLAY_DIFFICULTY_ENUM_NAME)


def upgrade() -> None:
    """Drop the legacy manual roleplay difficulty column and enum."""
    with op.batch_alter_table("conversations") as batch_op:
        batch_op.drop_column("roleplay_difficulty")

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        postgresql.ENUM(
            *ROLEPLAY_DIFFICULTY_VALUES,
            name=ROLEPLAY_DIFFICULTY_ENUM_NAME,
        ).drop(bind, checkfirst=True)


def downgrade() -> None:
    """Restore only the nullable schema; historical values remain deleted."""
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        postgresql.ENUM(
            *ROLEPLAY_DIFFICULTY_VALUES,
            name=ROLEPLAY_DIFFICULTY_ENUM_NAME,
        ).create(bind, checkfirst=True)

    with op.batch_alter_table("conversations") as batch_op:
        batch_op.add_column(sa.Column("roleplay_difficulty", _roleplay_difficulty_type(), nullable=True))

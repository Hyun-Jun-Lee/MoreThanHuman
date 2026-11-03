"""add roleplay difficulty

Revision ID: 20260814_0001
Revises: 20260720_0001
Create Date: 2026-08-14 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "20260814_0001"
down_revision: Union[str, Sequence[str], None] = "20260720_0001"
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
    """Upgrade schema."""
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        postgresql.ENUM(
            *ROLEPLAY_DIFFICULTY_VALUES,
            name=ROLEPLAY_DIFFICULTY_ENUM_NAME,
        ).create(bind, checkfirst=True)

    op.add_column(
        "conversations",
        sa.Column("roleplay_difficulty", _roleplay_difficulty_type(), nullable=True),
    )
    op.execute(
        "UPDATE conversations "
        "SET roleplay_difficulty = 'NORMAL' "
        "WHERE conversation_type = 'ROLE_PLAYING' "
        "AND roleplay_difficulty IS NULL"
    )

    with op.batch_alter_table("conversations") as batch_op:
        batch_op.alter_column(
            "role_character",
            existing_type=sa.String(length=100),
            type_=sa.String(length=500),
            existing_nullable=True,
        )


def downgrade() -> None:
    """Downgrade schema."""
    op.execute(
        "UPDATE conversations "
        "SET role_character = substr(role_character, 1, 100) "
        "WHERE role_character IS NOT NULL "
        "AND length(role_character) > 100"
    )

    with op.batch_alter_table("conversations") as batch_op:
        batch_op.alter_column(
            "role_character",
            existing_type=sa.String(length=500),
            type_=sa.String(length=100),
            existing_nullable=True,
        )
        batch_op.drop_column("roleplay_difficulty")

    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        postgresql.ENUM(
            *ROLEPLAY_DIFFICULTY_VALUES,
            name=ROLEPLAY_DIFFICULTY_ENUM_NAME,
        ).drop(bind, checkfirst=True)

"""add profile app locale

Revision ID: 20260828_0001
Revises: 20260814_0001
Create Date: 2026-08-28 15:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260828_0001"
down_revision: Union[str, Sequence[str], None] = "20260814_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("profiles", sa.Column("app_locale", sa.String(length=2), nullable=True))


def downgrade() -> None:
    op.drop_column("profiles", "app_locale")

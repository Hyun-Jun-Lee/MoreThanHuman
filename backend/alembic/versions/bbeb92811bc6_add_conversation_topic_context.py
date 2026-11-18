"""add conversation topic context

Revision ID: bbeb92811bc6
Revises: 20261115_0004
Create Date: 2026-11-19 02:00:33.985402

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'bbeb92811bc6'
down_revision: Union[str, Sequence[str], None] = '20261115_0004'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('conversations', sa.Column('topic', sa.Text(), nullable=True))
    op.add_column('conversations', sa.Column('topic_summary', sa.Text(), nullable=True))
    op.add_column('conversations', sa.Column('conversation_direction', sa.String(length=32), nullable=True))
    op.add_column('conversations', sa.Column('custom_focus', sa.String(length=200), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('conversations', 'custom_focus')
    op.drop_column('conversations', 'conversation_direction')
    op.drop_column('conversations', 'topic_summary')
    op.drop_column('conversations', 'topic')

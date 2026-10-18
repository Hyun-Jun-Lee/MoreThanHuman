"""Add nickname to profiles and preserve existing display names."""

from alembic import op
import sqlalchemy as sa

revision = "20261018_0001"
down_revision = "20261010_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("profiles", sa.Column("nickname", sa.String(100), nullable=True))
    op.execute("UPDATE profiles SET nickname = name")


def downgrade():
    op.drop_column("profiles", "nickname")

"""Store the first question generated with each weekly topic."""

import sqlalchemy as sa
from alembic import op

revision = "20261004_0001"
down_revision = "20261003_0001"
branch_labels = None
depends_on = None


def upgrade():
    # 기존 발행 주제는 재발행 전까지 질문이 없어요.
    op.add_column("weekly_topics", sa.Column("first_question", sa.String(300), nullable=True))


def downgrade():
    op.drop_column("weekly_topics", "first_question")

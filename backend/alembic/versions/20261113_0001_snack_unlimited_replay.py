"""Add account-scoped unlimited snack replay permission."""

import sqlalchemy as sa

from alembic import op

revision = "20261113_0001"
down_revision = "20261101_0001"
branch_labels = None
depends_on = None


def _has_column() -> bool:
    return any(
        column["name"] == "snack_unlimited_replay_enabled"
        for column in sa.inspect(op.get_bind()).get_columns("profiles")
    )


def upgrade():
    # 운영 DB에 같은 컬럼을 수동 추가한 경우에도 revision을 기록해요.
    if not _has_column():
        op.add_column(
            "profiles",
            sa.Column(
                "snack_unlimited_replay_enabled",
                sa.Boolean(),
                server_default=sa.false(),
                nullable=False,
            ),
        )


def downgrade():
    if _has_column():
        op.drop_column("profiles", "snack_unlimited_replay_enabled")

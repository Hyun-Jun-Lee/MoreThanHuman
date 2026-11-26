"""스낵 여섯 유형과 생성 실행별 대상 목록을 보존해요."""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB

revision = "20261126_0003"
down_revision = "20261126_0002"
branch_labels = None
depends_on = None

LEGACY = ["regional_variant", "usage_contrast", "homonym"]
ALL = LEGACY + ["register_contrast", "collocation", "idiomatic_expression"]
JSON_TYPE = sa.JSON().with_variant(JSONB(), "postgresql")


def type_check(kinds):
    return "content_type IN (" + ",".join("'" + kind + "'" for kind in kinds) + ")"


def upgrade():
    op.add_column(
        "language_snack_generation_runs",
        sa.Column("content_types", JSON_TYPE, nullable=True),
    )
    runs = sa.table(
        "language_snack_generation_runs", sa.column("content_types", JSON_TYPE)
    )
    op.get_bind().execute(runs.update().values(content_types=LEGACY))
    with op.batch_alter_table("language_snack_generation_runs") as batch:
        batch.alter_column("content_types", existing_type=JSON_TYPE, nullable=False)
    with op.batch_alter_table("language_snacks") as batch:
        batch.drop_constraint("ck_snack_type", type_="check")
        batch.create_check_constraint("ck_snack_type", type_check(ALL))


def downgrade():
    bind = op.get_bind()
    snacks = sa.table("language_snacks", sa.column("content_type", sa.String()))
    runs = sa.table(
        "language_snack_generation_runs", sa.column("content_types", JSON_TYPE)
    )
    if bind.execute(
        sa.select(snacks.c.content_type)
        .where(snacks.c.content_type.not_in(LEGACY))
        .limit(1)
    ).first():
        raise RuntimeError("Cannot downgrade while new snack types exist.")
    for (kinds,) in bind.execute(sa.select(runs.c.content_types)):
        if not isinstance(kinds, list) or set(kinds) != set(LEGACY):
            raise RuntimeError(
                "Cannot downgrade while non-legacy generation targets exist."
            )
    with op.batch_alter_table("language_snacks") as batch:
        batch.drop_constraint("ck_snack_type", type_="check")
        batch.create_check_constraint("ck_snack_type", type_check(LEGACY))
    with op.batch_alter_table("language_snack_generation_runs") as batch:
        batch.drop_column("content_types")

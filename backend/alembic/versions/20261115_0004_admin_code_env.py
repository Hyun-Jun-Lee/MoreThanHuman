from alembic import op
import sqlalchemy as sa

revision = "20261115_0004"
down_revision = "20261115_0003"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("DELETE FROM admin_access_sessions")
    with op.batch_alter_table("admin_access_sessions") as batch:
        batch.drop_column("code_version")
    op.drop_table("admin_access_config")


def downgrade():
    op.execute("DELETE FROM admin_access_sessions")
    with op.batch_alter_table("admin_access_sessions") as batch:
        batch.add_column(sa.Column("code_version", sa.Integer(), nullable=False))
    op.create_table(
        "admin_access_config",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(255), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE admin_access_config ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON TABLE admin_access_config FROM PUBLIC")
        roles = set(op.get_bind().execute(sa.text(
            "SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')"
        )).scalars())
        for role in ("anon", "authenticated", "service_role"):
            if role in roles:
                op.execute(f"REVOKE ALL ON TABLE admin_access_config FROM {role}")

from alembic import op
import sqlalchemy as sa

revision = "20261115_0002"
down_revision = "20261115_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "admin_access_config",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("code", sa.String(255), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
    )
    op.create_table(
        "admin_access_sessions",
        sa.Column("token_hash", sa.String(64), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code_version", sa.Integer(), nullable=True),
        sa.Column("csrf_token", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
    )
    op.create_index("ix_admin_access_sessions_user_id", "admin_access_sessions", ["user_id"])
    op.create_table(
        "admin_access_attempts",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("failed_count", sa.Integer(), nullable=False),
        sa.Column("window_started_at", sa.DateTime(), nullable=False),
        sa.Column("locked_until", sa.DateTime(), nullable=True),
    )
    op.create_table(
        "admin_oauth_flows",
        sa.Column("state_hash", sa.String(64), primary_key=True),
        sa.Column("code_verifier", sa.String(128), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
    )
    if op.get_bind().dialect.name == "postgresql":
        tables = ("admin_access_config", "admin_access_sessions",
                  "admin_access_attempts", "admin_oauth_flows")
        for table in tables:
            op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY")
        table_list = ", ".join(tables)
        op.execute(f"REVOKE ALL ON TABLE {table_list} FROM PUBLIC")
        roles = set(op.get_bind().execute(sa.text(
            "SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')"
        )).scalars())
        for role in ("anon", "authenticated", "service_role"):
            if role in roles:
                op.execute(f"REVOKE ALL ON TABLE {table_list} FROM {role}")


def downgrade():
    op.drop_table("admin_oauth_flows")
    op.drop_table("admin_access_attempts")
    op.drop_index("ix_admin_access_sessions_user_id", table_name="admin_access_sessions")
    op.drop_table("admin_access_sessions")
    op.drop_table("admin_access_config")

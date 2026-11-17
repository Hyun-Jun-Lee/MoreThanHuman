from alembic import op
import sqlalchemy as sa

revision = "20261115_0003"
down_revision = "20261115_0002"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("DELETE FROM admin_access_sessions")
    op.drop_index("ix_admin_access_sessions_user_id", table_name="admin_access_sessions")
    with op.batch_alter_table("admin_access_sessions") as batch:
        batch.drop_column("user_id")
        batch.alter_column("code_version", existing_type=sa.Integer(), nullable=False)
    op.drop_table("admin_access_attempts")
    op.create_table(
        "admin_access_attempts",
        sa.Column("client_key", sa.String(64), primary_key=True),
        sa.Column("failed_count", sa.Integer(), nullable=False),
        sa.Column("window_started_at", sa.DateTime(), nullable=False),
        sa.Column("locked_until", sa.DateTime(), nullable=True),
    )
    op.drop_table("admin_oauth_flows")
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE admin_access_attempts ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON TABLE admin_access_attempts FROM PUBLIC")
        roles = set(op.get_bind().execute(sa.text(
            "SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')"
        )).scalars())
        for role in ("anon", "authenticated", "service_role"):
            if role in roles:
                op.execute(f"REVOKE ALL ON TABLE admin_access_attempts FROM {role}")


def downgrade():
    op.execute("DELETE FROM admin_access_sessions")
    op.drop_table("admin_access_attempts")
    op.create_table(
        "admin_access_attempts",
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("failed_count", sa.Integer(), nullable=False),
        sa.Column("window_started_at", sa.DateTime(), nullable=False),
        sa.Column("locked_until", sa.DateTime(), nullable=True),
    )
    with op.batch_alter_table("admin_access_sessions") as batch:
        batch.alter_column("code_version", existing_type=sa.Integer(), nullable=True)
        batch.add_column(sa.Column(
            "user_id", sa.String(36),
            sa.ForeignKey("profiles.id", name="fk_admin_access_sessions_user_id_profiles", ondelete="CASCADE"),
            nullable=False,
        ))
    op.create_index("ix_admin_access_sessions_user_id", "admin_access_sessions", ["user_id"])
    op.create_table(
        "admin_oauth_flows",
        sa.Column("state_hash", sa.String(64), primary_key=True),
        sa.Column("code_verifier", sa.String(128), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
    )
    if op.get_bind().dialect.name == "postgresql":
        for table in ("admin_access_attempts", "admin_oauth_flows"):
            op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON TABLE admin_access_attempts, admin_oauth_flows FROM PUBLIC")
        roles = set(op.get_bind().execute(sa.text(
            "SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')"
        )).scalars())
        for role in ("anon", "authenticated", "service_role"):
            if role in roles:
                op.execute(f"REVOKE ALL ON TABLE admin_access_attempts, admin_oauth_flows FROM {role}")

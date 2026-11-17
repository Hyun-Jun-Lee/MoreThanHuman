from alembic import op
import sqlalchemy as sa

revision = "20261115_0001"
down_revision = "20261113_0001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("profiles", sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_table(
        "manual_entitlement_grants",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False),
        sa.Column("plan", sa.String(16), nullable=False),
        sa.Column("revoke_at", sa.DateTime(), nullable=True),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("granted_by", sa.String(36), sa.ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True),
        sa.Column("revoked_by", sa.String(36), sa.ForeignKey("profiles.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("plan IN ('advance', 'plus')", name="ck_manual_entitlement_plan"),
    )
    op.create_index("ix_manual_entitlement_grants_user_id", "manual_entitlement_grants", ["user_id"])
    if op.get_bind().dialect.name == "postgresql":
        op.execute("ALTER TABLE profiles ENABLE ROW LEVEL SECURITY")
        op.execute("ALTER TABLE manual_entitlement_grants ENABLE ROW LEVEL SECURITY")
        op.execute("REVOKE ALL ON TABLE profiles, manual_entitlement_grants FROM PUBLIC")
        roles = set(op.get_bind().execute(sa.text(
            "SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated')"
        )).scalars())
        for role in ("anon", "authenticated"):
            if role in roles:
                op.execute(f"REVOKE ALL ON TABLE profiles, manual_entitlement_grants FROM {role}")
                op.execute(f"REVOKE UPDATE (is_admin) ON profiles FROM {role}")


def downgrade():
    op.drop_index("ix_manual_entitlement_grants_user_id", table_name="manual_entitlement_grants")
    op.drop_table("manual_entitlement_grants")
    op.drop_column("profiles", "is_admin")

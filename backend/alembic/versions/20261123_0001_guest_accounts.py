"""Add persistent guest accounts, consent, transfer, and quota."""

from alembic import op
import sqlalchemy as sa


revision = "20261123_0001"
down_revision = "bbeb92811bc6"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("profiles") as batch:
        batch.alter_column("email", existing_type=sa.String(255), nullable=True)
        batch.add_column(
            sa.Column("is_guest", sa.Boolean(), nullable=False, server_default=sa.false())
        )
        batch.add_column(sa.Column("last_active_at", sa.DateTime(), nullable=True))

    op.execute("UPDATE profiles SET last_active_at = COALESCE(updated_at, created_at)")
    with op.batch_alter_table("profiles") as batch:
        batch.alter_column("last_active_at", existing_type=sa.DateTime(), nullable=False)
    op.create_index("ix_profiles_last_active_at", "profiles", ["last_active_at"])

    op.create_table(
        "user_consents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("consent_kind", sa.String(32), nullable=False),
        sa.Column("version", sa.String(64), nullable=False),
        sa.Column("accepted_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.CheckConstraint(
            "consent_kind IN ('privacy_policy', 'ai_data_processing')",
            name="ck_user_consent_kind",
        ),
        sa.UniqueConstraint(
            "user_id", "consent_kind", "version", name="uq_user_consent_kind_version"
        ),
    )
    op.create_index("ix_user_consents_user_id", "user_consents", ["user_id"])

    op.create_table(
        "guest_transfer_receipts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "guest_user_id",
            sa.String(36),
            sa.ForeignKey("profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("receipt_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("claimed_at", sa.DateTime(), nullable=True),
        sa.Column(
            "claimed_by_user_id",
            sa.String(36),
            sa.ForeignKey("profiles.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'claimed', 'expired')",
            name="ck_guest_transfer_receipt_status",
        ),
        sa.CheckConstraint(
            "expires_at > created_at", name="ck_guest_transfer_receipt_expiry"
        ),
        sa.CheckConstraint(
            "(status = 'claimed' AND claimed_at IS NOT NULL AND claimed_by_user_id IS NOT NULL) "
            "OR (status != 'claimed' AND claimed_at IS NULL AND claimed_by_user_id IS NULL)",
            name="ck_guest_transfer_receipt_claim",
        ),
    )
    op.create_index(
        "ix_guest_transfer_receipts_guest_user_id",
        "guest_transfer_receipts",
        ["guest_user_id"],
    )
    op.create_index(
        "ix_guest_transfer_receipts_expires_at",
        "guest_transfer_receipts",
        ["expires_at"],
    )

    op.create_table(
        "guest_turn_usages",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("request_key", sa.String(128), nullable=False),
        sa.Column(
            "conversation_id",
            sa.String(36),
            sa.ForeignKey("conversations.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("committed_at", sa.DateTime(), nullable=True),
        sa.Column("released_at", sa.DateTime(), nullable=True),
        sa.CheckConstraint(
            "status IN ('reserved', 'committed', 'released')",
            name="ck_guest_turn_usage_status",
        ),
        sa.CheckConstraint(
            "(status = 'reserved' AND committed_at IS NULL AND released_at IS NULL) "
            "OR (status = 'committed' AND committed_at IS NOT NULL AND released_at IS NULL) "
            "OR (status = 'released' AND committed_at IS NULL AND released_at IS NOT NULL)",
            name="ck_guest_turn_usage_timestamps",
        ),
        sa.UniqueConstraint(
            "user_id", "request_key", name="uq_guest_turn_usage_user_request"
        ),
    )
    op.create_index("ix_guest_turn_usages_user_id", "guest_turn_usages", ["user_id"])
    op.create_index(
        "ix_guest_turn_usages_conversation_id",
        "guest_turn_usages",
        ["conversation_id"],
    )

    if op.get_bind().dialect.name == "postgresql":
        tables = (
            "user_consents",
            "guest_transfer_receipts",
            "guest_turn_usages",
        )
        for table in tables:
            op.execute(f"ALTER TABLE {table} ENABLE ROW LEVEL SECURITY")
        table_list = ", ".join(tables)
        op.execute(f"REVOKE ALL ON TABLE {table_list} FROM PUBLIC")
        roles = set(
            op.get_bind()
            .execute(
                sa.text(
                    "SELECT rolname FROM pg_roles "
                    "WHERE rolname IN ('anon', 'authenticated', 'service_role')"
                )
            )
            .scalars()
        )
        for role in ("anon", "authenticated", "service_role"):
            if role in roles:
                op.execute(f"REVOKE ALL ON TABLE {table_list} FROM {role}")


def downgrade():
    connection = op.get_bind()
    guest_count = connection.execute(
        sa.text("SELECT COUNT(*) FROM profiles WHERE is_guest OR email IS NULL")
    ).scalar_one()
    if guest_count:
        raise RuntimeError(
            "Cannot downgrade guest accounts while guest or email-less profiles exist"
        )

    op.drop_index("ix_guest_turn_usages_conversation_id", table_name="guest_turn_usages")
    op.drop_index("ix_guest_turn_usages_user_id", table_name="guest_turn_usages")
    op.drop_table("guest_turn_usages")
    op.drop_index(
        "ix_guest_transfer_receipts_expires_at", table_name="guest_transfer_receipts"
    )
    op.drop_index(
        "ix_guest_transfer_receipts_guest_user_id",
        table_name="guest_transfer_receipts",
    )
    op.drop_table("guest_transfer_receipts")
    op.drop_index("ix_user_consents_user_id", table_name="user_consents")
    op.drop_table("user_consents")
    op.drop_index("ix_profiles_last_active_at", table_name="profiles")
    with op.batch_alter_table("profiles") as batch:
        batch.drop_column("last_active_at")
        batch.drop_column("is_guest")
        batch.alter_column("email", existing_type=sa.String(255), nullable=False)

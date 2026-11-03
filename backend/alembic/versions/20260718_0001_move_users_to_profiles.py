"""move users to profiles

Revision ID: 20260718_0001
Revises: 74f2791a314a
Create Date: 2026-07-18 21:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260718_0001"
down_revision: Union[str, Sequence[str], None] = "74f2791a314a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


CONSTRAINT_NAMING_CONVENTION = {
    "fk": "%(table_name)s_%(column_0_name)s_fkey",
}


def upgrade() -> None:
    """Upgrade schema."""
    bind = op.get_bind()
    user_count = bind.execute(sa.text("SELECT COUNT(*) FROM users")).scalar_one()
    conversation_count = bind.execute(sa.text("SELECT COUNT(*) FROM conversations")).scalar_one()
    if user_count or conversation_count:
        raise RuntimeError(
            "profiles migration requires an empty pre-Supabase users/conversations dataset. "
            "Add a backfill migration before running this on data-bearing databases."
        )

    op.create_table(
        "profiles",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("oauth_provider", sa.String(length=50), nullable=True),
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_profiles_email"), "profiles", ["email"], unique=True)

    with op.batch_alter_table(
        "conversations",
        naming_convention=CONSTRAINT_NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint("conversations_user_id_fkey", type_="foreignkey")
        batch_op.create_foreign_key(
            "conversations_user_id_fkey",
            "profiles",
            ["user_id"],
            ["id"],
        )

    op.drop_index("ix_refresh_tokens_user_device", table_name="refresh_tokens")
    op.drop_index(op.f("ix_refresh_tokens_token_hash"), table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")


def downgrade() -> None:
    """Downgrade schema."""
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("hashed_password", sa.String(length=255), nullable=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("oauth_provider", sa.String(length=50), nullable=True),
        sa.Column("oauth_provider_id", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)

    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("device_id", sa.String(length=64), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("last_used_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_refresh_tokens_token_hash"), "refresh_tokens", ["token_hash"], unique=True)
    op.create_index("ix_refresh_tokens_user_device", "refresh_tokens", ["user_id", "device_id"], unique=False)

    with op.batch_alter_table(
        "conversations",
        naming_convention=CONSTRAINT_NAMING_CONVENTION,
    ) as batch_op:
        batch_op.drop_constraint("conversations_user_id_fkey", type_="foreignkey")
        batch_op.create_foreign_key(
            "conversations_user_id_fkey",
            "users",
            ["user_id"],
            ["id"],
        )

    op.drop_index(op.f("ix_profiles_email"), table_name="profiles")
    op.drop_table("profiles")

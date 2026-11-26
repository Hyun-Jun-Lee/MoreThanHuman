"""개인정보 안내 확인을 AI 처리 동의와 별도로 기록해요."""
from alembic import op

revision = "20261126_0001"
down_revision = "20261125_0001"
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table("user_consents") as batch:
        batch.drop_constraint("ck_user_consent_kind", type_="check")
        batch.create_check_constraint(
            "ck_user_consent_kind",
            "consent_kind IN ('privacy_policy', 'ai_data_processing', 'privacy_notice')",
        )


def downgrade():
    # 안내 확인은 동의로 변환하지 않아요. 기존 명시 동의 기록은 보존해요.
    op.execute("DELETE FROM user_consents WHERE consent_kind = 'privacy_notice'")
    with op.batch_alter_table("user_consents") as batch:
        batch.drop_constraint("ck_user_consent_kind", type_="check")
        batch.create_check_constraint(
            "ck_user_consent_kind", "consent_kind IN ('privacy_policy', 'ai_data_processing')",
        )

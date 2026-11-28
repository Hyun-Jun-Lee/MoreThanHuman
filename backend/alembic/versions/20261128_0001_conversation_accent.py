"""대화별 TTS 억양을 미국 기본값으로 저장해요."""
from alembic import op
import sqlalchemy as sa
revision = "20261128_0001"
down_revision = "20261126_0003"
branch_labels = None
depends_on = None

def upgrade():
    with op.batch_alter_table("conversations") as batch:
        batch.add_column(sa.Column("tts_accent", sa.String(2), nullable=False, server_default="us"))
        batch.create_check_constraint("ck_conversation_tts_accent", "tts_accent IN ('us', 'gb', 'au')")

def downgrade():
    with op.batch_alter_table("conversations") as batch:
        batch.drop_constraint("ck_conversation_tts_accent", type_="check")
        batch.drop_column("tts_accent")

"""Replace subscriptions with consumable account ledgers."""
from datetime import datetime
import hashlib
import hmac
from uuid import uuid4

from alembic import op
import sqlalchemy as sa

revision = '20261125_0001'
down_revision = '20261123_0001'
branch_labels = None
depends_on = None

# 생성 시점에 고정한 스키마예요. 향후 ORM 변경과 독립적으로 실행해요.
DDL = {
  "sqlite": [
    "\nCREATE TABLE purchase_deliveries (\n\ttransaction_id VARCHAR(128) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tproduct_id VARCHAR(128) NOT NULL, \n\tenvironment VARCHAR(16) NOT NULL, \n\tresource_kind VARCHAR(16) NOT NULL, \n\tquantity INTEGER NOT NULL, \n\tstatus VARCHAR(32) NOT NULL, \n\tfirst_used_at DATETIME, \n\tcreated_at DATETIME NOT NULL, \n\tPRIMARY KEY (transaction_id), \n\tCONSTRAINT ck_delivery_resource CHECK (resource_kind IN ('slots', 'turns')), \n\tCONSTRAINT ck_delivery_quantity CHECK (quantity > 0), \n\tCONSTRAINT ck_delivery_status CHECK (status IN ('pending', 'granted', 'refund-before-delivery', 'revoked')), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE credit_lots (\n\tid VARCHAR(36) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tsource VARCHAR(16) NOT NULL, \n\tsource_key VARCHAR(128) NOT NULL, \n\tquantity INTEGER NOT NULL, \n\tcreated_at DATETIME NOT NULL, \n\trevoked_at DATETIME, \n\tPRIMARY KEY (id), \n\tCONSTRAINT uq_credit_source UNIQUE (user_id, source, source_key), \n\tCONSTRAINT ck_credit_source CHECK (source IN ('trial', 'apple', 'manual')), \n\tCONSTRAINT ck_credit_quantity CHECK (quantity > 0), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE turn_reservations (\n\tid VARCHAR(36) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tlot_id VARCHAR(36) NOT NULL, \n\trequest_key VARCHAR(128) NOT NULL, \n\tstatus VARCHAR(16) NOT NULL, \n\tdeadline_at DATETIME NOT NULL, \n\tcreated_at DATETIME NOT NULL, \n\tfinished_at DATETIME, \n\tPRIMARY KEY (id), \n\tCONSTRAINT uq_member_turn_request UNIQUE (user_id, request_key), \n\tCONSTRAINT ck_member_turn_status CHECK (status IN ('reserved', 'committed', 'released', 'revoked')), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE, \n\tFOREIGN KEY(lot_id) REFERENCES credit_lots (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE manual_resource_grants (\n\tid VARCHAR(36) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tresource_kind VARCHAR(16) NOT NULL, \n\tquantity INTEGER NOT NULL, \n\tcreated_at DATETIME NOT NULL, \n\trevoked_at DATETIME, \n\tPRIMARY KEY (id), \n\tCONSTRAINT ck_manual_resource CHECK (resource_kind IN ('slots', 'turns')), \n\tCONSTRAINT ck_manual_quantity CHECK (quantity > 0), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE billing_tombstones (\n\tkind VARCHAR(16) NOT NULL, \n\tdigest VARCHAR(64) NOT NULL, \n\tkey_version VARCHAR(64) NOT NULL, \n\tstatus VARCHAR(32) NOT NULL, \n\tcreated_at DATETIME NOT NULL, \n\tPRIMARY KEY (kind, digest, key_version)\n)\n\n",
    "\nCREATE TABLE purchase_notifications (\n\tnotification_uuid VARCHAR(64) NOT NULL, \n\tnotification_type VARCHAR(64) NOT NULL, \n\treceived_at DATETIME NOT NULL, \n\tPRIMARY KEY (notification_uuid)\n)\n\n",
    "CREATE INDEX ix_purchase_deliveries_user_id ON purchase_deliveries (user_id)",
    "CREATE INDEX ix_credit_lots_user_id ON credit_lots (user_id)",
    "CREATE INDEX ix_turn_reservations_user_id ON turn_reservations (user_id)",
    "CREATE INDEX ix_turn_reservations_lot_id ON turn_reservations (lot_id)",
    "CREATE INDEX ix_manual_resource_grants_user_id ON manual_resource_grants (user_id)"
  ],
  "postgresql": [
    "\nCREATE TABLE purchase_deliveries (\n\ttransaction_id VARCHAR(128) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tproduct_id VARCHAR(128) NOT NULL, \n\tenvironment VARCHAR(16) NOT NULL, \n\tresource_kind VARCHAR(16) NOT NULL, \n\tquantity INTEGER NOT NULL, \n\tstatus VARCHAR(32) NOT NULL, \n\tfirst_used_at TIMESTAMP WITHOUT TIME ZONE, \n\tcreated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\tPRIMARY KEY (transaction_id), \n\tCONSTRAINT ck_delivery_resource CHECK (resource_kind IN ('slots', 'turns')), \n\tCONSTRAINT ck_delivery_quantity CHECK (quantity > 0), \n\tCONSTRAINT ck_delivery_status CHECK (status IN ('pending', 'granted', 'refund-before-delivery', 'revoked')), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE credit_lots (\n\tid VARCHAR(36) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tsource VARCHAR(16) NOT NULL, \n\tsource_key VARCHAR(128) NOT NULL, \n\tquantity INTEGER NOT NULL, \n\tcreated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\trevoked_at TIMESTAMP WITHOUT TIME ZONE, \n\tPRIMARY KEY (id), \n\tCONSTRAINT uq_credit_source UNIQUE (user_id, source, source_key), \n\tCONSTRAINT ck_credit_source CHECK (source IN ('trial', 'apple', 'manual')), \n\tCONSTRAINT ck_credit_quantity CHECK (quantity > 0), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE turn_reservations (\n\tid VARCHAR(36) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tlot_id VARCHAR(36) NOT NULL, \n\trequest_key VARCHAR(128) NOT NULL, \n\tstatus VARCHAR(16) NOT NULL, \n\tdeadline_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\tcreated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\tfinished_at TIMESTAMP WITHOUT TIME ZONE, \n\tPRIMARY KEY (id), \n\tCONSTRAINT uq_member_turn_request UNIQUE (user_id, request_key), \n\tCONSTRAINT ck_member_turn_status CHECK (status IN ('reserved', 'committed', 'released', 'revoked')), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE, \n\tFOREIGN KEY(lot_id) REFERENCES credit_lots (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE manual_resource_grants (\n\tid VARCHAR(36) NOT NULL, \n\tuser_id VARCHAR(36) NOT NULL, \n\tresource_kind VARCHAR(16) NOT NULL, \n\tquantity INTEGER NOT NULL, \n\tcreated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\trevoked_at TIMESTAMP WITHOUT TIME ZONE, \n\tPRIMARY KEY (id), \n\tCONSTRAINT ck_manual_resource CHECK (resource_kind IN ('slots', 'turns')), \n\tCONSTRAINT ck_manual_quantity CHECK (quantity > 0), \n\tFOREIGN KEY(user_id) REFERENCES profiles (id) ON DELETE CASCADE\n)\n\n",
    "\nCREATE TABLE billing_tombstones (\n\tkind VARCHAR(16) NOT NULL, \n\tdigest VARCHAR(64) NOT NULL, \n\tkey_version VARCHAR(64) NOT NULL, \n\tstatus VARCHAR(32) NOT NULL, \n\tcreated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\tPRIMARY KEY (kind, digest, key_version)\n)\n\n",
    "\nCREATE TABLE purchase_notifications (\n\tnotification_uuid VARCHAR(64) NOT NULL, \n\tnotification_type VARCHAR(64) NOT NULL, \n\treceived_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, \n\tPRIMARY KEY (notification_uuid)\n)\n\n",
    "CREATE INDEX ix_purchase_deliveries_user_id ON purchase_deliveries (user_id)",
    "CREATE INDEX ix_credit_lots_user_id ON credit_lots (user_id)",
    "CREATE INDEX ix_turn_reservations_user_id ON turn_reservations (user_id)",
    "CREATE INDEX ix_turn_reservations_lot_id ON turn_reservations (lot_id)",
    "CREATE INDEX ix_manual_resource_grants_user_id ON manual_resource_grants (user_id)"
  ]
}


def upgrade():
    bind = op.get_bind()
    for statement in DDL[bind.dialect.name]:
        op.execute(sa.text(statement))
    with op.batch_alter_table('account_deletions') as batch:
        batch.alter_column('user_id', existing_type=sa.String(36), type_=sa.String(64))
        batch.add_column(sa.Column('key_version', sa.String(64)))
    deleted = bind.execute(sa.text("SELECT user_id FROM account_deletions WHERE status = 'completed'")).scalars().all()
    if deleted:
        from config import get_settings
        settings = get_settings()
        keys, current = settings.billing_hmac_keys, settings.billing_hmac_current_key
        if not current or current not in keys or len(keys[current].encode()) < 32:
            raise RuntimeError('Deletion migration requires BILLING_HMAC_KEYS and BILLING_HMAC_CURRENT_KEY')
        for user_id in deleted:
            for kind in ('user', 'account'):
                digest = hmac.new(keys[current].encode(), f'{kind}:{user_id}'.encode(), hashlib.sha256).hexdigest()
                bind.execute(sa.text("INSERT INTO billing_tombstones (kind, digest, key_version, status, created_at) VALUES (:kind, :digest, :version, 'deleted', :now)"),
                             dict(kind=kind, digest=digest, version=current, now=datetime.utcnow()))
                if kind == 'user':
                    bind.execute(sa.text("UPDATE account_deletions SET user_id=:digest, key_version=:version WHERE user_id=:user"),
                                 dict(digest=digest, version=current, user=user_id))
    profiles = bind.execute(sa.text('SELECT id FROM profiles WHERE is_guest = false AND is_admin = false')).scalars().all()
    for user_id in profiles:
        bind.execute(sa.text("INSERT INTO credit_lots (id, user_id, source, source_key, quantity, created_at) VALUES (:id, :user, 'trial', 'member-trial', 10, :now)"),
                     dict(id=str(uuid4()), user=user_id, now=datetime.utcnow()))
    # 기존 대화를 삭제하거나 활성 슬롯을 재선택하지 않아요.
    for table in ('apple_subscription_notifications', 'apple_subscriptions', 'manual_entitlement_grants'):
        op.drop_table(table)
    if bind.dialect.name == 'postgresql':
        for table in ('purchase_deliveries', 'credit_lots', 'turn_reservations',
                      'manual_resource_grants', 'billing_tombstones', 'purchase_notifications'):
            op.execute(sa.text(f'ALTER TABLE {table} ENABLE ROW LEVEL SECURITY'))
            for role in ('anon', 'authenticated'):
                if bind.execute(sa.text('SELECT 1 FROM pg_roles WHERE rolname=:role'), dict(role=role)).scalar():
                    op.execute(sa.text(f'REVOKE ALL ON TABLE {table} FROM {role}'))


def downgrade():
    # 유료 원장과 삭제 tombstone을 소실시키는 downgrade는 허용하지 않아요.
    bind = op.get_bind()
    for table in ('purchase_deliveries', 'turn_reservations', 'manual_resource_grants', 'billing_tombstones'):
        if bind.execute(sa.text(f'SELECT COUNT(*) FROM {table}')).scalar():
            raise RuntimeError('Billing data exists; restore the pre-rollout backup instead')
    for table in ('turn_reservations', 'credit_lots', 'purchase_deliveries',
                  'manual_resource_grants', 'billing_tombstones', 'purchase_notifications'):
        op.drop_table(table)
    with op.batch_alter_table('account_deletions') as batch:
        batch.drop_column('key_version')
        batch.alter_column('user_id', existing_type=sa.String(64), type_=sa.String(36))
    op.create_table('apple_subscriptions',
        sa.Column('original_transaction_id', sa.String(64), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('last_transaction_id', sa.String(64), nullable=False),
        sa.Column('product_id', sa.String(32), nullable=False),
        sa.Column('environment', sa.String(16), nullable=False),
        sa.Column('status', sa.String(32), nullable=False),
        sa.Column('expires_at', sa.DateTime()), sa.Column('grace_expires_at', sa.DateTime()),
        sa.Column('verified_at', sa.DateTime(), nullable=False))
    op.create_index('ix_apple_subscriptions_user_id', 'apple_subscriptions', ['user_id'])
    op.create_index('ix_apple_subscriptions_user_status', 'apple_subscriptions', ['user_id', 'status'])
    op.create_table('apple_subscription_notifications',
        sa.Column('notification_uuid', sa.String(64), primary_key=True),
        sa.Column('original_transaction_id', sa.String(64)),
        sa.Column('received_at', sa.DateTime(), nullable=False))
    op.create_table('manual_entitlement_grants',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('user_id', sa.String(36), sa.ForeignKey('profiles.id', ondelete='CASCADE'), nullable=False),
        sa.Column('plan', sa.String(16), nullable=False),
        sa.Column('revoke_at', sa.DateTime()), sa.Column('revoked_at', sa.DateTime()),
        sa.Column('granted_by', sa.String(36), sa.ForeignKey('profiles.id', ondelete='SET NULL')),
        sa.Column('revoked_by', sa.String(36), sa.ForeignKey('profiles.id', ondelete='SET NULL')),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint("plan IN ('advance', 'plus')", name='ck_manual_entitlement_plan'))
    op.create_index('ix_manual_entitlement_grants_user_id', 'manual_entitlement_grants', ['user_id'])

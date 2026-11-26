import importlib.util
from pathlib import Path

from alembic.migration import MigrationContext
from alembic.operations import Operations
import sqlalchemy as sa


def test_upgrade_preserves_conversations_and_backfills_trial_then_downgrades():
    path = Path(__file__).parents[2] / 'alembic/versions/20261125_0001_consumable_billing.py'
    spec = importlib.util.spec_from_file_location('consumable_migration', path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine = sa.create_engine('sqlite://')
    with engine.begin() as connection:
        connection.exec_driver_sql('CREATE TABLE profiles (id VARCHAR(36) PRIMARY KEY, is_guest BOOLEAN, is_admin BOOLEAN)')
        connection.exec_driver_sql("INSERT INTO profiles VALUES ('member', false, false), ('guest', true, false)")
        connection.exec_driver_sql('CREATE TABLE conversations (id VARCHAR(36) PRIMARY KEY, user_id VARCHAR(36))')
        connection.exec_driver_sql("INSERT INTO conversations VALUES ('one', 'member'), ('two', 'member')")
        connection.exec_driver_sql('CREATE TABLE account_deletions (user_id VARCHAR(36) PRIMARY KEY, status VARCHAR(16))')
        for table in ('apple_subscriptions', 'apple_subscription_notifications', 'manual_entitlement_grants'):
            connection.exec_driver_sql(f'CREATE TABLE {table} (id VARCHAR(36))')
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        assert connection.exec_driver_sql('SELECT COUNT(*) FROM conversations').scalar() == 2
        assert connection.exec_driver_sql('SELECT user_id, quantity FROM credit_lots').all() == [('member', 10)]
        assert 'apple_subscriptions' not in sa.inspect(connection).get_table_names()
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
        assert 'apple_subscriptions' in sa.inspect(connection).get_table_names()
        assert 'credit_lots' not in sa.inspect(connection).get_table_names()
    engine.dispose()

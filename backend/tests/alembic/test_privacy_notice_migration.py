import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_notice_kind_migration_preserves_explicit_consent_and_constraints():
    path = Path(__file__).parents[2] / 'alembic/versions/20261126_0001_privacy_notice.py'
    spec = importlib.util.spec_from_file_location('privacy_notice_migration', path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine = sa.create_engine('sqlite://')
    with engine.begin() as connection:
        connection.exec_driver_sql('PRAGMA foreign_keys=ON')
        connection.exec_driver_sql('CREATE TABLE profiles (id VARCHAR(36) PRIMARY KEY)')
        connection.exec_driver_sql("INSERT INTO profiles VALUES ('member')")
        connection.exec_driver_sql("""CREATE TABLE user_consents (
            id VARCHAR(36) PRIMARY KEY, user_id VARCHAR(36) NOT NULL,
            consent_kind VARCHAR(32) NOT NULL, version VARCHAR(64) NOT NULL,
            accepted_at DATETIME NOT NULL, revoked_at DATETIME,
            FOREIGN KEY(user_id) REFERENCES profiles(id) ON DELETE CASCADE,
            CONSTRAINT ck_user_consent_kind CHECK (consent_kind IN ('privacy_policy', 'ai_data_processing')),
            CONSTRAINT uq_user_consent_kind_version UNIQUE(user_id, consent_kind, version))""")
        connection.exec_driver_sql('CREATE INDEX ix_user_consents_user_id ON user_consents(user_id)')
        connection.exec_driver_sql("INSERT INTO user_consents VALUES ('old', 'member', 'ai_data_processing', 'v1', '2026-11-25', NULL)")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        connection.exec_driver_sql("INSERT INTO user_consents VALUES ('notice', 'member', 'privacy_notice', 'v2', '2026-11-26', NULL)")
        assert connection.exec_driver_sql('SELECT COUNT(*) FROM user_consents').scalar() == 2
        assert sa.inspect(connection).get_indexes('user_consents')[0]['name'] == 'ix_user_consents_user_id'
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
        assert connection.exec_driver_sql('SELECT id FROM user_consents').all() == [('old',)]
        connection.exec_driver_sql("DELETE FROM profiles WHERE id='member'")
        assert connection.exec_driver_sql('SELECT COUNT(*) FROM user_consents').scalar() == 0
    engine.dispose()

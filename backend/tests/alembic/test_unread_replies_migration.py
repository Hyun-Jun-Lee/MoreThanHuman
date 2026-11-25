import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_existing_replies_are_read_but_new_replies_are_unread():
    path = Path(__file__).parents[2] / 'alembic/versions/20261126_0002_unread_replies.py'
    spec = importlib.util.spec_from_file_location('unread_migration', path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine = sa.create_engine('sqlite://')
    with engine.begin() as connection:
        connection.exec_driver_sql('CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT, role TEXT, created_at DATETIME NOT NULL)')
        connection.exec_driver_sql("INSERT INTO messages VALUES ('old', 'c', 'ASSISTANT', '2026-11-25'), ('user', 'c', 'USER', '2026-11-25')")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        connection.exec_driver_sql("INSERT INTO messages (id, conversation_id, role, created_at) VALUES ('new', 'c', 'ASSISTANT', '2026-11-26')")
        assert connection.exec_driver_sql('SELECT id FROM messages WHERE read_at IS NOT NULL').all() == [('old',)]
        assert len(sa.inspect(connection).get_indexes('messages')) == 1
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
        assert 'read_at' not in {c['name'] for c in sa.inspect(connection).get_columns('messages')}
        assert connection.exec_driver_sql('SELECT COUNT(*) FROM messages').scalar() == 3
    engine.dispose()

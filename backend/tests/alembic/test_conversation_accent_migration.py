import importlib.util
from pathlib import Path

import pytest
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_existing_conversations_default_and_constraint():
    path = Path(__file__).parents[2] / 'alembic/versions/20261128_0001_conversation_accent.py'
    spec = importlib.util.spec_from_file_location('accent_migration', path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    engine = sa.create_engine('sqlite://')
    with engine.begin() as connection:
        connection.exec_driver_sql('CREATE TABLE conversations (id TEXT PRIMARY KEY)')
        connection.exec_driver_sql("INSERT INTO conversations VALUES ('old')")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        assert connection.exec_driver_sql('SELECT tts_accent FROM conversations').scalar() == 'us'
        connection.exec_driver_sql("INSERT INTO conversations (id, tts_accent) VALUES ('new', 'gb')")
        with pytest.raises(sa.exc.IntegrityError):
            connection.exec_driver_sql("INSERT INTO conversations (id, tts_accent) VALUES ('bad', 'xx')")
        with Operations.context(MigrationContext.configure(connection)):
            migration.downgrade()
        assert connection.exec_driver_sql('SELECT COUNT(*) FROM conversations').scalar() == 2
    engine.dispose()

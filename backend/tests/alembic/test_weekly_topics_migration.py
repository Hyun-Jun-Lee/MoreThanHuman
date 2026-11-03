import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_weekly_topics_migration_adds_tables_without_changing_conversations():
    path = Path(__file__).parents[2] / "alembic/versions/20261003_0001_weekly_topics.py"
    spec = importlib.util.spec_from_file_location("weekly_topics_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == "20261001_0001"
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql("CREATE TABLE profiles (id VARCHAR(36) PRIMARY KEY)")
        connection.exec_driver_sql("CREATE TABLE conversations (id VARCHAR(36) PRIMARY KEY)")
        connection.exec_driver_sql("INSERT INTO conversations VALUES ('existing')")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
            names = set(sa.inspect(connection).get_table_names())
            assert {"weekly_topic_batches", "weekly_topics", "suggested_starts"} <= names
            migration.downgrade()
        assert connection.exec_driver_sql("SELECT id FROM conversations").scalar() == "existing"
    engine.dispose()

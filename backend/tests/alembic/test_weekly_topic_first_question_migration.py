import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_first_question_migration_preserves_existing_topics():
    path = Path(__file__).parents[2] / "alembic/versions/20261004_0001_weekly_topic_first_question.py"
    spec = importlib.util.spec_from_file_location("weekly_topic_first_question_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == "20261003_0001"
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql("CREATE TABLE weekly_topics (id VARCHAR(36) PRIMARY KEY, text VARCHAR(200))")
        connection.exec_driver_sql("INSERT INTO weekly_topics (id, text) VALUES ('existing', 'Old topic')")
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
            columns = {column["name"] for column in sa.inspect(connection).get_columns("weekly_topics")}
            assert "first_question" in columns
            assert connection.exec_driver_sql(
                "SELECT text, first_question FROM weekly_topics WHERE id = 'existing'"
            ).one() == ("Old topic", None)
            migration.downgrade()
            assert "first_question" not in {
                column["name"] for column in sa.inspect(connection).get_columns("weekly_topics")
            }
    engine.dispose()

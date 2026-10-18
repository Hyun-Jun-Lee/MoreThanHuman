import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_nickname_migration_backfills_existing_and_leaves_new_profiles_unset():
    path = Path(__file__).parents[2] / "alembic/versions/20261018_0001_profile_nickname.py"
    spec = importlib.util.spec_from_file_location("profile_nickname_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == "20261010_0001"

    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql(
            "CREATE TABLE profiles (id VARCHAR(36) PRIMARY KEY, name VARCHAR(100) NOT NULL)"
        )
        original_name = "A" * 80
        connection.exec_driver_sql(
            "INSERT INTO profiles (id, name) VALUES ('existing', ?)", (original_name,)
        )
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        assert connection.exec_driver_sql(
            "SELECT nickname FROM profiles WHERE id = 'existing'"
        ).scalar() == original_name
        connection.exec_driver_sql(
            "INSERT INTO profiles (id, name) VALUES ('new', 'New')"
        )
        assert connection.exec_driver_sql(
            "SELECT nickname FROM profiles WHERE id = 'new'"
        ).scalar() is None
    engine.dispose()

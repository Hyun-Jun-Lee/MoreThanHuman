import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def test_reset_table_upgrade_downgrade_preserves_existing_data():
    path = (
        Path(__file__).parents[2]
        / "alembic/versions/20260919_0001_snack_basket_resets.py"
    )
    spec = importlib.util.spec_from_file_location("basket_reset_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    assert migration.down_revision == "20260912_0001"
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        connection.exec_driver_sql("CREATE TABLE profiles (id VARCHAR(36) PRIMARY KEY)")
        connection.exec_driver_sql(
            "CREATE TABLE language_snacks (id VARCHAR(36) PRIMARY KEY)"
        )
        connection.exec_driver_sql("INSERT INTO profiles VALUES ('learner')")
        connection.exec_driver_sql(
            "INSERT INTO language_snacks VALUES ('existing-snack')"
        )
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
            inspector = sa.inspect(connection)
            assert "language_snack_basket_resets" in inspector.get_table_names()
            assert inspector.get_pk_constraint("language_snack_basket_resets")[
                "constrained_columns"
            ] == ["user_id", "content_language"]
            migration.downgrade()
        assert (
            "language_snack_basket_resets"
            not in sa.inspect(connection).get_table_names()
        )
        assert (
            connection.exec_driver_sql("SELECT id FROM profiles").scalar() == "learner"
        )
        assert (
            connection.exec_driver_sql("SELECT id FROM language_snacks").scalar()
            == "existing-snack"
        )
    engine.dispose()

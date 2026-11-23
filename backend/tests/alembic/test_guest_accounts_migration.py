import importlib.util
from pathlib import Path

import pytest
import sqlalchemy as sa
from alembic.migration import MigrationContext
from alembic.operations import Operations


def _migration():
    path = Path(__file__).parents[2] / "alembic/versions/20261123_0001_guest_accounts.py"
    spec = importlib.util.spec_from_file_location("guest_accounts_migration", path)
    migration = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(migration)
    return migration


def _create_previous_schema(connection):
    connection.exec_driver_sql(
        """
        CREATE TABLE profiles (
            id VARCHAR(36) PRIMARY KEY,
            email VARCHAR(255) NOT NULL,
            name VARCHAR(100) NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL
        )
        """
    )
    connection.exec_driver_sql(
        "CREATE UNIQUE INDEX ix_profiles_email ON profiles (email)"
    )
    connection.exec_driver_sql(
        "CREATE TABLE conversations (id VARCHAR(36) PRIMARY KEY)"
    )


def test_guest_accounts_migration_backfills_members_and_allows_guest_rows():
    migration = _migration()
    assert migration.down_revision == "bbeb92811bc6"
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        _create_previous_schema(connection)
        connection.exec_driver_sql(
            """
            INSERT INTO profiles (id, email, name, created_at, updated_at)
            VALUES ('member', 'member@example.com', 'Member', '2026-01-01', '2026-02-01')
            """
        )
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()

        row = connection.exec_driver_sql(
            "SELECT email, is_guest, last_active_at FROM profiles WHERE id = 'member'"
        ).one()
        assert row.email == "member@example.com"
        assert row.is_guest == 0
        assert row.last_active_at is not None

        connection.exec_driver_sql(
            """
            INSERT INTO profiles
                (id, email, name, created_at, updated_at, is_guest, last_active_at)
            VALUES
                ('guest', NULL, 'Guest', '2026-03-01', '2026-03-01', 1, '2026-03-01')
            """
        )
        with pytest.raises(sa.exc.IntegrityError):
            connection.exec_driver_sql(
                """
                INSERT INTO profiles
                    (id, email, name, created_at, updated_at, is_guest, last_active_at)
                VALUES
                    ('duplicate', 'member@example.com', 'Duplicate', '2026-03-01',
                     '2026-03-01', 0, '2026-03-01')
                """
            )
    engine.dispose()


def test_guest_accounts_migration_refuses_lossy_downgrade():
    migration = _migration()
    engine = sa.create_engine("sqlite://")
    with engine.begin() as connection:
        _create_previous_schema(connection)
        with Operations.context(MigrationContext.configure(connection)):
            migration.upgrade()
        connection.exec_driver_sql(
            """
            INSERT INTO profiles
                (id, email, name, created_at, updated_at, is_guest, last_active_at)
            VALUES
                ('guest', NULL, 'Guest', '2026-03-01', '2026-03-01', 1, '2026-03-01')
            """
        )
        with Operations.context(MigrationContext.configure(connection)):
            with pytest.raises(RuntimeError, match="Cannot downgrade guest accounts"):
                migration.downgrade()
    engine.dispose()

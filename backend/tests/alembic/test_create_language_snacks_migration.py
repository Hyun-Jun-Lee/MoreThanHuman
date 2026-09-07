import os
import sqlite3
import subprocess
import sys
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[2]


def _run_alembic(database_url: str, command: str, revision: str) -> None:
    environment = os.environ | {"DATABASE_URL": database_url}
    subprocess.run(
        [sys.executable, "-m", "alembic", command, revision],
        cwd=BACKEND_DIR,
        env=environment,
        check=True,
    )


def test_language_snacks_table_and_index_are_reversible(tmp_path):
    database_path = tmp_path / "language_snacks.db"
    database_url = f"sqlite:///{database_path}"

    _run_alembic(database_url, "upgrade", "20260906_0001")
    _run_alembic(database_url, "upgrade", "head")

    with sqlite3.connect(database_path) as connection:
        columns = {
            row[1]
            for row in connection.execute("PRAGMA table_info(language_snacks)").fetchall()
        }
        indexes = {
            row[1]
            for row in connection.execute("PRAGMA index_list(language_snacks)").fetchall()
        }

    assert columns == {
        "id",
        "category",
        "left_label",
        "left_word",
        "right_label",
        "right_word",
        "meaning",
        "example",
        "published_at",
        "created_at",
        "updated_at",
    }
    assert "ix_language_snacks_published_at_id" in indexes

    _run_alembic(database_url, "downgrade", "20260906_0001")

    with sqlite3.connect(database_path) as connection:
        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            ).fetchall()
        }

    assert "language_snacks" not in tables

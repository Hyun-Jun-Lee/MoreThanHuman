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


def test_roleplay_difficulty_column_is_removed_after_upgrade(tmp_path):
    database_path = tmp_path / "roleplay_difficulty.db"
    database_url = f"sqlite:///{database_path}"

    _run_alembic(database_url, "upgrade", "20260828_0001")
    _run_alembic(database_url, "upgrade", "head")

    with sqlite3.connect(database_path) as connection:
        columns = {
            row[1]
            for row in connection.execute("PRAGMA table_info(conversations)").fetchall()
        }

    assert "roleplay_difficulty" not in columns

    _run_alembic(database_url, "downgrade", "20260828_0001")

    with sqlite3.connect(database_path) as connection:
        columns = {
            row[1]
            for row in connection.execute("PRAGMA table_info(conversations)").fetchall()
        }

    assert "roleplay_difficulty" in columns

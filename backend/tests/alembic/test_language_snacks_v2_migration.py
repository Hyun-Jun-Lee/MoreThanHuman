import os
import sqlite3
import subprocess
import sys
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url

ROOT = Path(__file__).resolve().parents[2]


def test_postgres_migration_resets_only_snacks_and_uses_jsonb():
    url = os.environ.get("SNACK_TEST_POSTGRES_URL")
    if not url:
        pytest.skip(
            "Set SNACK_TEST_POSTGRES_URL to an isolated PostgreSQL test database."
        )
    admin = create_engine(url)
    schema = "snack_migration_" + uuid4().hex
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA "{schema}"'))
    isolated_url = make_url(url).update_query_dict(
        {"options": f"-csearch_path={schema}"}
    )
    engine = create_engine(isolated_url)
    try:
        migration_url = isolated_url.render_as_string(hide_password=False)
        migrate(migration_url, "upgrade", "20260906_0002")
        with engine.begin() as db:
            db.execute(text("CREATE TABLE unrelated (id INTEGER)"))
            db.execute(text("INSERT INTO unrelated VALUES (42)"))
            db.execute(
                text(
                    "INSERT INTO language_snacks VALUES ('old','c','l','w','r','w','m','e',NULL,'2026-01-01','2026-01-01')"
                )
            )
        migrate(migration_url, "upgrade", "head")
        with engine.connect() as db:
            assert db.scalar(text("SELECT COUNT(*) FROM language_snacks")) == 0
            assert db.scalar(text("SELECT id FROM unrelated")) == 42
        columns = {
            item["name"]: str(item["type"])
            for item in inspect(engine).get_columns("language_snacks")
        }
        assert columns["payload"] == "JSONB"
        assert columns["identity"] == "JSONB"
        migrate(migration_url, "downgrade", "20260906_0002")
        assert "left_word" in {
            item["name"] for item in inspect(engine).get_columns("language_snacks")
        }
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


def migrate(url, direction, revision):
    subprocess.run(
        [sys.executable, "-m", "alembic", direction, revision],
        cwd=ROOT,
        env=os.environ | {"DATABASE_URL": url},
        check=True,
        capture_output=True,
    )


def test_reset_is_scoped_and_revisions_are_reversible(tmp_path):
    path = tmp_path / "snacks_v2.db"
    url = f"sqlite:///{path}"
    migrate(url, "upgrade", "20260906_0002")
    with sqlite3.connect(path) as db:
        db.execute("CREATE TABLE unrelated (id INTEGER)")
        db.execute("INSERT INTO unrelated VALUES (42)")
        db.execute(
            "INSERT INTO language_snacks VALUES ('old','c','l','w','r','w','m','e',NULL,'2026-01-01','2026-01-01')"
        )
    migrate(url, "upgrade", "head")
    with sqlite3.connect(path) as db:
        assert db.execute("SELECT COUNT(*) FROM language_snacks").fetchone()[0] == 0
        assert db.execute("SELECT id FROM unrelated").fetchone()[0] == 42
        columns = {x[1] for x in db.execute("PRAGMA table_info(language_snacks)")}
        assert {"identity", "payload", "knowledge_key", "content_language"} <= columns
        assert "left_word" not in columns
    migrate(url, "downgrade", "20260906_0002")
    with sqlite3.connect(path) as db:
        assert db.execute("SELECT COUNT(*) FROM language_snacks").fetchone()[0] == 0
        assert "left_word" in {
            x[1] for x in db.execute("PRAGMA table_info(language_snacks)")
        }

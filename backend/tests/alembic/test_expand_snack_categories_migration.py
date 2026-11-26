import json
import sqlite3
import subprocess

import pytest

from tests.alembic.test_language_snacks_v2_migration import migrate


def test_expansion_preserves_existing_cards_and_runs(tmp_path):
    path = tmp_path / "expansion.db"
    url = f"sqlite:///{path}"
    migrate(url, "upgrade", "20261126_0002")
    with sqlite3.connect(path) as db:
        db.execute(
            "INSERT INTO language_snack_generation_runs (id,run_key,content_language,status,target_per_type,metrics,started_at) VALUES ('run','old','en','partial',3,'{}','2026-11-26')"
        )
        db.execute(
            "INSERT INTO language_snacks (id,content_type,schema_version,content_language,explanation_language,identity,identity_version,knowledge_key,knowledge_summary,payload,status,origin,generation_metadata,created_at,updated_at,generation_run_id) VALUES ('card','homonym',1,'en','ko','{}',1,'unchanged','summary',NULL,'reserved','scheduled','{}','2026-11-26','2026-11-26','run')"
        )
    migrate(url, "upgrade", "head")
    with sqlite3.connect(path) as db:
        assert json.loads(
            db.execute(
                "SELECT content_types FROM language_snack_generation_runs"
            ).fetchone()[0]
        ) == ["regional_variant", "usage_contrast", "homonym"]
        assert db.execute(
            "SELECT id,knowledge_key,generation_run_id FROM language_snacks"
        ).fetchone() == ("card", "unchanged", "run")
        db.execute("UPDATE language_snacks SET content_type='idiomatic_expression'")
    with pytest.raises(subprocess.CalledProcessError):
        migrate(url, "downgrade", "20261126_0002")
    with sqlite3.connect(path) as db:
        assert (
            db.execute("SELECT content_type FROM language_snacks").fetchone()[0]
            == "idiomatic_expression"
        )
        db.execute("UPDATE language_snacks SET content_type='homonym'")
        db.execute(
            "UPDATE language_snack_generation_runs SET content_types=?",
            (json.dumps(["homonym", "collocation"]),),
        )
    with pytest.raises(subprocess.CalledProcessError):
        migrate(url, "downgrade", "20261126_0002")
    with sqlite3.connect(path) as db:
        db.execute(
            "UPDATE language_snack_generation_runs SET content_types=?",
            (json.dumps(["regional_variant", "usage_contrast", "homonym"]),),
        )
    migrate(url, "downgrade", "20261126_0002")
    with sqlite3.connect(path) as db:
        assert db.execute(
            "SELECT id,knowledge_key FROM language_snacks"
        ).fetchone() == ("card", "unchanged")


def test_postgres_expansion_preserves_jsonb_and_rejects_downgrade():
    import os
    from uuid import uuid4
    from sqlalchemy import create_engine, inspect, text
    from sqlalchemy.engine import make_url

    url = os.environ.get("SNACK_TEST_POSTGRES_URL")
    if not url:
        pytest.skip(
            "Set SNACK_TEST_POSTGRES_URL to an isolated PostgreSQL test database."
        )
    admin = create_engine(url)
    schema = "snack_expansion_" + uuid4().hex
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA "{schema}"'))
    isolated = make_url(url).update_query_dict({"options": f"-csearch_path={schema}"})
    engine = create_engine(isolated)
    try:
        migration_url = isolated.render_as_string(hide_password=False)
        migrate(migration_url, "upgrade", "20261126_0002")
        with engine.begin() as db:
            db.execute(
                text(
                    "INSERT INTO language_snack_generation_runs (id,run_key,content_language,status,target_per_type,metrics,started_at) VALUES ('run','old','en','partial',3,'{}','2026-11-26')"
                )
            )
        migrate(migration_url, "upgrade", "head")
        assert (
            str(
                next(
                    c
                    for c in inspect(engine).get_columns(
                        "language_snack_generation_runs"
                    )
                    if c["name"] == "content_types"
                )["type"]
            )
            == "JSONB"
        )
        with engine.begin() as db:
            assert db.scalar(
                text("SELECT content_types FROM language_snack_generation_runs")
            ) == ["regional_variant", "usage_contrast", "homonym"]
            db.execute(
                text(
                    "UPDATE language_snack_generation_runs SET content_types='[\"idiomatic_expression\"]'"
                )
            )
        with pytest.raises(subprocess.CalledProcessError):
            migrate(migration_url, "downgrade", "20261126_0002")
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()

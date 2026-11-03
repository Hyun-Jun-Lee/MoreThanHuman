import os
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from database import Base
from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import LanguageSnackModel
from domains.language_snacks.repository import LanguageSnackRepository
from domains.language_snacks.schemas import Candidate


@pytest.fixture
def postgres():
    url = os.environ.get("SNACK_TEST_POSTGRES_URL")
    if not url:
        pytest.skip(
            "Set SNACK_TEST_POSTGRES_URL to an isolated PostgreSQL test database."
        )
    admin = create_engine(url)
    schema = "snack_test_" + uuid4().hex
    with admin.begin() as db:
        db.execute(text(f'CREATE SCHEMA "{schema}"'))
    engine = create_engine(url, connect_args={"options": f"-csearch_path={schema}"})
    Base.metadata.create_all(engine)
    try:
        yield engine
    finally:
        engine.dispose()
        with admin.begin() as db:
            db.execute(text(f'DROP SCHEMA "{schema}" CASCADE'))
        admin.dispose()


def test_postgres_jsonb_unique_and_shared_session_lock(postgres, sample):
    candidate = Candidate.model_validate(
        {k: v for k, v in sample.items() if k in Candidate.model_fields}
    )
    with Session(postgres) as first, Session(postgres) as second:
        one, two = LanguageSnackRepository(first), LanguageSnackRepository(second)
        with one.locked():
            with pytest.raises(SnackError, match="generation_busy"), two.locked():
                pass
            row = one.reserve(candidate)
        with two.locked():
            assert two.history("en")[0]["id"] == row.id
            with pytest.raises(SnackError, match="duplicate"):
                two.reserve(candidate)
        assert second.query(LanguageSnackModel).count() == 1
        assert (
            second.execute(
                text("SELECT pg_typeof(identity)::text FROM language_snacks")
            ).scalar()
            == "jsonb"
        )


def test_lock_connection_loss_blocks_further_writes(postgres, sample):
    candidate = Candidate.model_validate(
        {k: v for k, v in sample.items() if k in Candidate.model_fields}
    )
    with Session(postgres) as db:
        repository = LanguageSnackRepository(db)
        with repository.locked():
            repository.guard.connection.close()
            with pytest.raises(SnackError, match="lock_connection_lost"):
                repository.reserve(candidate)
        assert db.query(LanguageSnackModel).count() == 0

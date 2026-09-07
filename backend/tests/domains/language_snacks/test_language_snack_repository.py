from datetime import datetime

import pytest
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.language_snacks.models import LanguageSnackModel
from domains.language_snacks.repository import LanguageSnackRepository
from domains.language_snacks.schemas import LanguageSnackCreate
from domains.language_snacks.service import LanguageSnackService


def _repository() -> LanguageSnackRepository:
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    return LanguageSnackRepository(sessionmaker(bind=engine)())


def _create_payload(**overrides: str) -> LanguageSnackCreate:
    values = {
        "category": "Vocabulary",
        "left_label": "British English",
        "left_word": "crisps",
        "right_label": "American English",
        "right_word": "chips",
        "meaning": "둘 다 감자칩을 뜻해요.",
        "example": "Would you like a bag of crisps?",
    }
    values.update(overrides)
    return LanguageSnackCreate(**values)


def test_service_persists_complete_published_snack():
    repository = _repository()
    service = LanguageSnackService(repository)

    snack = service.create(_create_payload())

    assert snack.category == "Vocabulary"
    assert snack.left_label == "British English"
    assert snack.left_word == "crisps"
    assert snack.right_label == "American English"
    assert snack.right_word == "chips"
    assert snack.meaning == "둘 다 감자칩을 뜻해요."
    assert snack.example == "Would you like a bag of crisps?"
    assert snack.published_at is not None
    assert snack.created_at is not None
    assert snack.updated_at is not None


def test_list_published_returns_only_published_snacks_in_stable_latest_order():
    repository = _repository()
    published_at = datetime(2026, 9, 6, 12, 0, 0)
    repository.save(
        LanguageSnackModel(
            id="00000000-0000-0000-0000-000000000001",
            category="Vocabulary",
            left_label="British English",
            left_word="crisps",
            right_label="American English",
            right_word="chips",
            meaning="older",
            example="Older example.",
            published_at=datetime(2026, 9, 5, 12, 0, 0),
        )
    )
    repository.save(
        LanguageSnackModel(
            id="00000000-0000-0000-0000-000000000002",
            category="Vocabulary",
            left_label="British English",
            left_word="flat",
            right_label="American English",
            right_word="apartment",
            meaning="not published",
            example="Not visible.",
            published_at=None,
        )
    )
    repository.save(
        LanguageSnackModel(
            id="00000000-0000-0000-0000-000000000003",
            category="Vocabulary",
            left_label="British English",
            left_word="lift",
            right_label="American English",
            right_word="elevator",
            meaning="same timestamp, lower id",
            example="Take the lift.",
            published_at=published_at,
        )
    )
    repository.save(
        LanguageSnackModel(
            id="00000000-0000-0000-0000-000000000004",
            category="Vocabulary",
            left_label="British English",
            left_word="queue",
            right_label="American English",
            right_word="line",
            meaning="same timestamp, higher id",
            example="Join the queue.",
            published_at=published_at,
        )
    )

    snacks = repository.list_published()

    assert [snack.id for snack in snacks] == [
        "00000000-0000-0000-0000-000000000004",
        "00000000-0000-0000-0000-000000000003",
        "00000000-0000-0000-0000-000000000001",
    ]


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("category", ""),
        ("left_label", "   "),
        ("left_word", "x" * 81),
        ("right_label", "x" * 49),
        ("right_word", "x" * 81),
        ("meaning", "x" * 161),
        ("example", "x" * 241),
    ],
)
def test_create_schema_rejects_blank_or_overlong_content(field: str, value: str):
    with pytest.raises(ValidationError):
        _create_payload(**{field: value})

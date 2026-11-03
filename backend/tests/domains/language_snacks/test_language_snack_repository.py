from copy import deepcopy

import pytest
from pydantic import ValidationError

from domains.language_snacks.identity import knowledge_key
from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import utcnow
from domains.language_snacks.schemas import Candidate, LanguageSnackCreate


def candidate(sample):
    return Candidate.model_validate(
        {key: value for key, value in sample.items() if key in Candidate.model_fields}
    )


def test_reservations_are_hidden_and_archived_keys_stay_unique(repository, sample):
    row = repository.reserve(candidate(sample))
    assert repository.list_published("en") == []
    row.payload = sample["payload"]
    row.status = "published"
    row.published_at = utcnow()
    repository.save(row)
    assert repository.list_published("en") == [row]
    assert repository.list_published("ko") == []
    row.status = "archived"
    repository.save(row)
    assert len(repository.history("en")) == 1
    with pytest.raises(SnackError, match="duplicate_knowledge"):
        repository.reserve(candidate(sample))


def test_random_samples_all_published_rows_with_language_and_status_filter(
    repository, sample
):
    from datetime import timedelta

    from sqlalchemy import event

    from domains.language_snacks.models import LanguageSnackModel

    for i in range(35):
        repository.save(
            LanguageSnackModel(
                id=f"sample-{i}",
                content_type="regional_variant",
                content_language="ko" if i == 33 else "en",
                explanation_language="en" if i == 33 else "ko",
                identity=sample["identity"],
                knowledge_key=f"{i:064x}",
                knowledge_summary="sample",
                payload=sample["payload"],
                origin="manual",
                status="archived" if i == 34 else "published",
                published_at=utcnow() + timedelta(seconds=i),
            )
        )
    statements = []
    engine = repository.db.get_bind()

    def capture(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    event.listen(engine, "before_cursor_execute", capture)
    try:
        rows = repository.list_published("en", 12, order="random")
    finally:
        event.remove(engine, "before_cursor_execute", capture)
    assert len(rows) == len({row.id for row in rows}) == 12
    assert all(
        row.content_language == "en" and row.status == "published" for row in rows
    )
    assert "ORDER BY random()" in statements[0]
    all_rows = repository.list_published("en", 40, order="random")
    assert {row.id for row in all_rows} == {f"sample-{i}" for i in range(33)}


def test_key_ignores_order_and_whitespace_but_preserves_sense_and_language(sample):
    original = sample["identity"]
    changed = deepcopy(original)
    changed["entries"].reverse()
    changed["entries"][0]["expression"] = "  chips  "
    assert knowledge_key(original) == knowledge_key(changed)
    changed["entries"][0]["sense"] = "electronic_chip"
    assert knowledge_key(original) != knowledge_key(changed)


def test_payload_is_strict_and_matches_identity(sample):
    assert LanguageSnackCreate.model_validate(sample).payload == sample["payload"]
    sample["payload"]["items"][0]["expression"] = "different"
    with pytest.raises(ValidationError):
        LanguageSnackCreate.model_validate(sample)


@pytest.mark.parametrize("mutation", ["extra", "blank", "three", "version", "language"])
def test_schema_rejects_invalid_cards(sample, mutation):
    if mutation == "extra":
        sample["payload"]["title"] = "No"
    if mutation == "blank":
        sample["payload"]["meaning"] = " "
    if mutation == "three":
        sample["payload"]["items"] *= 2
    if mutation == "version":
        sample["schema_version"] = 2
    if mutation == "language":
        sample["explanation_language"] = "en"
    with pytest.raises(ValidationError):
        LanguageSnackCreate.model_validate(sample)


def test_homonym_allows_same_spelling():
    LanguageSnackCreate.model_validate(
        {
            "content_type": "homonym",
            "content_language": "en",
            "explanation_language": "ko",
            "knowledge_summary": "Two senses of a word.",
            "identity": {
                "relation": "same_sound",
                "pronunciation": "test",
                "pronunciation_standard": "General American",
                "entries": [
                    {"language": "en", "expression": "word", "sense": "one"},
                    {"language": "en", "expression": "word", "sense": "two"},
                ],
            },
            "payload": {
                "items": [
                    {"expression": "word", "meaning": "하나", "example": "One."},
                    {"expression": "word", "meaning": "둘", "example": "Two."},
                ]
            },
        }
    )

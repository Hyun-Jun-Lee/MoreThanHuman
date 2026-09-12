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

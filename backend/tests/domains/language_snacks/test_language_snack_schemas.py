from copy import deepcopy

import pytest
from pydantic import ValidationError

from domains.language_snacks.schemas import LanguageSnackCreate


def new_snack(kind, language="en"):
    expressions = (
        ["Could you help?", "Help me, please"]
        if language == "en"
        else ["도와줘", "도와주시겠어요?"]
    )
    relation = {
        "register_contrast": "register_difference",
        "collocation": "collocation_set",
        "idiomatic_expression": "idiomatic_meaning",
    }[kind]
    entries = [dict(language=language, expression=e, sense="help") for e in expressions]
    identity = dict(relation=relation, entries=entries)
    items = [
        dict(expression=e, example=e, example_translation="번역") for e in expressions
    ]
    if kind == "register_contrast":
        identity["context"] = "asking for help"
        for i, entry in enumerate(entries):
            entry["register"] = ["polite", "casual"][i]
            items[i].update(label=entry["register"], usage="상대에 맞는 말투")
        payload = dict(situation="도움을 요청할 때", items=items)
    elif kind == "collocation":
        identity["headword"] = "help" if language == "en" else "도움"
        for item in items:
            item["meaning"] = "뜻"
        payload = dict(headword=identity["headword"], items=items)
    else:
        identity["entries"] = entries[:1]
        payload = dict(
            expression=expressions[0],
            literal_meaning="직역",
            meaning="실제 의미",
            usage="쓰임",
            example=expressions[0],
        )
    return dict(
        content_type=kind,
        content_language=language,
        explanation_language="ko" if language == "en" else "en",
        identity=identity,
        knowledge_summary="Fixture only",
        payload=payload,
    )


@pytest.mark.parametrize(
    "kind", ["register_contrast", "collocation", "idiomatic_expression"]
)
@pytest.mark.parametrize("language", ["en", "ko"])
def test_new_payloads_round_trip_and_reject_mismatched_identity(kind, language):
    raw = new_snack(kind, language)
    parsed = LanguageSnackCreate.model_validate(raw)
    assert parsed.payload == raw["payload"]
    bad = deepcopy(raw)
    bad["identity"]["entries"][0]["expression"] = "different"
    with pytest.raises(ValidationError):
        LanguageSnackCreate.model_validate(bad)


@pytest.mark.parametrize(
    "kind", ["register_contrast", "collocation", "idiomatic_expression"]
)
def test_new_types_reject_extra_fields_and_cardinality(kind):
    raw = new_snack(kind)
    raw["identity"]["pronunciation"] = "unrelated"
    with pytest.raises(ValidationError):
        LanguageSnackCreate.model_validate(raw)
    raw = new_snack(kind)
    raw["identity"]["entries"].append(deepcopy(raw["identity"]["entries"][0]))
    with pytest.raises(ValidationError):
        LanguageSnackCreate.model_validate(raw)


def test_collocation_headword_must_match():
    raw = new_snack("collocation")
    raw["payload"]["headword"] = "other"
    with pytest.raises(ValidationError):
        LanguageSnackCreate.model_validate(raw)

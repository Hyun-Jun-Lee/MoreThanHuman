"""언어 스낵 v2의 표시 데이터와 지식 계약."""

from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

Language = Literal["en", "ko"]
ContentType = Literal[
    "regional_variant",
    "usage_contrast",
    "homonym",
    "register_contrast",
    "collocation",
    "idiomatic_expression",
]
Text80 = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)
]
Text160 = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=160)
]
Text240 = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=240)
]


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)


class RegionalItem(StrictModel):
    label: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=48)
    ]
    expression: Text80


class UsageItem(StrictModel):
    expression: Text80
    usage: Text160
    example: Text240
    example_translation: Text240 | None = None


class HomonymItem(StrictModel):
    expression: Text80
    meaning: Text160
    example: Text240
    example_translation: Text240 | None = None


class RegionalPayload(StrictModel):
    meaning: Text160
    items: list[RegionalItem] = Field(min_length=2, max_length=2)


class UsagePayload(StrictModel):
    items: list[UsageItem] = Field(min_length=2, max_length=2)


class HomonymPayload(StrictModel):
    items: list[HomonymItem] = Field(min_length=2, max_length=2)


class RegisterItem(UsageItem):
    label: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=48)
    ]


class RegisterPayload(StrictModel):
    situation: Text160
    items: list[RegisterItem] = Field(min_length=2, max_length=2)


class CollocationPayload(HomonymPayload):
    headword: Text80


class IdiomaticPayload(HomonymItem):
    literal_meaning: Text160
    usage: Text160


PAYLOAD_MODELS = {
    "regional_variant": RegionalPayload,
    "usage_contrast": UsagePayload,
    "homonym": HomonymPayload,
    "register_contrast": RegisterPayload,
    "collocation": CollocationPayload,
    "idiomatic_expression": IdiomaticPayload,
}


class IdentityEntry(StrictModel):
    language: Language
    expression: Text80
    sense: Text160
    variety: Text80 | None = None
    register: Text80 | None = None


class KnowledgeIdentity(StrictModel):
    relation: Literal[
        "regional_equivalent",
        "usage_difference",
        "same_sound",
        "register_difference",
        "collocation_set",
        "idiomatic_meaning",
    ]
    entries: list[IdentityEntry] = Field(min_length=1, max_length=2)
    contrast: Text160 | None = None
    pronunciation: Text80 | None = None
    pronunciation_standard: Text80 | None = None
    context: Text160 | None = None
    headword: Text80 | None = None


class Candidate(StrictModel):
    content_type: ContentType
    content_language: Language
    identity: KnowledgeIdentity
    knowledge_summary: Text240

    @model_validator(mode="after")
    def validate_identity(self):
        relation = {
            "regional_variant": "regional_equivalent",
            "usage_contrast": "usage_difference",
            "homonym": "same_sound",
            "register_contrast": "register_difference",
            "collocation": "collocation_set",
            "idiomatic_expression": "idiomatic_meaning",
        }
        if self.identity.relation != relation[self.content_type]:
            raise ValueError("Identity relation does not match content type.")
        expected_count = 1 if self.content_type == "idiomatic_expression" else 2
        if len(self.identity.entries) != expected_count:
            raise ValueError("Identity entry count does not match content type.")
        new_types = {"register_contrast", "collocation", "idiomatic_expression"}
        if self.content_type in new_types:
            allowed = {"relation", "entries"}
            if self.content_type == "register_contrast":
                allowed.add("context")
                if not self.identity.context or any(
                    not e.register for e in self.identity.entries
                ):
                    raise ValueError(
                        "Register identity requires context and registers."
                    )
            if self.content_type == "collocation":
                allowed.add("headword")
                if not self.identity.headword:
                    raise ValueError("Collocations require a headword.")
            if set(self.identity.model_dump(exclude_none=True)) - allowed:
                raise ValueError("Unrelated identity fields.")
            if any(
                e.variety or (e.register and self.content_type != "register_contrast")
                for e in self.identity.entries
            ):
                raise ValueError("Unrelated entry fields.")
        elif (
            self.identity.context
            or self.identity.headword
            or any(e.register for e in self.identity.entries)
        ):
            raise ValueError("New identity fields are not valid for legacy types.")
        if any(
            entry.language != self.content_language for entry in self.identity.entries
        ):
            raise ValueError("Identity language does not match content language.")
        if self.content_type == "regional_variant" and any(
            not entry.variety for entry in self.identity.entries
        ):
            raise ValueError("Regional entries require variety codes.")
        if self.content_type == "usage_contrast" and not self.identity.contrast:
            raise ValueError("Usage identity requires a contrast.")
        if self.content_type == "homonym" and (
            not self.identity.pronunciation or not self.identity.pronunciation_standard
        ):
            raise ValueError("Homonyms require pronunciation and its standard.")
        return self


class LanguageSnackCreate(Candidate):
    schema_version: Literal[1] = 1
    explanation_language: Language
    payload: dict

    @model_validator(mode="after")
    def validate_payload(self):
        from domains.language_snacks.identity import normalized_text

        expected = "ko" if self.content_language == "en" else "en"
        if self.explanation_language != expected:
            raise ValueError("Explanations must use the other supported language.")
        parsed = PAYLOAD_MODELS[self.content_type].model_validate(self.payload)
        expressions = (
            [parsed.expression]
            if isinstance(parsed, IdiomaticPayload)
            else [item.expression for item in parsed.items]
        )
        if sorted(normalized_text(expression) for expression in expressions) != sorted(
            normalized_text(item.expression) for item in self.identity.entries
        ):
            raise ValueError("Payload expressions do not match the reserved identity.")
        if isinstance(parsed, CollocationPayload) and normalized_text(
            parsed.headword
        ) != normalized_text(self.identity.headword):
            raise ValueError("Payload headword does not match identity.")
        self.payload = parsed.model_dump(exclude_none=True)
        return self


class LanguageSnack(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    content_type: ContentType
    schema_version: Literal[1]
    content_language: Language
    explanation_language: Language
    payload: dict
    published_at: datetime
    created_at: datetime
    updated_at: datetime


class ArchiveRequest(StrictModel):
    status: Literal["archived"]

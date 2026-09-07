"""Language snack 도메인 Pydantic 스키마 정의."""
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class LanguageSnackCreate(BaseModel):
    """운영자가 생성하는 즉시 발행 언어 스낵."""

    category: str = Field(max_length=40)
    left_label: str = Field(max_length=48)
    left_word: str = Field(max_length=80)
    right_label: str = Field(max_length=48)
    right_word: str = Field(max_length=80)
    meaning: str = Field(max_length=160)
    example: str = Field(max_length=240)

    @field_validator(
        "category",
        "left_label",
        "left_word",
        "right_label",
        "right_word",
        "meaning",
        "example",
        mode="before",
    )
    @classmethod
    def normalize_required_text(cls, value: object) -> object:
        """표시 콘텐츠에서 공백만 있는 입력을 막고 앞뒤 공백을 제거한다."""
        if not isinstance(value, str):
            return value

        normalized = value.strip()
        if not normalized:
            raise ValueError("Language snack fields cannot be blank.")
        return normalized


class LanguageSnack(BaseModel):
    """학습자 Home에 전달되는 발행 언어 스낵."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    category: str
    left_label: str
    left_word: str
    right_label: str
    right_word: str
    meaning: str
    example: str
    published_at: datetime
    created_at: datetime
    updated_at: datetime

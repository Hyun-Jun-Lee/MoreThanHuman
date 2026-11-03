"""
학습 언어 컨텍스트 공통 모델
"""
from enum import StrEnum
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, model_validator


class LanguageCode(StrEnum):
    """MVP에서 지원하는 학습 언어 코드"""

    KOREAN = "ko"
    ENGLISH = "en"
    CHINESE = "zh"


SUPPORTED_LANGUAGE_PAIRS = frozenset(
    {
        (LanguageCode.KOREAN, LanguageCode.ENGLISH),
        (LanguageCode.ENGLISH, LanguageCode.KOREAN),
        (LanguageCode.CHINESE, LanguageCode.ENGLISH),
        (LanguageCode.CHINESE, LanguageCode.KOREAN),
    }
)


LANGUAGE_NAMES: dict[LanguageCode, str] = {
    LanguageCode.KOREAN: "Korean",
    LanguageCode.ENGLISH: "English",
    LanguageCode.CHINESE: "Chinese",
}


class LearningLanguagePair(BaseModel):
    """학습자의 모국어와 목표 연습 언어"""

    model_config = ConfigDict(extra="forbid", use_enum_values=False)

    native_language: LanguageCode = Field(default=LanguageCode.KOREAN)
    target_language: LanguageCode = Field(default=LanguageCode.ENGLISH)

    @model_validator(mode="after")
    def validate_supported_pair(self) -> Self:
        if (self.native_language, self.target_language) not in SUPPORTED_LANGUAGE_PAIRS:
            raise ValueError(
                f"Unsupported language pair: {self.native_language.value}->{self.target_language.value}"
            )
        return self

    @property
    def pair_code(self) -> str:
        """로그/테스트에서 쓰는 안정적인 언어쌍 코드"""
        return f"{self.native_language.value}-{self.target_language.value}"


class LearningLanguageContext(LearningLanguagePair):
    """프롬프트와 피드백에 전달되는 언어 컨텍스트"""

    feedback_language: LanguageCode = Field(default=LanguageCode.KOREAN)


DEFAULT_LANGUAGE_CONTEXT = LearningLanguageContext()


def language_context_from_values(
    *,
    native_language: str | LanguageCode | None,
    target_language: str | LanguageCode | None,
    feedback_language: str | LanguageCode | None,
) -> LearningLanguageContext:
    """nullable 저장값을 안전한 언어 컨텍스트로 변환"""
    return LearningLanguageContext(
        native_language=native_language or DEFAULT_LANGUAGE_CONTEXT.native_language,
        target_language=target_language or DEFAULT_LANGUAGE_CONTEXT.target_language,
        feedback_language=feedback_language or DEFAULT_LANGUAGE_CONTEXT.feedback_language,
    )


def language_context_to_dict(context: LearningLanguageContext) -> dict[str, str]:
    """API 응답과 로그에서 쓰는 직렬화 형태"""
    return {
        "native_language": context.native_language.value,
        "target_language": context.target_language.value,
        "feedback_language": context.feedback_language.value,
    }


def language_name(language: LanguageCode | str) -> str:
    """프롬프트에 넣을 안정적인 영어 언어명"""
    code = language if isinstance(language, LanguageCode) else LanguageCode(language)
    return LANGUAGE_NAMES[code]


def ensure_language_context(
    context: LearningLanguageContext | None,
) -> LearningLanguageContext:
    """None을 기본 학습 컨텍스트로 보정"""
    return context or DEFAULT_LANGUAGE_CONTEXT

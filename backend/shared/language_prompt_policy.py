"""
Target-language prompt policy helpers.
"""
from dataclasses import dataclass

from shared.language import LanguageCode


@dataclass(frozen=True)
class TargetLanguagePromptPolicy:
    """LLM prompt에 주입하는 목표 언어별 학습 기준"""

    practice_priorities: tuple[str, ...]
    correction_priorities: tuple[str, ...]
    topic_prep_priorities: tuple[str, ...]


KOREAN_PROMPT_POLICY = TargetLanguagePromptPolicy(
    practice_priorities=(
        "Practice Korean particles such as 은/는, 이/가, 을/를, 에/에서 in natural word order.",
        "Model verb endings, tense/aspect markers, and sentence-final endings that fit the situation.",
        "Keep honorific/formality level consistent, especially for polite requests and service situations.",
        "Use clear spacing, spelling, and natural spoken Korean phrasing.",
    ),
    correction_priorities=(
        "Check Korean particles such as 은/는, 이/가, 을/를, 에/에서, 로/으로.",
        "Check verb endings, tense/aspect markers, and sentence-final endings.",
        "Check honorific/formality level against the conversation context.",
        "Check natural Korean word order and spoken phrasing.",
        "Ignore spacing, punctuation, sentence-boundary formatting, and pure spelling differences unless they change meaning.",
        "Ignore fillers, hesitations, repeated words, and self-corrections unless they block meaning.",
        "Treat omitted subjects, omitted objects, and short elliptical answers as natural Korean when context is clear.",
    ),
    topic_prep_priorities=(
        "Steer practice toward concrete Korean situations where particles, endings, and honorific formality matter.",
        "Prefer questions that let the learner answer with polite requests, introductions, opinions, or daily-life explanations.",
        "Keep prompts useful for natural spoken Korean, not textbook translation drills.",
    ),
)


ENGLISH_PROMPT_POLICY = TargetLanguagePromptPolicy(
    practice_priorities=(
        "Practice tense, subject-verb agreement, articles, prepositions, and natural word order.",
        "Model complete but natural spoken sentences, including clear question formation.",
        "Use contractions and casual phrasing when appropriate while keeping learner-facing language accurate.",
        "Keep follow-up questions short, specific, and easy to answer.",
    ),
    correction_priorities=(
        "Check tense, Subject-verb agreement, articles, prepositions, and word order.",
        "Check question formation with the right auxiliary, subject, and main verb order.",
        "Check sentence completeness, missing words, word choice, and natural spoken phrasing.",
        "Ignore uppercase/lowercase capitalization entirely because speech transcripts may not preserve it.",
        "Ignore punctuation, contraction apostrophes, pure spelling differences, and sentence-boundary formatting.",
        "Ignore fillers, hesitations, repeated words, and self-corrections unless they block meaning.",
        "Use the conversation context to distinguish natural elliptical answers from real errors.",
    ),
    topic_prep_priorities=(
        "Steer practice toward concrete English conversation with tense, articles, prepositions, opinions, facts, and follow-up questions.",
        "Prefer questions that let the learner practice tense, question structure, and natural spoken phrasing.",
        "Keep prompts useful for real conversation rather than grammar drills.",
    ),
)


GENERIC_PROMPT_POLICY = TargetLanguagePromptPolicy(
    practice_priorities=(
        "Practice accurate grammar, natural word choice, and clear sentence structure.",
        "Keep responses natural, specific, and appropriate to the conversation context.",
    ),
    correction_priorities=(
        "Check grammar, word choice, sentence structure, spelling, and naturalness.",
        "Use the conversation context to distinguish natural short answers from real errors.",
    ),
    topic_prep_priorities=(
        "Steer practice toward concrete conversation topics with specific people, events, or places.",
        "Prefer questions that help the learner answer naturally in the target language.",
    ),
)


def target_language_prompt_policy(
    language: LanguageCode | str,
) -> TargetLanguagePromptPolicy:
    """목표 언어에 맞는 prompt policy 반환"""
    code = language if isinstance(language, LanguageCode) else LanguageCode(language)
    if code == LanguageCode.KOREAN:
        return KOREAN_PROMPT_POLICY
    if code == LanguageCode.ENGLISH:
        return ENGLISH_PROMPT_POLICY
    return GENERIC_PROMPT_POLICY


def format_practice_priorities(language: LanguageCode | str) -> str:
    """대화 prompt에 넣을 목표 언어 연습 기준"""
    return _format_priorities(target_language_prompt_policy(language).practice_priorities)


def format_correction_priorities(language: LanguageCode | str) -> str:
    """문법 feedback prompt에 넣을 목표 언어 교정 기준"""
    return _format_priorities(target_language_prompt_policy(language).correction_priorities)


def format_topic_prep_priorities(language: LanguageCode | str) -> str:
    """Topic Prep prompt에 넣을 목표 언어 연습 기준"""
    return _format_priorities(target_language_prompt_policy(language).topic_prep_priorities)


def practice_priority_summary(language: LanguageCode | str) -> str:
    """한 문장 prompt에 넣을 짧은 목표 언어 연습 기준"""
    return "; ".join(target_language_prompt_policy(language).practice_priorities)


def _format_priorities(priorities: tuple[str, ...]) -> str:
    return "\n".join(f"- {priority}" for priority in priorities)

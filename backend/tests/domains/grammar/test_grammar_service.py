from domains.grammar.service import GrammarService
from shared.language import LearningLanguageContext


class FakeGrammarRepository:
    pass


def test_english_grammar_prompt_keeps_current_policy_shape():
    service = GrammarService(FakeGrammarRepository())

    prompt = service.build_grammar_prompt(
        "what you think?",
        previous_ai_message="What do you think about it?",
    )

    assert "Analyze the following English response" in prompt
    assert "Subject-verb agreement" in prompt
    assert "question formation" in prompt
    assert "articles" in prompt
    assert "prepositions" in prompt
    assert "Ignore uppercase/lowercase capitalization entirely" in prompt
    assert "Ignore punctuation, contraction apostrophes, pure spelling differences" in prompt
    assert "Ignore fillers, hesitations, repeated words, and self-corrections" in prompt
    assert "Do not correct, mention, or create errors for uppercase/lowercase capitalization." in prompt
    assert "Do not correct, mention, or create errors for transcript formatting artifacts:" in prompt
    assert '"i" vs "I"' in prompt
    assert "dont/don't" in prompt


def test_korean_grammar_prompt_uses_korean_policy_and_feedback_language():
    service = GrammarService(FakeGrammarRepository())
    context = LearningLanguageContext(
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    prompt = service.build_grammar_prompt(
        "저는 학교 가요",
        previous_ai_message="오늘 어디에 가요?",
        language_context=context,
    )

    assert "Analyze the following Korean response" in prompt
    assert "particles" in prompt
    assert "honorific" in prompt
    assert "spacing" in prompt
    assert "Explain issues in English" in prompt


def test_korean_grammar_prompt_can_use_chinese_feedback_language():
    service = GrammarService(FakeGrammarRepository())
    context = LearningLanguageContext(
        native_language="zh",
        target_language="ko",
        feedback_language="zh",
    )

    prompt = service.build_grammar_prompt(
        "저는 병원 가요",
        previous_ai_message="어디가 아프세요?",
        language_context=context,
    )

    assert "Analyze the following Korean response" in prompt
    assert "Explain issues in Chinese" in prompt
    assert '"corrected_sentence"' in prompt
    assert '"errors"' in prompt

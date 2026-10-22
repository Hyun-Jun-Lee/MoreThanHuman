import json
from dataclasses import replace
from datetime import UTC, datetime

import pytest

from domains.search.schemas import (
    ConversationDirection,
    SearchQuality,
    SearchResultItem,
    TopicPrepCard,
    TopicPrepDirection,
    TopicPrepQuality,
)
from domains.search.query import build_rule_query_analysis
from domains.search.service import PreparedSearchResult, SearchService, resolve_topic_display_language
from shared.language import LanguageCode, LearningLanguageContext
from shared.logging_config import request_context


@pytest.mark.parametrize(
    ("topic", "native_language", "expected"),
    [
        ("리센느", LanguageCode.ENGLISH, LanguageCode.KOREAN),
        ("recent Dodgers game", LanguageCode.KOREAN, LanguageCode.ENGLISH),
        ("RESCENE", LanguageCode.KOREAN, LanguageCode.KOREAN),
        ("2026", LanguageCode.ENGLISH, LanguageCode.ENGLISH),
    ],
)
def test_resolve_topic_display_language_prefers_input_and_falls_back_to_native(
    topic: str,
    native_language: LanguageCode,
    expected: LanguageCode,
):
    assert resolve_topic_display_language(topic, native_language) == expected


def _raw_result(index: int) -> dict:
    return {
        "title": f"Dodgers game result {index}",
        "href": f"https://example.com/{index}",
        "body": f"Specific Dodgers game result snippet {index}",
    }


def _quality(is_sufficient: bool = True) -> TopicPrepQuality:
    return TopicPrepQuality(
        is_sufficient=is_sufficient,
        source_count=3,
        has_enough_sources=True,
        relevance=is_sufficient,
        freshness=is_sufficient,
        specificity=is_sufficient,
        reason=None if is_sufficient else "검색 결과가 너무 일반적이에요.",
        retry_suggestion=None if is_sufficient else "팀, 날짜, 경기명을 포함해 다시 입력해보세요.",
    )


def _card(topic: str, sources: list[SearchResultItem], is_sufficient: bool = True) -> TopicPrepCard:
    directions = [
        TopicPrepDirection(
            direction=direction,
            title=direction.value,
            description=f"{direction.value} mode",
            first_questions=[
                f"What was specific about the Dodgers result in {direction.value}?",
                f"Why did this game matter for {direction.value}?",
                f"What detail would you discuss next in {direction.value}?",
            ],
        )
        for direction in ConversationDirection
    ]
    return TopicPrepCard(
        topic=topic,
        summary="The Dodgers won a specific recent game with notable late scoring.",
        directions=directions,
        sources=sources,
        quality=_quality(is_sufficient),
        timestamp=datetime.now(UTC),
    )


def _sources() -> list[SearchResultItem]:
    return [
        SearchResultItem(
            title=f"Dodgers game result {index}",
            url=f"https://example.com/{index}",
            snippet=f"Specific Dodgers game result snippet {index}",
        )
        for index in range(1, 4)
    ]


def _prepared(topic: str, sources: list[SearchResultItem], is_sufficient: bool = True) -> PreparedSearchResult:
    return PreparedSearchResult(
        analysis=build_rule_query_analysis(topic, current_date="2026-06-04"),
        sources=sources,
        quality=SearchQuality(
            is_sufficient=is_sufficient,
            source_count=len(sources),
            relevant_source_count=len(sources),
            dropped_source_count=0,
            relevance=is_sufficient,
            freshness=True,
            specificity=is_sufficient,
            reason=None if is_sufficient else "검색 결과가 너무 일반적이에요.",
            retry_suggestion=None if is_sufficient else "팀, 날짜, 경기명을 포함해 다시 입력해보세요.",
        ),
    )


async def _search_required_analysis(topic: str, **_kwargs):
    return build_rule_query_analysis(topic, current_date="2026-06-04")


def _direction_payload() -> list[dict]:
    return [
        {
            "direction": direction.value,
            "title": direction.value,
            "description": f"{direction.value} mode",
            "first_questions": [
                f"What was specific about the Dodgers result in {direction.value}?",
                f"Why did this game matter for {direction.value}?",
                f"What detail would you discuss next in {direction.value}?",
            ],
        }
        for direction in ConversationDirection
    ]


@pytest.mark.asyncio
async def test_topic_prep_logs_each_stage_without_topic_text(monkeypatch, capsys):
    service = SearchService()
    topic = "private coffee topic"
    analysis_calls = 0

    async def fake_analyze(_query, **_kwargs):
        nonlocal analysis_calls
        analysis_calls += 1
        return build_rule_query_analysis(topic, current_date="2026-06-04")

    async def fake_search(_query, _analysis, **_kwargs):
        return [_raw_result(index) for index in range(1, 4)]

    async def fake_judge(_query, sources, _analysis, **_kwargs):
        return sources, _prepared(topic, sources).quality

    async def fake_card(_topic, sources, **_kwargs):
        return _card(topic, sources)

    monkeypatch.setattr(service, "_analyze_query", fake_analyze)
    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    monkeypatch.setattr(service, "_judge_search_quality", fake_judge)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_card)
    token = request_context.set({"trace_id": "a" * 32, "request_id": "b" * 32})
    try:
        result = await service.prepare_topic(topic)
    finally:
        request_context.reset(token)

    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines() if line.startswith("{")]
    stages = {row.get("stage"): row for row in rows if row.get("duration_ms") is not None}
    assert result.ready is True
    assert analysis_calls == 1
    assert set(stages) >= {
        "topic_prep.total", "search.query_analysis", "search.provider_search",
        "search.quality_judge", "topic_prep.card_generation",
    }
    assert all(stages[name]["status"] == "ok" for name in (
        "topic_prep.total", "search.query_analysis", "search.provider_search",
        "search.quality_judge", "topic_prep.card_generation",
    ))
    assert all(stages[name]["trace_id"] == "a" * 32 for name in stages)
    assert topic not in json.dumps(rows)


@pytest.mark.asyncio
async def test_topic_prep_logs_failed_stage_and_preserves_exception(monkeypatch, capsys):
    service = SearchService()

    async def fake_analyze(query, **_kwargs):
        return build_rule_query_analysis(query, current_date="2026-06-04")

    async def fake_search(_query, _analysis, **_kwargs):
        raise RuntimeError("private upstream payload")

    monkeypatch.setattr(service, "_analyze_query", fake_analyze)
    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    token = request_context.set({"trace_id": "a" * 32, "request_id": "b" * 32})
    try:
        with pytest.raises(RuntimeError, match="private upstream payload"):
            await service.prepare_topic("private search topic")
    finally:
        request_context.reset(token)

    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines() if line.startswith("{")]
    stages = {row["stage"]: row for row in rows if row.get("stage") in {
        "topic_prep.total", "search.query_analysis", "search.provider_search",
    }}
    assert stages["search.provider_search"]["status"] == "error"
    assert stages["topic_prep.total"]["status"] == "error"
    assert "private upstream payload" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_prepare_topic_returns_ready_card_when_search_quality_is_sufficient(monkeypatch):
    service = SearchService()

    async def fake_prepare(topic: str, language_context=None, analysis=None):
        return _prepared(topic, _sources())

    async def fake_generate(
        topic: str,
        sources: list[SearchResultItem],
        language_context=None,
    ):
        return _card(topic, sources)

    monkeypatch.setattr(service, "_prepare_search_results", fake_prepare)
    monkeypatch.setattr(service, "_analyze_query", _search_required_analysis)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic("recent Dodgers game result")

    assert result.ready is True
    assert result.card is not None
    assert result.card.topic == "recent Dodgers game result"
    assert len(result.card.directions) == 3
    assert all(len(direction.first_questions) == 3 for direction in result.card.directions)
    assert "Dodgers" in result.card.directions[0].first_questions[0]


@pytest.mark.asyncio
async def test_prepare_topic_skips_search_when_analysis_says_unnecessary(monkeypatch):
    service = SearchService()
    topic = "면접 자기소개 연습"

    async def fake_llm_analysis(_topic, *_args, **_kwargs):
        return {
            "canonical_topic": topic,
            "required_phrases": [topic],
            "required_tokens": ["면접", "자기소개", "연습"],
            "context_terms": [],
            "recency_intent": False,
            "exclude_terms": [],
            "search_required": False,
        }

    async def fail_if_searched(*_args, **_kwargs):
        raise AssertionError("direct topic prep must skip web search and source judge")

    async def fake_generate(_topic, sources, **_kwargs):
        return service._build_topic_prep_card_from_data(
            topic,
            sources,
            {"quality": {"is_sufficient": True, "relevance": True, "freshness": True, "specificity": True},
             "summary": "Interview introduction practice.", "directions": _direction_payload()},
        )

    monkeypatch.setattr(service, "_generate_llm_query_analysis", fake_llm_analysis)
    monkeypatch.setattr(service, "_prepare_search_results", fail_if_searched)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic(topic)

    assert result.ready is True
    assert result.search_required is False
    assert result.card is not None
    assert result.card.sources == []
    assert result.quality.source_count == 0
    assert result.quality.has_enough_sources is False


@pytest.mark.asyncio
async def test_direct_topic_prep_failure_does_not_claim_search_failed(monkeypatch):
    service = SearchService()
    topic = "면접 자기소개 연습"

    async def fake_analyze(_topic, **_kwargs):
        return replace(build_rule_query_analysis(topic), search_required=False)

    async def fake_generate(_topic, sources, **_kwargs):
        return service._build_topic_prep_card_from_data(
            topic, sources, {"quality": {"is_sufficient": False}, "summary": "", "directions": []},
        )

    monkeypatch.setattr(service, "_analyze_query", fake_analyze)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic(topic)

    assert result.ready is False
    assert result.search_required is False
    assert result.quality.source_count == 0
    assert "검색" not in result.retry_guidance


@pytest.mark.asyncio
async def test_topic_prep_followups_generate_without_repeating_search(monkeypatch):
    service = SearchService()
    requests = []

    async def fail_if_searched(*_args, **_kwargs):
        raise AssertionError("follow-up generation must not repeat web search")

    class FakeResponse:
        def __init__(self, content):
            self.content = content

    class FakeProvider:
        async def chat_completion(self, request):
            requests.append(request)
            if len(requests) == 1:
                return FakeResponse(json.dumps({
                    "is_relevant": True,
                    "first_questions": ["What is your strength?", "Why this role?", "What did you learn?"],
                    "retry_guidance": None,
                }))
            return FakeResponse(json.dumps({"directions": _direction_payload()}))

    monkeypatch.setattr(service, "_prepare_search_results", fail_if_searched)
    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: FakeProvider())

    focus = await service.prepare_custom_focus_questions("면접 자기소개 연습", "강점 설명")
    directions = await service.regenerate_topic_prep_directions("면접 자기소개 연습", [])

    assert focus.ready is True
    assert len(directions.directions) == 3
    assert all("Search Results" not in request.messages[1].content for request in requests)


@pytest.mark.asyncio
async def test_prepare_topic_rejects_when_source_count_is_too_low(monkeypatch):
    service = SearchService()

    async def fake_prepare(topic: str, language_context=None, analysis=None):
        return _prepared(topic, _sources()[:1], is_sufficient=False)

    async def fail_if_called(
        _topic: str,
        _sources: list[SearchResultItem],
        language_context=None,
    ):
        raise AssertionError("LLM card generation should not run for low source count")

    monkeypatch.setattr(service, "_prepare_search_results", fake_prepare)
    monkeypatch.setattr(service, "_analyze_query", _search_required_analysis)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fail_if_called)

    result = await service.prepare_topic("recent game")

    assert result.ready is False
    assert result.card is None
    assert result.quality.has_enough_sources is False
    assert result.retry_guidance is not None
    assert result.example_topics


@pytest.mark.asyncio
async def test_prepare_topic_rejects_when_llm_quality_gate_fails(monkeypatch):
    service = SearchService()

    async def fake_prepare(topic: str, language_context=None, analysis=None):
        return _prepared(topic, _sources())

    async def fake_generate(
        topic: str,
        sources: list[SearchResultItem],
        language_context=None,
    ):
        return _card(topic, sources, is_sufficient=False)

    monkeypatch.setattr(service, "_prepare_search_results", fake_prepare)
    monkeypatch.setattr(service, "_analyze_query", _search_required_analysis)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic("요즘 이슈")

    assert result.ready is False
    assert result.card is None
    assert result.quality.is_sufficient is False
    assert "날짜" in result.retry_guidance
    assert "팀" in result.retry_guidance


@pytest.mark.asyncio
async def test_prepare_topic_uses_feedback_language_when_llm_card_quality_fails(monkeypatch):
    service = SearchService()
    context = LearningLanguageContext(
        native_language="zh",
        target_language="ko",
        feedback_language="zh",
    )

    async def fake_prepare(topic: str, language_context=None, analysis=None):
        return _prepared(topic, _sources())

    async def fake_generate(
        topic: str,
        sources: list[SearchResultItem],
        _analysis=None,
        language_context=None,
    ):
        return _card(topic, sources, is_sufficient=False)

    monkeypatch.setattr(service, "_prepare_search_results", fake_prepare)
    monkeypatch.setattr(service, "_analyze_query", _search_required_analysis)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic("预约", language_context=context)

    assert result.ready is False
    assert result.card is None
    assert "请加入具体事件" in result.retry_guidance
    assert result.quality.retry_suggestion == result.retry_guidance
    assert all("韩语" in example for example in result.example_topics)


@pytest.mark.asyncio
async def test_prepare_topic_uses_english_feedback_for_korean_practice_retry(monkeypatch):
    service = SearchService()
    context = LearningLanguageContext(
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    async def fake_prepare(topic: str, language_context=None, analysis=None):
        prepared = _prepared(topic, _sources()[:1], is_sufficient=False)
        return PreparedSearchResult(
            analysis=prepared.analysis,
            sources=prepared.sources,
            quality=prepared.quality.model_copy(update={"retry_suggestion": None}),
        )

    async def fail_if_called(
        _topic: str,
        _sources: list[SearchResultItem],
        _analysis=None,
        language_context=None,
    ):
        raise AssertionError("LLM card generation should not run for low source count")

    monkeypatch.setattr(service, "_prepare_search_results", fake_prepare)
    monkeypatch.setattr(service, "_analyze_query", _search_required_analysis)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fail_if_called)

    result = await service.prepare_topic("clinic appointment", language_context=context)

    assert result.ready is False
    assert result.card is None
    assert result.retry_guidance.startswith("I could not find")
    assert all("Korean" in example for example in result.example_topics)


@pytest.mark.parametrize(
    "data",
    [
        {
            "quality": {"is_sufficient": True, "relevance": True, "freshness": True, "specificity": True},
            "summary": "",
            "directions": _direction_payload(),
        },
        {
            "quality": {"is_sufficient": True, "relevance": True, "freshness": True, "specificity": True},
            "summary": "The Dodgers won a specific recent game.",
            "directions": _direction_payload()[:2],
        },
        {
            "quality": {"is_sufficient": True, "relevance": True, "freshness": True, "specificity": True},
            "summary": "The Dodgers won a specific recent game.",
            "directions": [
                {
                    **direction,
                    "first_questions": direction["first_questions"][:2],
                }
                if direction["direction"] == ConversationDirection.DEBATE.value
                else direction
                for direction in _direction_payload()
            ],
        },
    ],
)
def test_build_topic_prep_card_rejects_incomplete_sufficient_llm_payload(data):
    service = SearchService()

    card = service._build_topic_prep_card_from_data(
        "recent Dodgers game result",
        _sources(),
        data,
    )

    assert card.quality.is_sufficient is False
    assert card.quality.reason == "주제에 맞는 대화 준비 카드를 완성하지 못했어요."
    assert card.quality.retry_suggestion is not None


def test_build_example_topics_uses_feedback_language_for_korean_practice_examples():
    service = SearchService()
    context = LearningLanguageContext(
        native_language="zh",
        target_language="ko",
        feedback_language="zh",
    )

    examples = service._build_example_topics("预约", language_context=context)

    assert len(examples) == 3
    assert all("韩语" in example for example in examples)
    assert any("礼貌服务场景" in example for example in examples)


def test_topic_prep_card_uses_target_language_fallback_directions():
    service = SearchService()
    context = LearningLanguageContext(
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    card = service._build_topic_prep_card_from_data(
        "clinic visit",
        _sources(),
        {
            "quality": {
                "is_sufficient": True,
                "relevance": True,
                "freshness": True,
                "specificity": True,
            },
            "summary": "Clinic visit practice.",
            "directions": [
                {
                    "direction": ConversationDirection.EXPLANATION_PRACTICE.value,
                    "title": "",
                    "description": "",
                    "first_questions": [],
                },
            ],
        },
        language_context=context,
    )

    explanation = next(
        direction
        for direction in card.directions
        if direction.direction == ConversationDirection.EXPLANATION_PRACTICE
    )
    assert explanation.title == "Explanation practice"
    assert "쉬운 한국어" in explanation.first_questions[0]


def test_topic_prep_system_prompt_includes_korean_practice_policy():
    service = SearchService()
    context = LearningLanguageContext(
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    prompt = service._build_topic_prep_system_prompt(language_context=context)

    assert "Korean learners" in prompt
    assert "particles" in prompt
    assert "honorific" in prompt
    assert "Feedback/retry guidance language: English" in prompt


def test_topic_prep_system_prompt_includes_english_practice_policy():
    service = SearchService()

    prompt = service._build_topic_prep_system_prompt()

    assert "English learners" in prompt
    assert "tense" in prompt
    assert "articles" in prompt
    assert "prepositions" in prompt


@pytest.mark.asyncio
async def test_topic_prep_card_prompt_omits_search_sources(monkeypatch):
    service = SearchService()
    sources = _sources()
    captured = {}

    class FakeResponse:
        content = json.dumps({
            "quality": {"is_sufficient": True, "relevance": True, "freshness": True, "specificity": True},
            "summary": "A conversation about a recent Dodgers game.",
            "directions": _direction_payload(),
        })

    class FakeProvider:
        async def chat_completion(self, request):
            captured["request"] = request
            return FakeResponse()

    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: FakeProvider())

    card = await service._generate_topic_prep_card("recent Dodgers game", sources)

    system_prompt = captured["request"].messages[0].content
    user_prompt = captured["request"].messages[1].content
    assert "source" not in system_prompt.lower()
    assert "Search Results" not in user_prompt
    assert "Enhanced query" not in user_prompt
    assert all(source.title not in user_prompt and source.url not in user_prompt for source in sources)
    assert card.sources == sources

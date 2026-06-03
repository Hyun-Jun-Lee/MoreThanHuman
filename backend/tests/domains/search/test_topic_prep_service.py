from datetime import UTC, datetime

import pytest

from domains.search.schemas import (
    ConversationDirection,
    SearchResultItem,
    TopicPrepCard,
    TopicPrepDirection,
    TopicPrepQuality,
)
from domains.search.service import SearchService


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
async def test_prepare_topic_returns_ready_card_when_search_quality_is_sufficient(monkeypatch):
    service = SearchService()

    async def fake_search(_topic: str):
        return [_raw_result(1), _raw_result(2), _raw_result(3)]

    async def fake_generate(topic: str, sources: list[SearchResultItem]):
        return _card(topic, sources)

    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic("recent Dodgers game result")

    assert result.ready is True
    assert result.card is not None
    assert result.card.topic == "recent Dodgers game result"
    assert len(result.card.directions) == 4
    assert all(len(direction.first_questions) == 3 for direction in result.card.directions)
    assert "Dodgers" in result.card.directions[0].first_questions[0]


@pytest.mark.asyncio
async def test_prepare_topic_rejects_when_source_count_is_too_low(monkeypatch):
    service = SearchService()

    async def fake_search(_topic: str):
        return [_raw_result(1), _raw_result(2)]

    async def fail_if_called(_topic: str, _sources: list[SearchResultItem]):
        raise AssertionError("LLM card generation should not run for low source count")

    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
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

    async def fake_search(_topic: str):
        return [_raw_result(1), _raw_result(2), _raw_result(3)]

    async def fake_generate(topic: str, sources: list[SearchResultItem]):
        return _card(topic, sources, is_sufficient=False)

    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    monkeypatch.setattr(service, "_generate_topic_prep_card", fake_generate)

    result = await service.prepare_topic("요즘 이슈")

    assert result.ready is False
    assert result.card is None
    assert result.quality.is_sufficient is False
    assert "팀, 날짜" in result.retry_guidance


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
            "directions": _direction_payload()[:3],
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
    assert card.quality.reason == "검색 결과로 대화 준비 카드를 완성하지 못했어요."
    assert card.quality.retry_suggestion is not None

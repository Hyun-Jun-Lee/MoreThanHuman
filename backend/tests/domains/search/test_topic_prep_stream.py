import json
from dataclasses import replace

import pytest

from domains.search.query import build_rule_query_analysis
from domains.search.service import SearchService
from domains.search.topic_prep_stream import completed_summary


def test_summary_is_available_only_after_complete_json_string_and_quality():
    prefix = '{"quality":{"is_sufficient":true},"summary":"A \\"quoted\\" summary.'
    assert completed_summary(prefix) is None
    assert completed_summary(prefix + '","directions":[') == 'A "quoted" summary.'
    assert completed_summary('{"quality":{"is_sufficient":false},"summary":"Draft"}') is None


@pytest.mark.asyncio
async def test_stream_emits_summary_before_validated_card(monkeypatch):
    service = SearchService()
    topic = "면접 자기소개 연습"

    async def analyze(*_args, **_kwargs):
        return replace(build_rule_query_analysis(topic), search_required=False)

    payload = {
        "quality": {"is_sufficient": True, "relevance": True,
                    "freshness": True, "specificity": True},
        "summary": "면접에서 자기소개를 연습해요.",
        "directions": [
            {"direction": direction, "title": direction,
             "description": "면접 대화 연습", "first_questions": ["Q1?", "Q2?", "Q3?"]}
            for direction in ("CASUAL_CHAT", "DEBATE", "EXPLANATION_PRACTICE")
        ],
    }
    encoded = json.dumps(payload, ensure_ascii=False)
    split = encoded.index('"directions"')

    class Provider:
        async def chat_completion_stream(self, _request):
            yield encoded[:split]
            yield encoded[split:]

    monkeypatch.setattr(service, "_analyze_query", analyze)
    monkeypatch.setattr(
        "domains.search.service.LLMProviderFactory.create_provider",
        lambda **_kwargs: Provider(),
    )

    events = service.prepare_topic_stream(topic)
    name, summary = await anext(events)
    assert (name, summary) == ("summary_ready", payload["summary"])
    name, result = await anext(events)
    assert name == "card_ready"
    assert result.ready is True
    assert result.search_required is False
    assert len(result.card.directions) == 3
    with pytest.raises(StopAsyncIteration):
        await anext(events)


@pytest.mark.asyncio
async def test_stream_skips_summary_when_card_quality_is_insufficient(monkeypatch):
    service = SearchService()
    topic = "면접 자기소개 연습"

    async def analyze(*_args, **_kwargs):
        return replace(build_rule_query_analysis(topic), search_required=False)

    class Provider:
        async def chat_completion_stream(self, _request):
            yield json.dumps({
                "quality": {"is_sufficient": False, "relevance": False,
                            "freshness": True, "specificity": False},
                "summary": "잠정 요약", "directions": [],
            }, ensure_ascii=False)

    monkeypatch.setattr(service, "_analyze_query", analyze)
    monkeypatch.setattr(
        "domains.search.service.LLMProviderFactory.create_provider",
        lambda **_kwargs: Provider(),
    )

    events = [event async for event in service.prepare_topic_stream(topic)]
    assert [name for name, _ in events] == ["card_ready"]
    assert events[0][1].ready is False

from datetime import UTC, datetime

import pytest

from domains.search.query import build_rule_query_analysis
from domains.search.schemas import SearchQuality, SearchResultItem
from domains.search.service import SearchService
from shared.exceptions import ExternalAPIException


def _quality(is_sufficient: bool) -> SearchQuality:
    return SearchQuality(
        is_sufficient=is_sufficient,
        source_count=4,
        relevant_source_count=2 if is_sufficient else 0,
        dropped_source_count=2 if is_sufficient else 4,
        relevance=is_sufficient,
        freshness=True,
        specificity=is_sufficient,
        reason=None if is_sufficient else "검색 결과가 주제와 충분히 관련되어 있지 않아요.",
        retry_suggestion=None if is_sufficient else "팀, 날짜, 사건명을 추가해보세요.",
    )


@pytest.mark.asyncio
async def test_search_pipeline_summarizes_only_llm_accepted_sources(monkeypatch):
    service = SearchService()

    async def fake_analyze(_query: str, **_kwargs):
        return build_rule_query_analysis("최근 롯데 자이언츠 경기", current_date="2026-06-04")

    async def fake_judge(_query, sources, _analysis, **_kwargs):
        return [sources[1], sources[2]], _quality(True)

    async def fake_summarize(_query, sources, _analysis, **_kwargs):
        assert [source.title for source in sources] == [
            "롯데 자이언츠, 최근 KBO 경기 결과",
            "롯데 자이언츠 경기 하이라이트",
        ]
        return "Lotte Giants won a recent KBO game."

    async def fake_search(_query, _analysis=None, **_kwargs):
        return [
            {"title": "NAVER", "href": "https://www.naver.com/", "body": "네이버 포털"},
            {
                "title": "롯데 자이언츠, 최근 KBO 경기 결과",
                "href": "https://sports.example.com/kbo/lotte",
                "body": "롯데 자이언츠가 최근 경기에서 승리했다.",
            },
            {
                "title": "롯데 자이언츠 경기 하이라이트",
                "href": "https://sports.example.com/highlight",
                "body": "KBO 롯데 자이언츠 경기 결과와 주요 장면.",
            },
        ]

    monkeypatch.setattr(service, "_analyze_query", fake_analyze)
    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    monkeypatch.setattr(service, "_judge_search_quality", fake_judge)
    monkeypatch.setattr(service, "_summarize_results", fake_summarize)

    result = await service.search("최근 롯데 자이언츠 경기")

    assert result.ready is True
    assert result.summary == "Lotte Giants won a recent KBO game."
    assert result.quality.dropped_source_count == 2


@pytest.mark.asyncio
async def test_search_low_quality_does_not_summarize(monkeypatch):
    service = SearchService()

    async def fake_analyze(_query: str, **_kwargs):
        return build_rule_query_analysis("요즘 이슈", current_date="2026-06-04")

    async def fake_judge(_query, _sources, _analysis, **_kwargs):
        return [], _quality(False)

    async def fail_summarize(_query, _sources, _analysis, **_kwargs):
        raise AssertionError("summary LLM should not run for low-quality search")

    async def fake_search(_query, _analysis=None, **_kwargs):
        return [
            {"title": "Google 뉴스", "href": "https://news.google.com/?hl=ko", "body": "뉴스 모음"},
        ]

    monkeypatch.setattr(service, "_analyze_query", fake_analyze)
    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    monkeypatch.setattr(service, "_judge_search_quality", fake_judge)
    monkeypatch.setattr(service, "_summarize_results", fail_summarize)

    result = await service.search("요즘 이슈")

    assert result.ready is False
    assert result.summary is None
    assert result.retry_guidance is not None


@pytest.mark.asyncio
async def test_search_empty_results_does_not_call_quality_judge(monkeypatch):
    service = SearchService()

    async def fake_analyze(_query: str, **_kwargs):
        return build_rule_query_analysis("검색 결과 없는 주제", current_date="2026-06-04")

    async def fake_search(_query, _analysis=None, **_kwargs):
        return []

    async def fail_judge(_query, _sources, _analysis, **_kwargs):
        raise AssertionError("quality judge should not run when search returns no sources")

    monkeypatch.setattr(service, "_analyze_query", fake_analyze)
    monkeypatch.setattr(service, "_search_duckduckgo", fake_search)
    monkeypatch.setattr(service, "_judge_search_quality", fail_judge)

    result = await service.search("검색 결과 없는 주제")

    assert result.ready is False
    assert result.sources == []
    assert result.quality.source_count == 0


@pytest.mark.asyncio
async def test_quality_judge_prompt_includes_current_date_and_timezone(monkeypatch):
    captured = {}
    service = SearchService()
    analysis = build_rule_query_analysis("최근 애플 발표", current_date="2026-06-04")

    class FakeResponse:
        content = '{"is_sufficient":true,"accepted_source_ids":[1,2],"relevance":true,"freshness":true,"specificity":true,"reason":null,"retry_suggestion":null}'

    class FakeProvider:
        async def chat_completion(self, request):
            captured["request"] = request
            return FakeResponse()

    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda: FakeProvider())

    accepted_sources, quality = await service._judge_search_quality(
        "최근 애플 발표",
        [
            SearchResultItem(title="Apple 발표", url="https://example.com/1", snippet="Apple announced a new product."),
            SearchResultItem(title="Apple WWDC", url="https://example.com/2", snippet="Apple shared WWDC updates."),
        ],
        analysis,
    )

    assert quality.is_sufficient is True
    assert len(accepted_sources) == 2
    system_prompt = captured["request"].messages[0].content
    user_prompt = captured["request"].messages[1].content
    assert "rejected_sources" in system_prompt
    assert "portal homepages" in system_prompt
    assert "when uncertain, reject conservatively" in system_prompt
    assert "at least 2 independent accepted sources" in system_prompt
    assert "one short sentence" in system_prompt
    assert captured["request"].max_tokens == 1000
    assert captured["request"].extra_params["response_format"]["type"] == "json_schema"
    assert (
        captured["request"].extra_params["response_format"]["json_schema"]["name"]
        == "search_quality_judge"
    )
    assert "Current date:" in user_prompt
    assert "Timezone: Asia/Seoul" in user_prompt
    assert "Recency intent:" in user_prompt
    assert "Required phrases:" in user_prompt
    assert "Exclude terms:" in user_prompt
    assert "Source 1" in user_prompt


def test_quality_finalizer_rejects_contradictory_sufficient_result():
    service = SearchService()
    analysis = build_rule_query_analysis("오사카 여행 맛집 추천", current_date="2026-06-04")
    sources = [
        SearchResultItem(title="오사카 맛집", url="https://example.com/1", snippet="오사카 맛집 추천"),
        SearchResultItem(title="도톤보리 음식", url="https://example.com/2", snippet="도톤보리 타코야키"),
    ]
    judge_result = {
        "is_sufficient": True,
        "accepted_source_ids": [1, 2],
        "rejected_sources": [],
        "relevance": False,
        "freshness": False,
        "specificity": False,
        "reason": None,
        "retry_suggestion": None,
    }

    accepted_sources, quality = service._finalize_search_quality(
        "오사카 여행 맛집 추천",
        sources,
        analysis,
        service._build_search_quality_judge_result(judge_result),
    )

    assert len(accepted_sources) == 2
    assert quality.is_sufficient is False
    assert quality.freshness is True
    assert quality.reason is not None


def test_quality_judge_parser_accepts_common_llm_short_forms():
    service = SearchService()

    result = service._build_search_quality_judge_result(
        {
            "is_sufficient": True,
            "accepted_source_ids": ["1", "2"],
            "rejected_sources": [3, 4],
            "relevance": 5,
            "freshness": "5",
            "specificity": "true",
            "reason": None,
            "retry_suggestion": None,
        }
    )

    assert result.accepted_source_ids == [1, 2]
    assert [source.id for source in result.rejected_sources] == [3, 4]
    assert result.relevance is True
    assert result.freshness is True
    assert result.specificity is True


def test_quality_judge_parser_drops_alias_fields_after_normalization():
    service = SearchService()

    result = service._build_search_quality_judge_result(
        {
            "is_sufficient": True,
            "accepted_ids": ["1", "2"],
            "rejected_ids": ["3"],
            "relevance": True,
            "freshness": True,
            "specificity": True,
            "reason": None,
            "retry_suggestion": None,
        }
    )

    assert result.accepted_source_ids == [1, 2]
    assert [source.id for source in result.rejected_sources] == [3]


@pytest.mark.asyncio
async def test_quality_judge_retries_without_structured_output_when_provider_rejects(monkeypatch):
    service = SearchService()
    analysis = build_rule_query_analysis("최근 애플 발표", current_date="2026-06-04")
    calls = []

    class FakeResponse:
        content = '{"is_sufficient":true,"accepted_source_ids":[1,2],"rejected_sources":[],"relevance":true,"freshness":true,"specificity":true,"reason":null,"retry_suggestion":null}'

    class FakeProvider:
        async def chat_completion(self, request):
            calls.append(request.extra_params)
            if request.extra_params:
                raise ExternalAPIException("response_format json_schema is not supported")
            return FakeResponse()

    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda: FakeProvider())

    accepted_sources, quality = await service._judge_search_quality(
        "최근 애플 발표",
        [
            SearchResultItem(title="Apple 발표", url="https://example.com/1", snippet="Apple announced a new product."),
            SearchResultItem(title="Apple WWDC", url="https://example.com/2", snippet="Apple shared WWDC updates."),
        ],
        analysis,
    )

    assert len(accepted_sources) == 2
    assert quality.is_sufficient is True
    assert calls[0] is not None
    assert calls[1] is None


def test_quality_finalizer_rejects_invalid_source_id():
    service = SearchService()
    analysis = build_rule_query_analysis("최근 애플 WWDC 발표 내용", current_date="2026-06-04")
    sources = [
        SearchResultItem(title="WWDC 2026", url="https://example.com/1", snippet="Apple WWDC announcement"),
    ]
    judge_result = {
        "is_sufficient": True,
        "accepted_source_ids": [2],
        "rejected_sources": [],
        "relevance": True,
        "freshness": True,
        "specificity": True,
        "reason": None,
        "retry_suggestion": None,
    }

    accepted_sources, quality = service._finalize_search_quality(
        "최근 애플 WWDC 발표 내용",
        sources,
        analysis,
        service._build_search_quality_judge_result(judge_result),
    )

    assert accepted_sources == []
    assert quality.is_sufficient is False
    assert quality.relevant_source_count == 0

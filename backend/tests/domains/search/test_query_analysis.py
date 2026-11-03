import json

import pytest

from domains.llm.schemas import LLMResponse
from domains.search.query import build_rule_query_analysis, merge_query_analysis
from domains.search.service import SearchService
from shared.logging_config import request_context


def test_rule_analysis_enhances_recent_lotte_giants_query():
    analysis = build_rule_query_analysis("최근 롯데 자이언츠 경기", current_date="2026-06-04")

    assert analysis.original_query == "최근 롯데 자이언츠 경기"
    assert "롯데 자이언츠" in analysis.required_phrases
    assert "롯데" in analysis.required_tokens
    assert "KBO" not in analysis.enhanced_query
    assert "경기 결과" in analysis.enhanced_query
    assert "2026-06" in analysis.enhanced_query


def test_rule_analysis_does_not_add_sports_terms_to_travel_query():
    analysis = build_rule_query_analysis("오사카 여행 맛집", current_date="2026-06-04")

    assert analysis.recency_intent is False
    assert "KBO" not in analysis.enhanced_query
    assert "2026년 6월" not in analysis.enhanced_query
    assert "여행 후기" in analysis.enhanced_query


def test_rule_analysis_uses_iso_month_hint_for_recent_queries():
    analysis = build_rule_query_analysis("latest Apple announcement", current_date="2026-06-04")

    assert analysis.recency_intent is True
    assert "2026-06" in analysis.enhanced_query
    assert "2026년 6월" not in analysis.enhanced_query


def test_rule_analysis_uses_iso_month_hint_for_chinese_recent_query():
    analysis = build_rule_query_analysis("最新 苹果 发布", current_date="2026-06-04")

    assert "2026-06" in analysis.enhanced_query
    assert "2026年6月" not in analysis.enhanced_query
    assert "2026년 6월" not in analysis.enhanced_query


@pytest.mark.parametrize(
    ("query", "intent"),
    [("축구 경기 결과", "결과"), ("농구 경기 일정", "일정"), ("시험 결과", "결과")],
)
def test_rule_analysis_does_not_invent_baseball_league(query, intent):
    analysis = build_rule_query_analysis(query, current_date="2026-06-04")

    assert "KBO" not in analysis.enhanced_query
    assert intent in analysis.enhanced_query


def test_rule_analysis_recognizes_recent_news_without_matching_unrelated_last():
    recent = build_rule_query_analysis("요즘 AI 뉴스", current_date="2026-06-04")
    historical = build_rule_query_analysis("last supper painting", current_date="2026-06-04")

    assert recent.recency_intent is True
    assert "AI 뉴스" in recent.enhanced_query
    assert "2026-06" in recent.enhanced_query
    assert historical.recency_intent is False
    assert "2026-06" not in historical.enhanced_query


def test_rule_analysis_keeps_historical_year_without_current_month_hint():
    analysis = build_rule_query_analysis("지난 2020년 경기 결과", current_date="2026-06-04")

    assert analysis.recency_intent is False
    assert "2020년" in analysis.enhanced_query
    assert "2026-06" not in analysis.enhanced_query


def test_merge_query_analysis_preserves_explicit_date_when_llm_drops_it():
    rule = build_rule_query_analysis("2020년 올림픽 축구 결과", current_date="2026-06-04")

    merged = merge_query_analysis(
        rule, {"canonical_topic": "올림픽 축구 결과", "recency_intent": True},
        current_date="2026-06-04",
    )

    assert "2020년" in merged.enhanced_query
    assert "2026-06" not in merged.enhanced_query


@pytest.mark.parametrize(
    ("query", "expected", "unexpected"),
    [
        ("Osaka restaurants", "travel reviews", "여행 후기"),
        ("大阪 旅行", "旅行评价", "여행 후기"),
    ],
)
def test_rule_analysis_uses_query_language_for_travel_hints(query, expected, unexpected):
    analysis = build_rule_query_analysis(query, current_date="2026-06-04")

    assert expected in analysis.enhanced_query
    assert unexpected not in analysis.enhanced_query


def test_merge_query_analysis_keeps_rule_baseline_when_llm_is_missing():
    rule_analysis = build_rule_query_analysis("최근 애플 발표", current_date="2026-06-04")

    merged = merge_query_analysis(rule_analysis, None, current_date="2026-06-04")

    assert merged == rule_analysis
    assert "KBO" not in merged.enhanced_query


@pytest.mark.parametrize(
    ("query", "llm_search_required", "expected"),
    [
        ("면접 자기소개 연습", False, False),
        ("요즘 AI 뉴스", False, True),
        ("축구 경기 결과", False, True),
        ("오사카 맛집 추천", False, True),
        ("여행 경험 이야기", True, True),
    ],
)
def test_search_decision_preserves_explicit_fact_requirements(query, llm_search_required, expected):
    rule = build_rule_query_analysis(query, current_date="2026-06-04")

    merged = merge_query_analysis(rule, {"search_required": llm_search_required})

    assert merged.search_required is expected


@pytest.mark.parametrize("llm_data", [None, {}, {"search_required": "false"}, {"search_required": 0}])
def test_search_decision_defaults_to_search_without_boolean_answer(llm_data):
    rule = build_rule_query_analysis("면접 자기소개 연습", current_date="2026-06-04")

    merged = merge_query_analysis(rule, llm_data)

    assert merged.search_required is True


@pytest.mark.asyncio
async def test_query_analysis_searches_when_llm_fails(monkeypatch):
    service = SearchService()

    async def fail_analysis(*_args, **_kwargs):
        raise RuntimeError("analysis unavailable")

    monkeypatch.setattr(service, "_generate_llm_query_analysis", fail_analysis)

    analysis = await service._analyze_query("면접 자기소개 연습")

    assert analysis.search_required is True


@pytest.mark.asyncio
async def test_llm_query_analyzer_prompt_includes_current_date_and_timezone(monkeypatch, capsys):
    captured = {}

    class FakeProvider:
        async def chat_completion(self, request):
            captured["request"] = request
            return LLMResponse(
                content='{"canonical_topic":"롯데 자이언츠","required_phrases":["롯데 자이언츠"],"required_tokens":["롯데","자이언츠"],"context_terms":["KBO"],"recency_intent":true,"exclude_terms":[],"search_required":true}',
                usage={"prompt_tokens": 101, "completion_tokens": 65},
                upstream_provider="Google",
            )

    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: FakeProvider())

    token = request_context.set({"trace_id": "a" * 32, "request_id": "b" * 32})
    try:
        data = await SearchService()._generate_llm_query_analysis("최근 롯데 자이언츠 경기", "2026-06-04", "Asia/Seoul")
    finally:
        request_context.reset(token)

    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines() if line.startswith("{")]
    llm_row = next(row for row in rows if row.get("stage") == "search.query_analysis.llm_request")
    assert llm_row["prompt_tokens"] == 101
    assert llm_row["completion_tokens"] == 65
    assert llm_row["upstream_provider"] == "Google"
    assert any(row.get("stage") == "search.query_analysis.parse" for row in rows)
    assert "롯데 자이언츠" not in json.dumps(rows, ensure_ascii=False)

    assert data["canonical_topic"] == "롯데 자이언츠"
    assert data["search_required"] is True
    assert captured["request"].extra_params["response_format"]["type"] == "json_schema"
    assert captured["request"].extra_params["provider"] == {"sort": "latency"}
    assert (
        captured["request"].extra_params["response_format"]["json_schema"]["name"]
        == "search_query_analysis"
    )
    user_prompt = captured["request"].messages[1].content
    assert "Current date: 2026-06-04" in user_prompt
    assert "Timezone: Asia/Seoul" in user_prompt


@pytest.mark.asyncio
async def test_query_analyzer_omits_openrouter_routing_for_ollama(monkeypatch):
    service = SearchService()
    monkeypatch.setattr(service.settings, "llm_provider", "ollama")
    captured = {}

    class FakeProvider:
        async def chat_completion(self, request):
            captured["extra_params"] = request.extra_params
            return LLMResponse(content=json.dumps({
                "canonical_topic": "interview practice",
                "required_phrases": [],
                "required_tokens": [],
                "context_terms": [],
                "recency_intent": False,
                "exclude_terms": [],
                "search_required": False,
            }))

    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: FakeProvider())

    await service._generate_llm_query_analysis("interview practice", "2026-06-04", "Asia/Seoul")

    assert "response_format" in captured["extra_params"]
    assert "provider" not in captured["extra_params"]

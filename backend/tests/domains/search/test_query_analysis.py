import pytest

from domains.search.query import build_rule_query_analysis, merge_query_analysis
from domains.search.service import SearchService


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


@pytest.mark.asyncio
async def test_llm_query_analyzer_prompt_includes_current_date_and_timezone(monkeypatch):
    captured = {}

    class FakeResponse:
        content = '{"canonical_topic":"롯데 자이언츠","required_phrases":["롯데 자이언츠"],"required_tokens":["롯데","자이언츠"],"context_terms":["KBO"],"recency_intent":true,"exclude_terms":[]}'

    class FakeProvider:
        async def chat_completion(self, request):
            captured["request"] = request
            return FakeResponse()

    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: FakeProvider())

    data = await SearchService()._generate_llm_query_analysis("최근 롯데 자이언츠 경기", "2026-06-04", "Asia/Seoul")

    assert data["canonical_topic"] == "롯데 자이언츠"
    assert captured["request"].extra_params["response_format"]["type"] == "json_schema"
    assert (
        captured["request"].extra_params["response_format"]["json_schema"]["name"]
        == "search_query_analysis"
    )
    user_prompt = captured["request"].messages[1].content
    assert "Current date: 2026-06-04" in user_prompt
    assert "Timezone: Asia/Seoul" in user_prompt

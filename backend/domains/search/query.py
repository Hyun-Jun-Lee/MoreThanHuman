"""
Search query analysis helpers
"""
import re
from dataclasses import dataclass, replace
from datetime import datetime
from zoneinfo import ZoneInfo


RECENCY_TERMS = {
    "최근",
    "최신",
    "오늘",
    "어제",
    "이번",
    "이번주",
    "지난",
    "current",
    "recent",
    "latest",
    "today",
    "yesterday",
    "this",
    "last",
}

INTENT_STOPWORDS = {
    "경기",
    "결과",
    "일정",
    "뉴스",
    "이슈",
    "소식",
    "정보",
    "알려줘",
    "대해",
    "관련",
    "game",
    "match",
    "result",
    "score",
    "news",
    "issue",
    "about",
    "tell",
    "me",
}

SPORTS_TERMS = {
    "경기",
    "결과",
    "일정",
    "하이라이트",
    "야구",
    "축구",
    "농구",
    "배구",
    "kbo",
    "mlb",
    "game",
    "match",
    "score",
    "result",
}

TRAVEL_TERMS = {"여행", "맛집", "카페", "숙소", "코스", "travel", "restaurant", "food", "hotel"}


@dataclass(frozen=True)
class QueryAnalysis:
    """검색 쿼리 분석 결과"""

    original_query: str
    canonical_topic: str
    required_phrases: list[str]
    required_tokens: list[str]
    context_terms: list[str]
    recency_intent: bool
    exclude_terms: list[str]
    enhanced_query: str


def current_search_context(timezone: str = "Asia/Seoul") -> tuple[str, str]:
    """현재 날짜와 timezone 문자열 반환"""
    now = datetime.now(ZoneInfo(timezone))
    return now.date().isoformat(), timezone


def build_rule_query_analysis(query: str, *, current_date: str | None = None) -> QueryAnalysis:
    """규칙 기반 query analysis baseline 생성"""
    normalized_query = _normalize_spaces(query)
    raw_tokens = _tokenize(normalized_query)
    lowered_tokens = [token.lower() for token in raw_tokens]
    recency_intent = any(_compact(token.lower()) in RECENCY_TERMS for token in raw_tokens)
    core_tokens = [
        token
        for token in raw_tokens
        if _is_core_token(token)
    ]

    canonical_topic = _build_canonical_topic(normalized_query, raw_tokens, core_tokens)
    required_phrases = _dedupe([canonical_topic] if canonical_topic else [])
    required_tokens = _dedupe(core_tokens)
    context_terms = _infer_context_terms(lowered_tokens)
    exclude_terms = ["홈", "메인", "많이 본 뉴스", "최신뉴스", "포털", "news index", "homepage"]
    enhanced_query = build_enhanced_query(
        normalized_query,
        canonical_topic,
        context_terms,
        recency_intent=recency_intent,
        current_date=current_date,
    )

    return QueryAnalysis(
        original_query=normalized_query,
        canonical_topic=canonical_topic or normalized_query,
        required_phrases=required_phrases,
        required_tokens=required_tokens,
        context_terms=context_terms,
        recency_intent=recency_intent,
        exclude_terms=exclude_terms,
        enhanced_query=enhanced_query,
    )


def merge_query_analysis(
    rule_analysis: QueryAnalysis,
    llm_data: dict | None,
    *,
    current_date: str | None = None,
) -> QueryAnalysis:
    """규칙 baseline과 LLM query analyzer 결과 병합"""
    if not llm_data:
        return rule_analysis

    canonical_topic = _clean_string(llm_data.get("canonical_topic")) or rule_analysis.canonical_topic
    required_phrases = _dedupe(
        rule_analysis.required_phrases + _clean_string_list(llm_data.get("required_phrases"))
    )
    required_tokens = _dedupe(
        rule_analysis.required_tokens + _clean_string_list(llm_data.get("required_tokens"))
    )
    context_terms = _dedupe(
        rule_analysis.context_terms + _clean_string_list(llm_data.get("context_terms"))
    )
    exclude_terms = _dedupe(
        rule_analysis.exclude_terms + _clean_string_list(llm_data.get("exclude_terms"))
    )
    recency_intent = rule_analysis.recency_intent or llm_data.get("recency_intent") is True
    enhanced_query = build_enhanced_query(
        rule_analysis.original_query,
        canonical_topic,
        context_terms,
        recency_intent=recency_intent,
        current_date=current_date,
    )

    return replace(
        rule_analysis,
        canonical_topic=canonical_topic,
        required_phrases=required_phrases,
        required_tokens=required_tokens,
        context_terms=context_terms,
        recency_intent=recency_intent,
        exclude_terms=exclude_terms,
        enhanced_query=enhanced_query,
    )


def build_enhanced_query(
    original_query: str,
    canonical_topic: str,
    context_terms: list[str],
    *,
    recency_intent: bool,
    current_date: str | None,
) -> str:
    """검색용 additive query 생성"""
    parts = [canonical_topic or original_query, *context_terms]
    if recency_intent and current_date:
        year, month, *_ = current_date.split("-")
        parts.append(f"{year}년 {int(month)}월")
    return " ".join(_dedupe([part for part in parts if part.strip()]))


def _normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _tokenize(value: str) -> list[str]:
    return re.findall(r"[가-힣A-Za-z0-9]+", value)


def _compact(value: str) -> str:
    return re.sub(r"\s+", "", value)


def _is_core_token(token: str) -> bool:
    lowered = _compact(token.lower())
    if len(lowered) <= 1:
        return False
    return lowered not in RECENCY_TERMS and lowered not in INTENT_STOPWORDS


def _build_canonical_topic(original_query: str, raw_tokens: list[str], core_tokens: list[str]) -> str:
    if not core_tokens:
        return original_query

    token_positions = {token: index for index, token in enumerate(raw_tokens)}
    ordered_core = sorted(core_tokens, key=lambda token: token_positions.get(token, 0))
    return " ".join(ordered_core).strip() or original_query


def _infer_context_terms(lowered_tokens: list[str]) -> list[str]:
    token_set = {_compact(token) for token in lowered_tokens}
    terms: list[str] = []
    if token_set & SPORTS_TERMS:
        terms.extend(["경기 결과", "KBO"] if token_set & {"경기", "야구", "kbo"} else ["game result"])
    if token_set & {"뉴스", "이슈", "소식", "news", "issue"}:
        terms.append("최신 뉴스")
    if token_set & TRAVEL_TERMS:
        terms.extend(["여행 후기", "추천"])
    return _dedupe(terms)


def _clean_string(value: object) -> str | None:
    if not isinstance(value, str):
        return None
    cleaned = _normalize_spaces(value)
    return cleaned or None


def _clean_string_list(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    return [
        cleaned
        for item in value
        if (cleaned := _clean_string(item))
    ]


def _dedupe(values: list[str]) -> list[str]:
    seen = set()
    deduped = []
    for value in values:
        key = value.casefold()
        if key in seen:
            continue
        seen.add(key)
        deduped.append(value)
    return deduped

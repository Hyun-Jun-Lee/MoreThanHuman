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
    "요즘",
    "현재",
    "오늘",
    "어제",
    "이번주",
    "지난주",
    "이번달",
    "지난달",
    "current",
    "recent",
    "latest",
    "today",
    "yesterday",
    "now",
    "最新",
    "最近",
    "现在",
    "目前",
    "今天",
    "昨天",
    "本周",
    "上周",
}

RECENCY_PHRASES = (
    re.compile(r"(?:이번|지난)\s*(?:주|주말|달|개월|월)(?![가-힣])"),
    re.compile(r"\b(?:this|last)\s+(?:week|month|night)\b", re.IGNORECASE),
)
EXPLICIT_DATE = re.compile(
    r"(?<!\d)(?:19|20)\d{2}(?:[-./]\d{1,2}(?:[-./]\d{1,2})?|년(?:\s*\d{1,2}월?)?|年(?:\s*\d{1,2}月?)?)?(?!\d)"
)

INTENT_STOPWORDS = {
    "정보",
    "알려줘",
    "대해",
    "관련",
    "이번",
    "지난",
    "about",
    "tell",
    "me",
}

SPORTS_TERMS = {
    "경기",
    "하이라이트",
    "야구",
    "축구",
    "농구",
    "배구",
    "kbo",
    "mlb",
    "game",
    "match",
}

TRAVEL_TERMS = {
    "여행", "맛집", "숙소", "코스", "旅游", "旅行", "餐厅", "住宿",
    "travel", "trip", "restaurant", "restaurants", "hotel", "hotels",
}
NEWS_TERMS = {"뉴스", "이슈", "소식", "news", "issue", "新闻", "消息"}
GENERIC_INTENT_TERMS = {
    "경기", "결과", "일정", "뉴스", "이슈", "소식",
    "game", "match", "result", "score", "news", "issue",
}


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
    recency_intent = _has_recency_intent(normalized_query, lowered_tokens)
    core_tokens = [
        token
        for token in raw_tokens
        if _is_core_token(token)
    ]

    canonical_topic = _build_canonical_topic(normalized_query, core_tokens)
    phrase_tokens = [token for token in core_tokens if token.lower() not in GENERIC_INTENT_TERMS]
    required_phrases = [_build_canonical_topic(normalized_query, phrase_tokens)]
    required_tokens = _dedupe(core_tokens)
    context_terms = _infer_context_terms(
        lowered_tokens, language=_query_language(normalized_query), recency_intent=recency_intent,
    )
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
    base_query = canonical_topic or original_query
    parts = [base_query, *(term for term in context_terms if term.casefold() not in base_query.casefold())]
    explicit_dates = EXPLICIT_DATE.findall(original_query)
    parts.extend(date for date in explicit_dates if date not in base_query)
    if recency_intent and current_date and not explicit_dates:
        parts.append(_build_recency_date_hint(current_date))
    return " ".join(_dedupe([part for part in parts if part.strip()]))


def _normalize_spaces(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _tokenize(value: str) -> list[str]:
    return re.findall(r"[가-힣\u4e00-\u9fffA-Za-z0-9]+", value)


def _build_recency_date_hint(current_date: str) -> str:
    """검색 provider에 전달할 언어 중립 월 힌트 생성"""
    year, month, *_ = current_date.split("-")
    return f"{year}-{month}"


def _compact(value: str) -> str:
    return re.sub(r"\s+", "", value)


def _has_recency_intent(query: str, lowered_tokens: list[str]) -> bool:
    return bool(set(lowered_tokens) & RECENCY_TERMS) or any(
        pattern.search(query) for pattern in RECENCY_PHRASES
    )


def _query_language(query: str) -> str:
    if re.search(r"[가-힣]", query):
        return "ko"
    if re.search(r"[\u4e00-\u9fff]", query):
        return "zh"
    return "en"


def _is_core_token(token: str) -> bool:
    lowered = _compact(token.lower())
    if len(lowered) <= 1:
        return False
    return lowered not in RECENCY_TERMS and lowered not in INTENT_STOPWORDS


def _build_canonical_topic(original_query: str, core_tokens: list[str]) -> str:
    if not core_tokens:
        return original_query
    return " ".join(core_tokens).strip() or original_query


def _infer_context_terms(lowered_tokens: list[str], *, language: str, recency_intent: bool) -> list[str]:
    token_set = {_compact(token) for token in lowered_tokens}
    terms: list[str] = []
    if token_set & SPORTS_TERMS:
        terms.append({"ko": "경기 결과", "zh": "比赛结果", "en": "game result"}[language])
    if recency_intent and token_set & NEWS_TERMS:
        terms.append({"ko": "최신 뉴스", "zh": "最新新闻", "en": "latest news"}[language])
    if token_set & TRAVEL_TERMS:
        terms.extend({
            "ko": ["여행 후기", "추천"],
            "zh": ["旅行评价", "推荐"],
            "en": ["travel reviews", "recommendations"],
        }[language])
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

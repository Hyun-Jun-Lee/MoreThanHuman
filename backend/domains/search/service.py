"""
Search Service Layer
"""
import asyncio
import json
import logging
import re
import time
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ValidationError

from config import get_model_for_provider, get_settings
from domains.llm.factory import LLMProviderFactory
from domains.llm.provider import LLMProvider
from domains.llm.schemas import LLMMessage, LLMRequest, LLMResponse
from domains.search.provider import DuckDuckGoSearchProvider
from domains.search.query import (
    QueryAnalysis,
    build_rule_query_analysis,
    current_search_context,
    merge_query_analysis,
)
from domains.search.schemas import (
    ConversationDirection,
    CustomFocusQuestionsResult,
    SearchQualityJudgeResult,
    SearchQuality,
    SearchQueryAnalysisResult,
    SearchResult,
    SearchResultItem,
    TopicPrepCard,
    TopicPrepDirection,
    TopicPrepDirectionsResult,
    TopicPrepQuality,
    TopicPrepResult,
)
from shared.exceptions import ExternalAPIException
from shared.language import (
    LanguageCode,
    LearningLanguageContext,
    ensure_language_context,
    language_name,
)
from shared.language_prompt_policy import (
    format_topic_prep_priorities,
    practice_priority_summary,
)

logger = logging.getLogger(__name__)

MIN_TOPIC_PREP_SOURCE_COUNT = 3
INCOMPLETE_TOPIC_PREP_CARD_REASON = "검색 결과로 대화 준비 카드를 완성하지 못했어요."


def resolve_topic_display_language(topic: str, native_language: LanguageCode) -> LanguageCode:
    """입력 주제의 표시 언어를 판별하고 모호하면 모국어를 사용한다."""
    hangul_count = len(re.findall(r"[가-힣]", topic))
    han_count = len(re.findall(r"[\u4e00-\u9fff]", topic))
    latin_words = re.findall(r"[A-Za-z]+", topic)

    if hangul_count > 0 and hangul_count >= han_count:
        return LanguageCode.KOREAN
    if han_count > 0:
        return LanguageCode.CHINESE
    # 단일 로마자 고유명사는 언어를 단정하지 않는다.
    if len(latin_words) >= 2:
        return LanguageCode.ENGLISH
    return native_language


@dataclass(frozen=True)
class PreparedSearchResult:
    """검색 품질 파이프라인 결과"""

    analysis: QueryAnalysis
    sources: list[SearchResultItem]
    quality: SearchQuality


class SearchService:
    """검색 서비스"""

    def __init__(self, search_provider: DuckDuckGoSearchProvider | None = None):
        self.settings = get_settings()
        self.search_provider = search_provider or DuckDuckGoSearchProvider(self.settings)

    async def search(
        self,
        query: str,
        language_context: LearningLanguageContext | None = None,
    ) -> SearchResult:
        """
        DuckDuckGo 검색 후 LLM 요약

        Args:
            query: 검색 쿼리

        Returns:
            요약된 검색 결과
        """
        language_context = ensure_language_context(language_context)
        prepared = await self._prepare_search_results(query, language_context=language_context)
        if not prepared.quality.is_sufficient:
            return SearchResult(
                query=query,
                enhanced_query=prepared.analysis.enhanced_query,
                language=language_context,
                ready=False,
                sources=prepared.sources,
                quality=prepared.quality,
                retry_guidance=prepared.quality.retry_suggestion
                or self._build_retry_guidance(query, language_context=language_context),
                example_queries=self._build_example_topics(query, language_context=language_context),
                timestamp=datetime.utcnow(),
            )

        summary = await self._summarize_results(
            query,
            prepared.sources,
            prepared.analysis,
            language_context=language_context,
        )
        return SearchResult(
            query=query,
            enhanced_query=prepared.analysis.enhanced_query,
            language=language_context,
            ready=True,
            summary=summary,
            sources=prepared.sources,
            quality=prepared.quality,
            timestamp=datetime.utcnow(),
        )

    async def prepare_topic(
        self,
        topic: str,
        language_context: LearningLanguageContext | None = None,
    ) -> TopicPrepResult:
        """
        검색 기반 대화 전 주제 준비 카드 생성

        Args:
            topic: 사용자가 대화하고 싶은 관심 주제

        Returns:
            준비 카드 생성 결과
        """
        language_context = ensure_language_context(language_context)
        prepared = await self._prepare_search_results(topic, language_context=language_context)
        if not prepared.quality.is_sufficient:
            return self._build_low_quality_result(
                topic,
                prepared.sources,
                reason=prepared.quality.reason or "대화 준비에 사용할 검색 출처가 충분하지 않아요.",
                retry_suggestion=prepared.quality.retry_suggestion,
                language_context=language_context,
            )

        card = await self._generate_topic_prep_card(
            topic,
            prepared.sources,
            prepared.analysis,
            language_context=language_context,
        )
        if not card.quality.is_sufficient:
            return self._build_not_ready_topic_prep_result(
                topic,
                card.quality,
                language_context=language_context,
                use_quality_retry_suggestion=False,
            )

        return TopicPrepResult(
            ready=True,
            language=language_context,
            card=card,
            quality=card.quality,
        )

    async def prepare_custom_focus_questions(
        self,
        topic: str,
        custom_focus: str,
        language_context: LearningLanguageContext | None = None,
    ) -> CustomFocusQuestionsResult:
        """사용자가 직접 적은 대화 방향에 맞는 첫 질문을 생성한다."""
        language_context = ensure_language_context(language_context)
        focus = custom_focus.strip()
        display_language = resolve_topic_display_language(topic, language_context.native_language)
        prepared = await self._prepare_search_results(topic, language_context=language_context)
        if not prepared.quality.is_sufficient:
            return CustomFocusQuestionsResult(
                ready=False,
                custom_focus=focus,
                retry_guidance=self._custom_focus_retry_guidance(display_language),
            )

        source_text = self._format_topic_prep_sources(prepared.sources)
        target_name = language_name(language_context.target_language)
        display_name = language_name(display_language)
        provider = LLMProviderFactory.create_provider()
        response = await provider.chat_completion(
            LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=(
                            f"Create exactly three first conversation questions in {target_name}. "
                            "The learner must answer in the practice target language. "
                            f"Decide whether the user's focus is genuinely about the topic. "
                            f"Write retry_guidance in {display_name} only when it is unrelated. "
                            'Return JSON only: {"is_relevant": true, "first_questions": ["q1", "q2", "q3"], '
                            '"retry_guidance": null}.'
                        ),
                    ),
                    LLMMessage(
                        role="user",
                        content=f"Topic: {topic}\nFocus: {focus}\n\nSearch Results:\n{source_text}",
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=min(self.settings.max_tokens, 700),
                temperature=0.4,
            )
        )
        data = self._parse_json_response(response.content)
        questions = [str(question).strip() for question in data.get("first_questions", []) if str(question).strip()]
        is_relevant = data.get("is_relevant") is True and len(questions) == 3
        return CustomFocusQuestionsResult(
            ready=is_relevant,
            custom_focus=focus,
            first_questions=questions if is_relevant else [],
            retry_guidance=(
                None
                if is_relevant
                else str(data.get("retry_guidance") or self._custom_focus_retry_guidance(display_language))
            ),
        )

    async def regenerate_topic_prep_directions(
        self,
        topic: str,
        previous_directions: list[str],
        language_context: LearningLanguageContext | None = None,
    ) -> TopicPrepDirectionsResult:
        """같은 검증 주제에서 새로운 세 대화 방향만 생성한다."""
        language_context = ensure_language_context(language_context)
        display_language = resolve_topic_display_language(topic, language_context.native_language)
        prepared = await self._prepare_search_results(topic, language_context=language_context)
        if not prepared.quality.is_sufficient:
            raise ExternalAPIException("Topic prep directions are unavailable for this topic")

        source_text = self._format_topic_prep_sources(prepared.sources)
        target_name = language_name(language_context.target_language)
        display_name = language_name(display_language)
        directions = ", ".join(direction.value for direction in ConversationDirection)
        provider = LLMProviderFactory.create_provider()
        response = await provider.chat_completion(
            LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=(
                            f"Create exactly three conversation directions for a {target_name} learner. "
                            f"Use exactly these values once each: {directions}. "
                            f"Write each title and description in {display_name}; write each of exactly three first questions in {target_name}. "
                            "Make them materially different from the previous direction text. "
                            'Return JSON only: {"directions": [{"direction": "CASUAL_CHAT", "title": "...", '
                            '"description": "...", "first_questions": ["q1", "q2", "q3"]}]}.'
                        ),
                    ),
                    LLMMessage(
                        role="user",
                        content=(
                            f"Topic: {topic}\nPrevious directions: {json.dumps(previous_directions)}\n\n"
                            f"Search Results:\n{source_text}"
                        ),
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=min(self.settings.max_tokens, 1000),
                temperature=0.75,
            )
        )
        data = self._parse_json_response(response.content)
        raw_directions = data.get("directions", [])
        if not self._has_complete_directions_payload(raw_directions):
            raise ExternalAPIException("Topic prep directions response was incomplete")
        return TopicPrepDirectionsResult(
            directions=self._normalize_topic_prep_directions(
                topic,
                raw_directions,
                language_context=language_context,
                display_language=display_language,
            )
        )

    async def _prepare_search_results(
        self,
        query: str,
        language_context: LearningLanguageContext | None = None,
    ) -> PreparedSearchResult:
        """검색 전처리, 검색 수집, LLM source judge를 실행"""
        language_context = ensure_language_context(language_context)
        analysis = await self._analyze_query(query, language_context=language_context)
        logger.info(
            "Search pipeline stage=provider_search query=%r enhanced_query=%r recency_intent=%s",
            query,
            analysis.enhanced_query,
            analysis.recency_intent,
        )
        raw_results = await self._search_duckduckgo(
            analysis.enhanced_query,
            analysis,
            language_context=language_context,
        )
        sources = [
            SearchResultItem(
                title=r.get("title", ""),
                url=r.get("href", ""),
                snippet=r.get("body", "")[:300],
            )
            for r in raw_results
        ]
        logger.info(
            "Search pipeline stage=source_collection query=%r raw_count=%s",
            query,
            len(sources),
        )
        if not sources:
            return PreparedSearchResult(
                analysis=analysis,
                sources=[],
                quality=self._build_failed_search_quality(
                    source_count=0,
                    reason="검색 결과를 찾지 못했어요.",
                    retry_suggestion=self._build_retry_guidance(query, language_context=language_context),
                ),
            )

        accepted_sources, quality = await self._judge_search_quality(
            query,
            sources,
            analysis,
            language_context=language_context,
        )
        return PreparedSearchResult(
            analysis=analysis,
            sources=accepted_sources,
            quality=quality,
        )

    async def _analyze_query(
        self,
        query: str,
        language_context: LearningLanguageContext | None = None,
    ) -> QueryAnalysis:
        """규칙 baseline과 LLM query analyzer를 조합"""
        current_date, _timezone = current_search_context()
        rule_analysis = build_rule_query_analysis(query, current_date=current_date)
        try:
            llm_data = await self._generate_llm_query_analysis(
                query,
                current_date,
                _timezone,
                language_context=ensure_language_context(language_context),
            )
        except Exception as exc:
            logger.exception(
                "Search LLM stage=query_analysis status=fallback query=%r current_date=%s timezone=%s error=%s",
                query,
                current_date,
                _timezone,
                exc,
            )
            llm_data = None
        return merge_query_analysis(rule_analysis, llm_data, current_date=current_date)

    async def _generate_llm_query_analysis(
        self,
        query: str,
        current_date: str,
        timezone: str,
        language_context: LearningLanguageContext | None = None,
    ) -> dict | None:
        """LLM query analyzer JSON 생성"""
        language_context = ensure_language_context(language_context)
        target_name = language_name(language_context.target_language)
        native_name = language_name(language_context.native_language)
        provider = LLMProviderFactory.create_provider()
        started_at = time.perf_counter()
        request = LLMRequest(
            messages=[
                LLMMessage(
                    role="system",
                    content=(
                        f"You analyze a user's search topic for a {target_name} conversation app. "
                        f"The learner's native language is {native_name}. "
                        "Return only valid JSON with keys: canonical_topic, required_phrases, "
                        "required_tokens, context_terms, recency_intent, exclude_terms. "
                        "Keep query expansion additive and do not change the user's intent."
                    ),
                ),
                LLMMessage(
                    role="user",
                    content=(
                        f"Current date: {current_date}\n"
                        f"Timezone: {timezone}\n"
                        f"Query: {query}"
                    ),
                ),
            ],
            model=get_model_for_provider(),
            max_tokens=self.settings.search_query_analysis_max_tokens,
            temperature=0.1,
            extra_params=self._build_structured_output_params(
                SearchQueryAnalysisResult,
                "search_query_analysis",
            ),
        )
        logger.info(
            "Search LLM stage=query_analysis status=start provider=%s model=%s query=%r current_date=%s timezone=%s",
            self._provider_name(provider),
            request.model,
            query,
            current_date,
            timezone,
        )
        response = await self._chat_completion_with_structured_fallback(
            provider,
            request,
            stage="query_analysis",
            query=query,
        )
        data = self._parse_structured_json_response(response.content, SearchQueryAnalysisResult)
        logger.info(
            "Search LLM stage=query_analysis status=success provider=%s model=%s duration_ms=%s response_chars=%s",
            self._provider_name(provider),
            request.model,
            round((time.perf_counter() - started_at) * 1000),
            len(response.content or ""),
        )
        return data if isinstance(data, dict) else None

    async def _search_duckduckgo(
        self,
        query: str,
        analysis: QueryAnalysis | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> list[dict]:
        """
        DuckDuckGo 검색 (동기 라이브러리를 스레드에서 실행)

        Args:
            query: 검색 쿼리

        Returns:
            검색 결과 리스트

        Raises:
            ExternalAPIException: 검색 실패
        """
        try:
            return await asyncio.to_thread(
                self._sync_search,
                query,
                analysis,
                ensure_language_context(language_context),
            )
        except ExternalAPIException:
            raise
        except Exception as e:
            raise ExternalAPIException(f"DuckDuckGo search failed: {str(e)}")

    def _sync_search(
        self,
        query: str,
        analysis: QueryAnalysis | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> list[dict]:
        """DuckDuckGo 동기 검색"""
        return self.search_provider.text(
            query,
            use_recency_timelimit=bool(analysis and analysis.recency_intent),
            region=self._resolve_search_region(ensure_language_context(language_context)),
        )

    async def _judge_search_quality(
        self,
        query: str,
        sources: list[SearchResultItem],
        analysis: QueryAnalysis,
        language_context: LearningLanguageContext | None = None,
    ) -> tuple[list[SearchResultItem], SearchQuality]:
        """LLM으로 source 채택과 최종 대화 적합성 판단"""
        language_context = ensure_language_context(language_context)
        target_name = language_name(language_context.target_language)
        feedback_name = language_name(language_context.feedback_language)
        practice_summary = practice_priority_summary(language_context.target_language)
        current_date, timezone = current_search_context()
        source_text = self._format_numbered_sources(sources)
        analysis_text = self._format_query_analysis_for_judge(analysis)
        try:
            provider = LLMProviderFactory.create_provider()
            started_at = time.perf_counter()
            request = LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=(
                            f"You are the primary source quality judge for a {target_name} conversation app. "
                            "Select only sources that are directly useful for discussing the user's topic. "
                            f"Judge usefulness for target-language practice priorities: {practice_summary}. "
                            "Return only valid JSON with keys: is_sufficient, accepted_source_ids, "
                            "rejected_sources, relevance, freshness, specificity, reason, retry_suggestion. "
                            "Use 1-based source ids from the provided list. "
                            "accepted_source_ids must be an array of integers. "
                            "rejected_sources must explain rejected ids with one short reason each. "
                            "is_sufficient, relevance, freshness, and specificity must be JSON booleans, "
                            "not numeric ratings. "
                            f"Write reason and retry_suggestion in {feedback_name}. "
                            "Keep reason and retry_suggestion to one short sentence each, or null when sufficient. "
                            f"Set is_sufficient true only when at least {self.settings.search_min_relevant_results} "
                            "independent accepted sources are enough for a concrete conversation and summary. "
                            "Treat canonical_topic, required_phrases, required_tokens, and exclude_terms as hard "
                            "guidance from the query analysis. Reject sources that do not mention the canonical "
                            "topic or required terms in the title/snippet, unless they are clearly equivalent. "
                            "Reject portal homepages, search result pages, tag pages, news index pages, generic "
                            "aggregators, ads, shallow listicles, unrelated profiles, duplicate sources, and "
                            "snippets too vague to support a concrete conversation. Accept sources only when "
                            "they provide concrete facts, events, people, places, outcomes, dates, or distinct "
                            "context for the topic. If recency_intent is true, stale background sources or "
                            "sources without current context are insufficient. If recency_intent is false, "
                            "freshness should not block sufficiency. You only see title, snippet, and URL; "
                            "when uncertain, reject conservatively."
                        ),
                    ),
                    LLMMessage(
                        role="user",
                        content=(
                            f"Current date: {current_date}\n"
                            f"Timezone: {timezone}\n"
                            f"Original query: {query}\n"
                            f"Enhanced query: {analysis.enhanced_query}\n\n"
                            f"Query analysis:\n{analysis_text}\n\n"
                            f"Sources:\n{source_text}"
                        ),
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=self.settings.search_quality_judge_max_tokens,
                temperature=0.1,
                extra_params=self._build_structured_output_params(
                    SearchQualityJudgeResult,
                    "search_quality_judge",
                ),
            )
            logger.info(
                "Search LLM stage=quality_judge status=start provider=%s model=%s query=%r source_count=%s",
                self._provider_name(provider),
                request.model,
                query,
                len(sources),
            )
            response = await self._chat_completion_with_structured_fallback(
                provider,
                request,
                stage="quality_judge",
                query=query,
            )
            data = self._parse_structured_json_response(response.content, SearchQualityJudgeResult)
            judge_result = self._build_search_quality_judge_result(data)
            accepted_sources, quality = self._finalize_search_quality(
                query,
                sources,
                analysis,
                judge_result,
                language_context=language_context,
            )
            logger.info(
                "Search LLM stage=quality_judge status=success provider=%s model=%s duration_ms=%s sufficient=%s accepted_count=%s rejected_count=%s response_chars=%s",
                self._provider_name(provider),
                request.model,
                round((time.perf_counter() - started_at) * 1000),
                quality.is_sufficient,
                quality.relevant_source_count,
                len(judge_result.rejected_sources),
                len(response.content or ""),
            )
            return accepted_sources, quality
        except Exception as exc:
            logger.exception(
                "Search LLM stage=quality_judge status=fallback query=%r enhanced_query=%r error=%s",
                query,
                analysis.enhanced_query,
                exc,
            )
            return [], self._build_failed_search_quality(
                source_count=len(sources),
                reason="검색 결과를 품질 판단하는 중 오류가 발생했어요.",
                retry_suggestion=self._build_retry_guidance(query, language_context=language_context),
            )

    def _build_structured_output_params(
        self,
        schema_model: type[BaseModel],
        schema_name: str,
    ) -> dict[str, Any]:
        """OpenAI-compatible structured output 파라미터 생성"""
        return {
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": schema_name,
                    "strict": True,
                    "schema": schema_model.model_json_schema(),
                },
            },
        }

    async def _chat_completion_with_structured_fallback(
        self,
        provider: LLMProvider,
        request: LLMRequest,
        *,
        stage: str,
        query: str,
    ) -> LLMResponse:
        """structured output 미지원 모델은 기존 JSON prompt 방식으로 재시도"""
        try:
            return await provider.chat_completion(request)
        except ExternalAPIException as exc:
            if not self._should_retry_without_structured_output(exc):
                raise
            logger.warning(
                "Search LLM stage=%s status=structured_output_fallback provider=%s query=%r error=%s",
                stage,
                self._provider_name(provider),
                query,
                exc,
            )
            return await provider.chat_completion(request.model_copy(update={"extra_params": None}))

    def _should_retry_without_structured_output(self, exc: ExternalAPIException) -> bool:
        """provider/model이 structured output을 거부한 오류인지 추정"""
        message = str(exc).casefold()
        return any(
            marker in message
            for marker in (
                "response_format",
                "json_schema",
                "structured",
                "schema",
                "unsupported parameter",
                "not support",
            )
        )

    def _parse_structured_json_response(
        self,
        response: str,
        schema_model: type[BaseModel],
    ) -> dict:
        """structured output 응답을 Pydantic으로 우선 검증하고 기존 parser로 보정"""
        try:
            return schema_model.model_validate_json(response).model_dump()
        except ValidationError:
            return self._parse_json_response(response)

    def _format_query_analysis_for_judge(self, analysis: QueryAnalysis) -> str:
        """source judge에 전달할 query analysis 상세 컨텍스트"""
        return "\n".join(
            [
                f"Canonical topic: {analysis.canonical_topic}",
                f"Required phrases: {self._format_string_list(analysis.required_phrases)}",
                f"Required tokens: {self._format_string_list(analysis.required_tokens)}",
                f"Context terms: {self._format_string_list(analysis.context_terms)}",
                f"Exclude terms: {self._format_string_list(analysis.exclude_terms)}",
                f"Recency intent: {analysis.recency_intent}",
            ]
        )

    def _format_string_list(self, values: list[str]) -> str:
        """프롬프트용 문자열 리스트 포맷"""
        return ", ".join(values) if values else "none"

    def _build_search_quality_judge_result(self, data: dict) -> SearchQualityJudgeResult:
        """LLM source judge JSON을 내부 모델로 변환"""
        if not isinstance(data, dict):
            return SearchQualityJudgeResult.model_validate(data)

        normalized = {
            key: data.get(key)
            for key in (
                "is_sufficient",
                "accepted_source_ids",
                "rejected_sources",
                "relevance",
                "freshness",
                "specificity",
                "reason",
                "retry_suggestion",
            )
            if key in data
        }
        normalized["accepted_source_ids"] = self._coerce_int_list(
            data.get("accepted_source_ids")
            or data.get("accepted_sources")
            or data.get("accepted_ids")
            or []
        )
        normalized["rejected_sources"] = self._coerce_rejected_sources(
            data.get("rejected_sources")
            or data.get("rejected_source_ids")
            or data.get("rejected_ids")
            or []
        )
        for field in ("is_sufficient", "relevance", "freshness", "specificity"):
            if field in normalized:
                normalized[field] = self._coerce_llm_bool(normalized[field])

        return SearchQualityJudgeResult.model_validate(normalized)

    def _coerce_int_list(self, values: Any) -> list[int]:
        """LLM이 문자열 숫자로 반환한 source id를 정수 리스트로 보정"""
        if not isinstance(values, list):
            return []

        ids = []
        for value in values:
            try:
                ids.append(int(value))
            except (TypeError, ValueError):
                continue
        return ids

    def _coerce_rejected_sources(self, values: Any) -> list[dict]:
        """LLM rejected_sources 축약 응답을 객체 리스트로 보정"""
        if not isinstance(values, list):
            return []

        rejected_sources = []
        for value in values:
            if isinstance(value, dict):
                source_id = value.get("id") or value.get("source_id")
                reason = value.get("reason") or "LLM이 대화에 덜 유용한 출처로 판단했어요."
            else:
                source_id = value
                reason = "LLM이 대화에 덜 유용한 출처로 판단했어요."

            try:
                rejected_sources.append({"id": int(source_id), "reason": str(reason)})
            except (TypeError, ValueError):
                continue

        return rejected_sources

    def _coerce_llm_bool(self, value: Any) -> Any:
        """LLM의 boolean 유사 응답을 bool로 보정"""
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return value >= 4
        if isinstance(value, str):
            lowered = value.strip().casefold()
            if lowered in {"true", "yes", "y", "sufficient", "pass"}:
                return True
            if lowered in {"false", "no", "n", "insufficient", "fail"}:
                return False
            try:
                return float(lowered) >= 4
            except ValueError:
                return value
        return value

    def _format_numbered_sources(self, sources: list[SearchResultItem]) -> str:
        """LLM judge에 전달할 numbered source 목록 생성"""
        return "\n".join(
            f"Source {index}\n"
            f"Title: {source.title}\n"
            f"Snippet: {source.snippet}\n"
            f"URL: {source.url}"
            for index, source in enumerate(sources, start=1)
        )

    def _finalize_search_quality(
        self,
        query: str,
        sources: list[SearchResultItem],
        analysis: QueryAnalysis,
        judge_result: SearchQualityJudgeResult,
        language_context: LearningLanguageContext | None = None,
    ) -> tuple[list[SearchResultItem], SearchQuality]:
        """LLM judge 결과를 API 응답용 quality로 정규화"""
        language_context = ensure_language_context(language_context)
        source_count = len(sources)
        accepted_ids = list(dict.fromkeys(judge_result.accepted_source_ids))
        has_invalid_source_id = any(source_id < 1 or source_id > source_count for source_id in accepted_ids)

        if has_invalid_source_id:
            return [], self._build_failed_search_quality(
                source_count=source_count,
                reason="검색 품질 판단 결과에 유효하지 않은 출처가 포함됐어요.",
                retry_suggestion=self._build_retry_guidance(query, language_context=language_context),
            )

        accepted_sources = [
            sources[source_id - 1]
            for source_id in accepted_ids
        ]
        freshness = True if not analysis.recency_intent else judge_result.freshness
        has_enough_sources = len(accepted_sources) >= self.settings.search_min_relevant_results
        is_sufficient = (
            judge_result.is_sufficient
            and judge_result.relevance
            and freshness
            and judge_result.specificity
            and has_enough_sources
        )
        reason = judge_result.reason
        retry_suggestion = judge_result.retry_suggestion
        if not is_sufficient:
            reason = reason or "검색 결과가 주제와 충분히 관련되어 있지 않아요."
            retry_suggestion = retry_suggestion or self._build_retry_guidance(
                query,
                language_context=language_context,
            )

        quality = SearchQuality(
            is_sufficient=is_sufficient,
            source_count=source_count,
            relevant_source_count=len(accepted_sources),
            dropped_source_count=source_count - len(accepted_sources),
            relevance=judge_result.relevance,
            freshness=freshness,
            specificity=judge_result.specificity,
            reason=None if is_sufficient else reason,
            retry_suggestion=None if is_sufficient else retry_suggestion,
        )
        logger.info(
            "Search pipeline stage=quality_finalizer query=%r raw_count=%s accepted_count=%s dropped_count=%s sufficient=%s",
            query,
            quality.source_count,
            quality.relevant_source_count,
            quality.dropped_source_count,
            quality.is_sufficient,
        )
        return accepted_sources, quality

    def _build_failed_search_quality(
        self,
        *,
        source_count: int,
        reason: str,
        retry_suggestion: str,
    ) -> SearchQuality:
        """LLM judge 실패/무효 결과에 대한 품질 실패 생성"""
        return SearchQuality(
            is_sufficient=False,
            source_count=source_count,
            relevant_source_count=0,
            dropped_source_count=source_count,
            relevance=False,
            freshness=False,
            specificity=False,
            reason=reason,
            retry_suggestion=retry_suggestion,
        )

    async def _summarize_results(
        self,
        query: str,
        sources: list[SearchResultItem],
        analysis: QueryAnalysis,
        language_context: LearningLanguageContext | None = None,
    ) -> str:
        """
        LLM을 사용하여 검색 결과 요약

        Args:
            query: 원본 검색 쿼리
            sources: 검색 결과 항목 리스트

        Returns:
            요약 텍스트
        """
        if not sources:
            return f"No results found for: {query}"
        language_context = ensure_language_context(language_context)
        target_name = language_name(language_context.target_language)
        feedback_name = language_name(language_context.feedback_language)
        practice_summary = practice_priority_summary(language_context.target_language)

        source_text = "\n".join(
            f"- {s.title}: {s.snippet}" for s in sources
        )
        current_date, timezone = current_search_context()

        try:
            provider = LLMProviderFactory.create_provider()
            started_at = time.perf_counter()
            request = LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=(
                            "Summarize the following search results into a concise paragraph. "
                            "Focus on key facts and information relevant to the query. "
                            f"Write in {target_name} for conversation practice. "
                            f"Keep the summary useful for these practice priorities: {practice_summary}. "
                            f"Use {feedback_name} only for brief learning guidance if needed. "
                            "Keep it under 150 words."
                        ),
                    ),
                    LLMMessage(
                        role="user",
                        content=(
                            f"Current date: {current_date}\n"
                            f"Timezone: {timezone}\n"
                            f"Original query: {query}\n"
                            f"Enhanced query: {analysis.enhanced_query}\n\n"
                            f"Search Results:\n{source_text}"
                        ),
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=self.settings.search_summary_max_tokens,
                temperature=0.3,
            )

            logger.info(
                "Search LLM stage=summarization status=start provider=%s model=%s query=%r source_count=%s",
                self._provider_name(provider),
                request.model,
                query,
                len(sources),
            )
            response = await provider.chat_completion(request)
            logger.info(
                "Search LLM stage=summarization status=success provider=%s model=%s duration_ms=%s response_chars=%s",
                self._provider_name(provider),
                request.model,
                round((time.perf_counter() - started_at) * 1000),
                len(response.content or ""),
            )
            return response.content
        except Exception as e:
            logger.exception(
                "Search LLM stage=summarization status=fallback query=%r enhanced_query=%r source_count=%s error=%s",
                query,
                analysis.enhanced_query,
                len(sources),
                e,
            )
            return "\n".join(f"- {s.title}: {s.snippet}" for s in sources)

    async def _generate_topic_prep_card(
        self,
        topic: str,
        sources: list[SearchResultItem],
        analysis: QueryAnalysis | None = None,
        language_context: LearningLanguageContext | None = None,
        display_language: LanguageCode | None = None,
    ) -> TopicPrepCard:
        """LLM으로 검색 품질 판정과 준비 카드 내용을 생성"""
        language_context = ensure_language_context(language_context)
        display_language = display_language or resolve_topic_display_language(
            topic, language_context.native_language
        )
        source_text = "\n".join(
            f"- Title: {source.title}\n  Snippet: {source.snippet}\n  URL: {source.url}"
            for source in sources
        )
        current_date, timezone = current_search_context()

        try:
            provider = LLMProviderFactory.create_provider()
            request = LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=self._build_topic_prep_system_prompt(
                            language_context=language_context,
                            display_language=display_language,
                        ),
                    ),
                    LLMMessage(
                        role="user",
                        content=(
                            f"Current date: {current_date}\n"
                            f"Timezone: {timezone}\n"
                            f"Topic: {topic}\n"
                            f"Enhanced query: {analysis.enhanced_query if analysis else topic}\n\n"
                            f"Search Results:\n{source_text}"
                        ),
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=min(self.settings.max_tokens, 1600),
                temperature=0.2,
            )
            response = await provider.chat_completion(request)
            data = self._parse_json_response(response.content)
            return self._build_topic_prep_card_from_data(
                topic,
                sources,
                data,
                language_context=language_context,
                display_language=display_language,
            )
        except ExternalAPIException:
            raise
        except Exception as e:
            logger.error(f"Topic prep generation failed: {e}", exc_info=True)
            raise ExternalAPIException(f"Topic prep generation failed: {str(e)}")

    def _build_topic_prep_system_prompt(
        self,
        language_context: LearningLanguageContext | None = None,
        display_language: LanguageCode | None = None,
    ) -> str:
        """주제 준비 카드 생성 프롬프트"""
        language_context = ensure_language_context(language_context)
        display_language = display_language or language_context.native_language
        target_name = language_name(language_context.target_language)
        feedback_name = language_name(language_context.feedback_language)
        native_name = language_name(language_context.native_language)
        display_name = language_name(display_language)
        topic_prep_priorities = format_topic_prep_priorities(language_context.target_language)
        directions = ", ".join(direction.value for direction in ConversationDirection)
        return f"""You create pre-conversation topic prep cards for {target_name} learners.

Learner language context:
- Native language: {native_name}
- Practice target language: {target_name}
- Feedback/retry guidance language: {feedback_name}

Target-language practice priorities:
{topic_prep_priorities}

Evaluate whether the search results are good enough to start a concrete {target_name} conversation.
Judge quality using:
1. source_count: enough independent sources
2. relevance: directly related to the user's topic
3. freshness: clear recent/current context when the topic asks for recent/current news
4. specificity: concrete people, events, results, or issues rather than generic background

If the quality is insufficient, set is_sufficient to false and explain how to make the topic more specific.
If sufficient, create a short {display_name} summary and exactly three conversation directions.
Each direction must use one of these direction values: {directions}.
Each direction must include exactly three first questions.
Questions must be specific to the search summary and must not be generic questions like "Do you like baseball?"
For sufficient cards, write the summary, titles, and descriptions in {display_name}.
Write every first question in {target_name}.
When is_sufficient is false, write quality reason and retry_suggestion in {feedback_name} so the learner can recover.

Respond only in JSON:
{{
  "quality": {{
    "is_sufficient": true,
    "relevance": true,
    "freshness": true,
    "specificity": true,
    "reason": "brief reason",
    "retry_suggestion": null
  }},
  "summary": "3-5 short {display_name} sentences grounded in the search results.",
  "directions": [
    {{
      "direction": "CASUAL_CHAT",
      "title": "Casual conversation",
      "description": "Share opinions and personal reactions about the topic.",
      "first_questions": ["question 1", "question 2", "question 3"]
    }}
  ]
}}"""

    def _parse_json_response(self, response: str) -> dict:
        """LLM JSON 응답 파싱"""
        if "```json" in response:
            response = response.split("```json")[1].split("```")[0].strip()
        elif "```" in response:
            response = response.split("```")[1].split("```")[0].strip()
        return json.loads(response)

    def _provider_name(self, provider: object) -> str:
        """로그용 provider 이름 반환"""
        get_provider_name = getattr(provider, "get_provider_name", None)
        if callable(get_provider_name):
            return str(get_provider_name())
        return provider.__class__.__name__

    def _build_topic_prep_card_from_data(
        self,
        topic: str,
        sources: list[SearchResultItem],
        data: dict,
        language_context: LearningLanguageContext | None = None,
        display_language: LanguageCode | None = None,
    ) -> TopicPrepCard:
        """LLM 응답 dict를 TopicPrepCard로 변환"""
        language_context = ensure_language_context(language_context)
        display_language = display_language or resolve_topic_display_language(
            topic, language_context.native_language
        )
        quality_data = data.get("quality", {})
        raw_directions = data.get("directions", [])
        summary = str(data.get("summary") or "").strip()
        llm_is_sufficient = self._as_json_bool(quality_data.get("is_sufficient", False))
        has_complete_card = self._has_complete_topic_prep_payload(summary, raw_directions)
        is_sufficient = llm_is_sufficient and has_complete_card
        reason = quality_data.get("reason")
        retry_suggestion = quality_data.get("retry_suggestion")

        if llm_is_sufficient and not has_complete_card:
            reason = reason or INCOMPLETE_TOPIC_PREP_CARD_REASON
            retry_suggestion = retry_suggestion or self._build_retry_guidance(
                topic,
                language_context=language_context,
            )

        quality = TopicPrepQuality(
            is_sufficient=is_sufficient,
            source_count=len(sources),
            has_enough_sources=len(sources) >= MIN_TOPIC_PREP_SOURCE_COUNT,
            relevance=self._as_json_bool(quality_data.get("relevance", False)),
            freshness=self._as_json_bool(quality_data.get("freshness", False)),
            specificity=self._as_json_bool(quality_data.get("specificity", False)),
            reason=reason,
            retry_suggestion=retry_suggestion,
        )

        directions = self._normalize_topic_prep_directions(
            topic,
            raw_directions,
            language_context=language_context,
            display_language=display_language,
        )
        return TopicPrepCard(
            topic=topic,
            language=language_context,
            summary=summary,
            directions=directions,
            sources=sources,
            quality=quality,
            timestamp=datetime.utcnow(),
        )

    def _as_json_bool(self, value: object) -> bool:
        """JSON boolean만 true로 인정"""
        return value is True

    def _has_complete_topic_prep_payload(self, summary: str, raw_directions: object) -> bool:
        """ready=true 카드로 반환 가능한 최소 LLM payload 검증"""
        if not summary or not isinstance(raw_directions, list):
            return False
        return bool(summary) and self._has_complete_directions_payload(raw_directions)

    def _has_complete_directions_payload(self, raw_directions: object) -> bool:
        """방향 세 개가 enum과 질문 수 계약을 충족하는지 확인한다."""
        if not isinstance(raw_directions, list):
            return False
        if len(raw_directions) != len(ConversationDirection):
            return False

        expected_directions = {direction.value for direction in ConversationDirection}
        seen_directions = set()

        for item in raw_directions:
            if not isinstance(item, dict):
                return False

            direction = item.get("direction")
            if direction not in expected_directions or direction in seen_directions:
                return False
            seen_directions.add(direction)

            questions = item.get("first_questions")
            if not isinstance(questions, list) or len(questions) != 3:
                return False
            if any(not str(question).strip() for question in questions):
                return False

        return seen_directions == expected_directions

    def _normalize_topic_prep_directions(
        self,
        topic: str,
        raw_directions: list[dict],
        language_context: LearningLanguageContext | None = None,
        display_language: LanguageCode | None = None,
    ) -> list[TopicPrepDirection]:
        """대화 방향 3개를 고정 순서로 정규화"""
        by_direction = {
            item.get("direction"): item
            for item in raw_directions
            if isinstance(item, dict)
        }
        defaults = self._default_direction_metadata(topic, language_context=language_context)
        display_copy = self._direction_display_copy(
            display_language or ensure_language_context(language_context).native_language
        )
        normalized = []
        for direction in ConversationDirection:
            item = by_direction.get(direction.value, {})
            questions = [
                str(question).strip()
                for question in item.get("first_questions", [])
                if str(question).strip()
            ][:3]
            while len(questions) < 3:
                questions.append(defaults[direction]["fallback_questions"][len(questions)])

            normalized.append(
                TopicPrepDirection(
                    direction=direction,
                    title=item.get("title") or display_copy[direction]["title"],
                    description=item.get("description") or display_copy[direction]["description"],
                    first_questions=questions,
                )
            )
        return normalized

    def _default_direction_metadata(
        self,
        topic: str,
        language_context: LearningLanguageContext | None = None,
    ) -> dict[ConversationDirection, dict]:
        """대화 방향 기본 메타데이터"""
        language_context = ensure_language_context(language_context)
        if language_context.target_language == LanguageCode.KOREAN:
            return {
                ConversationDirection.CASUAL_CHAT: {
                    "title": "가볍게 대화하기",
                    "description": "주제에 대한 생각과 경험을 자연스럽게 말해요.",
                    "fallback_questions": [
                        f"{topic}에서 가장 먼저 눈에 들어온 점은 무엇인가요?",
                        f"{topic}에 대한 생각을 어떻게 말해보고 싶나요?",
                        f"{topic}에 대해 더 알고 싶은 점은 무엇인가요?",
                    ],
                },
                ConversationDirection.DEBATE: {
                    "title": "의견 말하기",
                    "description": "입장을 정하고 이유를 차분하게 설명해요.",
                    "fallback_questions": [
                        f"{topic}에 대해 어떤 입장을 말해보고 싶나요?",
                        f"그렇게 생각하는 가장 큰 이유는 무엇인가요?",
                        f"반대 의견을 가진 사람은 어떤 말을 할 수 있을까요?",
                    ],
                },
                ConversationDirection.EXPLANATION_PRACTICE: {
                    "title": "설명 연습",
                    "description": "주제를 이해하기 쉽게 정리해서 말해요.",
                    "fallback_questions": [
                        f"{topic}을 쉬운 한국어로 어떻게 요약할 수 있을까요?",
                        f"{topic}을 이해하려면 어떤 배경을 알아야 하나요?",
                        f"{topic}을 설명하기 좋은 예시는 무엇인가요?",
                    ],
                },
            }
        target_name = language_name(language_context.target_language)
        return {
            ConversationDirection.CASUAL_CHAT: {
                "title": "Casual conversation",
                "description": "Share opinions and personal reactions about the topic.",
                "fallback_questions": [
                    f"What part of {topic} caught your attention first?",
                    f"How would you explain your reaction to {topic}?",
                    f"What do you want to know more about {topic}?",
                ],
            },
            ConversationDirection.DEBATE: {
                "title": "Debate",
                "description": "Take a position and explain your reasons.",
                "fallback_questions": [
                    f"What position would you take on {topic}?",
                    f"What is the strongest reason for your opinion about {topic}?",
                    f"What might someone on the other side of {topic} say?",
                ],
            },
            ConversationDirection.EXPLANATION_PRACTICE: {
                "title": "Explanation practice",
                "description": "Practice explaining the topic clearly to someone else.",
                "fallback_questions": [
                    f"How would you summarize {topic} in simple {target_name}?",
                    f"What background does someone need to understand {topic}?",
                    f"What is one example that makes {topic} easier to explain?",
                ],
            },
        }

    def _direction_display_copy(self, display_language: LanguageCode) -> dict[ConversationDirection, dict[str, str]]:
        """방향 제목과 설명은 입력 주제 언어로 fallback한다."""
        if display_language == LanguageCode.KOREAN:
            return {
                ConversationDirection.CASUAL_CHAT: {"title": "가볍게 대화하기", "description": "주제에 대한 생각과 경험을 자연스럽게 말해요."},
                ConversationDirection.DEBATE: {"title": "의견 말하기", "description": "입장을 정하고 이유를 차분하게 설명해요."},
                ConversationDirection.EXPLANATION_PRACTICE: {"title": "설명 연습", "description": "주제를 이해하기 쉽게 정리해서 말해요."},
            }
        if display_language == LanguageCode.CHINESE:
            return {
                ConversationDirection.CASUAL_CHAT: {"title": "轻松聊天", "description": "自然分享你对这个话题的想法和经历。"},
                ConversationDirection.DEBATE: {"title": "表达观点", "description": "提出立场并平静说明理由。"},
                ConversationDirection.EXPLANATION_PRACTICE: {"title": "说明练习", "description": "练习清楚地向别人解释这个话题。"},
            }
        return {
            ConversationDirection.CASUAL_CHAT: {"title": "Casual conversation", "description": "Share opinions and personal reactions about the topic."},
            ConversationDirection.DEBATE: {"title": "Debate", "description": "Take a position and explain your reasons."},
            ConversationDirection.EXPLANATION_PRACTICE: {"title": "Explanation practice", "description": "Practice explaining the topic clearly to someone else."},
        }

    @staticmethod
    def _format_topic_prep_sources(sources: list[SearchResultItem]) -> str:
        return "\n".join(
            f"- Title: {source.title}\n  Snippet: {source.snippet}\n  URL: {source.url}"
            for source in sources
        )

    @staticmethod
    def _custom_focus_retry_guidance(display_language: LanguageCode) -> str:
        if display_language == LanguageCode.KOREAN:
            return "이 주제 안에서 이야기하고 싶은 방향을 다시 입력해 주세요."
        if display_language == LanguageCode.CHINESE:
            return "请围绕这个主题重新输入想讨论的方向。"
        return "Please enter a focus that stays within this topic."

    def _build_low_quality_result(
        self,
        topic: str,
        sources: list[SearchResultItem],
        reason: str,
        retry_suggestion: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> TopicPrepResult:
        """검색 품질 부족 결과 생성"""
        language_context = ensure_language_context(language_context)
        quality = TopicPrepQuality(
            is_sufficient=False,
            source_count=len(sources),
            has_enough_sources=len(sources) >= MIN_TOPIC_PREP_SOURCE_COUNT,
            relevance=False,
            freshness=False,
            specificity=False,
            reason=reason,
            retry_suggestion=retry_suggestion,
        )
        return self._build_not_ready_topic_prep_result(
            topic,
            quality,
            language_context=language_context,
        )

    def _build_not_ready_topic_prep_result(
        self,
        topic: str,
        quality: TopicPrepQuality,
        *,
        language_context: LearningLanguageContext | None = None,
        use_quality_retry_suggestion: bool = True,
    ) -> TopicPrepResult:
        """Topic Prep not-ready 응답의 retry/example 정합성을 맞춘다."""
        language_context = ensure_language_context(language_context)
        example_topics = self._build_example_topics(
            topic,
            language_context=language_context,
        )
        retry_guidance = (
            quality.retry_suggestion if use_quality_retry_suggestion else None
        ) or self._build_retry_guidance(
            topic,
            language_context=language_context,
            example_topics=example_topics,
        )
        final_quality = quality.model_copy(
            update={"retry_suggestion": retry_guidance},
        )
        return TopicPrepResult(
            ready=False,
            language=language_context,
            quality=final_quality,
            retry_guidance=retry_guidance,
            example_topics=example_topics,
        )

    def _build_retry_guidance(
        self,
        topic: str,
        language_context: LearningLanguageContext | None = None,
        example_topics: list[str] | None = None,
    ) -> str:
        """주제 재입력 안내 생성"""
        language_context = ensure_language_context(language_context)
        examples = ", ".join(
            example_topics
            or self._build_example_topics(topic, language_context=language_context)
        )
        if language_context.feedback_language == LanguageCode.ENGLISH:
            return (
                "I could not find search results specific enough to prepare a conversation. "
                f"Try again with a concrete event, date, team, person, or place. Examples: {examples}"
            )
        if language_context.feedback_language == LanguageCode.CHINESE:
            return (
                "没有找到足够具体的搜索结果来准备对话。"
                f"请加入具体事件、日期、团队、人物或地点后再试。例：{examples}"
            )
        return (
            "이 주제에 대해 대화 준비를 만들 만큼 구체적인 검색 결과를 찾지 못했어요. "
            f"더 구체적인 사건, 날짜, 팀, 인물, 장소를 넣어 다시 입력해보세요. 예: {examples}"
        )

    def _build_example_topics(
        self,
        topic: str,
        language_context: LearningLanguageContext | None = None,
    ) -> list[str]:
        """주제 재입력 예시"""
        language_context = ensure_language_context(language_context)
        trimmed_topic = topic.strip()
        if not trimmed_topic:
            trimmed_topic = self._default_example_topic(language_context)
        current_date, _timezone = current_search_context()
        year, month, *_ = current_date.split("-")
        if language_context.target_language == LanguageCode.KOREAN:
            return self._build_korean_practice_example_topics(
                trimmed_topic,
                year,
                month,
                language_context=language_context,
            )
        if language_context.feedback_language == LanguageCode.ENGLISH:
            return [
                f"{trimmed_topic} latest issue in {year}-{month}",
                f"specific event and outcome about {trimmed_topic}",
                f"pros and cons debate about {trimmed_topic}",
            ]
        if language_context.feedback_language == LanguageCode.CHINESE:
            return [
                f"{year}年{int(month)}月 {trimmed_topic} 最新议题",
                f"{trimmed_topic} 的具体事件和结果",
                f"关于 {trimmed_topic} 的正反争议",
            ]
        return [
            f"{year}년 {int(month)}월 {trimmed_topic} 관련 최신 이슈",
            f"{trimmed_topic}의 구체적인 사건과 결과",
            f"{trimmed_topic}에 대한 찬반 쟁점",
        ]

    def _default_example_topic(self, language_context: LearningLanguageContext) -> str:
        """feedback 언어에 맞는 빈 주제 기본값"""
        if language_context.feedback_language == LanguageCode.ENGLISH:
            return "recent news"
        if language_context.feedback_language == LanguageCode.CHINESE:
            return "最近新闻"
        return "최근 뉴스"

    def _build_korean_practice_example_topics(
        self,
        topic: str,
        year: str,
        month: str,
        *,
        language_context: LearningLanguageContext,
    ) -> list[str]:
        """한국어 연습에 맞는 low-quality 재입력 예시"""
        if language_context.feedback_language == LanguageCode.ENGLISH:
            return [
                f"{topic} polite Korean service situation in {year}-{month}",
                f"specific Korean self-introduction or workplace greeting about {topic}",
                f"Korean opinion conversation with concrete people or places about {topic}",
            ]
        if language_context.feedback_language == LanguageCode.CHINESE:
            return [
                f"{year}年{int(month)}月 {topic} 的韩语礼貌服务场景",
                f"围绕 {topic} 的具体韩语自我介绍或职场问候",
                f"关于 {topic} 的韩语观点对话，加入具体人物或地点",
            ]
        return [
            f"{year}년 {int(month)}월 {topic} 관련 한국어 존댓말 상황",
            f"{topic}에 대한 구체적인 자기소개나 직장 인사 상황",
            f"{topic}을 두고 인물이나 장소가 분명한 한국어 의견 대화",
        ]

    def _resolve_search_region(self, language_context: LearningLanguageContext) -> str:
        """언어 컨텍스트 기반 검색 region hint"""
        if language_context.native_language == LanguageCode.CHINESE:
            return "cn-zh"
        if language_context.target_language == LanguageCode.ENGLISH:
            return "us-en"
        if language_context.target_language == LanguageCode.KOREAN:
            return "kr-kr"
        return self.settings.search_region

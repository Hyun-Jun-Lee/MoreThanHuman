"""
Search Service Layer
"""
import asyncio
import json
import logging
from datetime import datetime

from duckduckgo_search import DDGS

from config import get_model_for_provider, get_settings
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest
from domains.search.schemas import (
    ConversationDirection,
    SearchResult,
    SearchResultItem,
    TopicPrepCard,
    TopicPrepDirection,
    TopicPrepQuality,
    TopicPrepResult,
)
from shared.exceptions import ExternalAPIException

logger = logging.getLogger(__name__)

settings = get_settings()

MIN_TOPIC_PREP_SOURCE_COUNT = 3


class SearchService:
    """검색 서비스"""

    async def search(self, query: str) -> SearchResult:
        """
        DuckDuckGo 검색 후 LLM 요약

        Args:
            query: 검색 쿼리

        Returns:
            요약된 검색 결과
        """
        raw_results = await self._search_duckduckgo(query)

        sources = [
            SearchResultItem(
                title=r.get("title", ""),
                url=r.get("href", ""),
                snippet=r.get("body", "")[:300],
            )
            for r in raw_results
        ]

        summary = await self._summarize_results(query, sources)

        return SearchResult(
            query=query,
            summary=summary,
            sources=sources,
            timestamp=datetime.utcnow(),
        )

    async def prepare_topic(self, topic: str) -> TopicPrepResult:
        """
        검색 기반 대화 전 주제 준비 카드 생성

        Args:
            topic: 사용자가 대화하고 싶은 관심 주제

        Returns:
            준비 카드 생성 결과
        """
        raw_results = await self._search_duckduckgo(topic)
        sources = [
            SearchResultItem(
                title=r.get("title", ""),
                url=r.get("href", ""),
                snippet=r.get("body", "")[:300],
            )
            for r in raw_results
        ]

        if len(sources) < MIN_TOPIC_PREP_SOURCE_COUNT:
            return self._build_low_quality_result(
                topic,
                sources,
                reason="대화 준비에 사용할 검색 출처가 충분하지 않아요.",
            )

        card = await self._generate_topic_prep_card(topic, sources)
        if not card.quality.is_sufficient:
            return TopicPrepResult(
                ready=False,
                card=None,
                quality=card.quality,
                retry_guidance=card.quality.retry_suggestion or self._build_retry_guidance(topic),
                example_topics=self._build_example_topics(topic),
            )

        return TopicPrepResult(
            ready=True,
            card=card,
            quality=card.quality,
        )

    async def _search_duckduckgo(self, query: str) -> list[dict]:
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
            return await asyncio.to_thread(self._sync_search, query)
        except ExternalAPIException:
            raise
        except Exception as e:
            raise ExternalAPIException(f"DuckDuckGo search failed: {str(e)}")

    def _sync_search(self, query: str) -> list[dict]:
        """DuckDuckGo 동기 검색"""
        ddgs = DDGS()
        results = ddgs.text(query, max_results=5)
        return results

    async def _summarize_results(self, query: str, sources: list[SearchResultItem]) -> str:
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

        source_text = "\n".join(
            f"- {s.title}: {s.snippet}" for s in sources
        )

        try:
            provider = LLMProviderFactory.create_provider()
            request = LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=(
                            "Summarize the following search results into a concise paragraph. "
                            "Focus on key facts and information relevant to the query. "
                            "Write in English only. Keep it under 150 words."
                        ),
                    ),
                    LLMMessage(
                        role="user",
                        content=f"Query: {query}\n\nSearch Results:\n{source_text}",
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=settings.search_summary_max_tokens,
                temperature=0.3,
            )

            response = await provider.chat_completion(request)
            return response.content
        except Exception as e:
            logger.warning(f"LLM summarization failed, using fallback: {e}")
            return "\n".join(f"- {s.title}: {s.snippet}" for s in sources)

    async def _generate_topic_prep_card(self, topic: str, sources: list[SearchResultItem]) -> TopicPrepCard:
        """LLM으로 검색 품질 판정과 준비 카드 내용을 생성"""
        source_text = "\n".join(
            f"- Title: {source.title}\n  Snippet: {source.snippet}\n  URL: {source.url}"
            for source in sources
        )

        try:
            provider = LLMProviderFactory.create_provider()
            request = LLMRequest(
                messages=[
                    LLMMessage(
                        role="system",
                        content=self._build_topic_prep_system_prompt(),
                    ),
                    LLMMessage(
                        role="user",
                        content=f"Topic: {topic}\n\nSearch Results:\n{source_text}",
                    ),
                ],
                model=get_model_for_provider(),
                max_tokens=min(settings.max_tokens, 1600),
                temperature=0.2,
            )
            response = await provider.chat_completion(request)
            data = self._parse_json_response(response.content)
            return self._build_topic_prep_card_from_data(topic, sources, data)
        except ExternalAPIException:
            raise
        except Exception as e:
            logger.error(f"Topic prep generation failed: {e}", exc_info=True)
            raise ExternalAPIException(f"Topic prep generation failed: {str(e)}")

    def _build_topic_prep_system_prompt(self) -> str:
        """주제 준비 카드 생성 프롬프트"""
        directions = ", ".join(direction.value for direction in ConversationDirection)
        return f"""You create pre-conversation topic prep cards for English learners.

Evaluate whether the search results are good enough to start a concrete English conversation.
Judge quality using:
1. source_count: enough independent sources
2. relevance: directly related to the user's topic
3. freshness: clear recent/current context when the topic asks for recent/current news
4. specificity: concrete people, events, results, or issues rather than generic background

If the quality is insufficient, set is_sufficient to false and explain how to make the topic more specific.
If sufficient, create a short English summary and exactly four conversation directions.
Each direction must use one of these direction values: {directions}.
Each direction must include exactly three first questions.
Questions must be specific to the search summary and must not be generic questions like "Do you like baseball?"

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
  "summary": "3-5 short English sentences grounded in the search results.",
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

    def _build_topic_prep_card_from_data(
        self,
        topic: str,
        sources: list[SearchResultItem],
        data: dict,
    ) -> TopicPrepCard:
        """LLM 응답 dict를 TopicPrepCard로 변환"""
        quality_data = data.get("quality", {})
        quality = TopicPrepQuality(
            is_sufficient=bool(quality_data.get("is_sufficient", False)),
            source_count=len(sources),
            has_enough_sources=len(sources) >= MIN_TOPIC_PREP_SOURCE_COUNT,
            relevance=bool(quality_data.get("relevance", False)),
            freshness=bool(quality_data.get("freshness", False)),
            specificity=bool(quality_data.get("specificity", False)),
            reason=quality_data.get("reason"),
            retry_suggestion=quality_data.get("retry_suggestion"),
        )

        directions = self._normalize_topic_prep_directions(topic, data.get("directions", []))
        return TopicPrepCard(
            topic=topic,
            summary=data.get("summary", ""),
            directions=directions,
            sources=sources,
            quality=quality,
            timestamp=datetime.utcnow(),
        )

    def _normalize_topic_prep_directions(
        self,
        topic: str,
        raw_directions: list[dict],
    ) -> list[TopicPrepDirection]:
        """대화 방향 4개를 고정 순서로 정규화"""
        by_direction = {
            item.get("direction"): item
            for item in raw_directions
            if isinstance(item, dict)
        }
        defaults = self._default_direction_metadata(topic)
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
                    title=item.get("title") or defaults[direction]["title"],
                    description=item.get("description") or defaults[direction]["description"],
                    first_questions=questions,
                )
            )
        return normalized

    def _default_direction_metadata(self, topic: str) -> dict[ConversationDirection, dict]:
        """대화 방향 기본 메타데이터"""
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
            ConversationDirection.INTERVIEW_QA: {
                "title": "Interview / Q&A",
                "description": "Answer focused questions as if you are being interviewed.",
                "fallback_questions": [
                    f"What is the most important fact people should know about {topic}?",
                    f"Why does {topic} matter right now?",
                    f"What question would you ask an expert about {topic}?",
                ],
            },
            ConversationDirection.EXPLANATION_PRACTICE: {
                "title": "Explanation practice",
                "description": "Practice explaining the topic clearly to someone else.",
                "fallback_questions": [
                    f"How would you summarize {topic} in simple English?",
                    f"What background does someone need to understand {topic}?",
                    f"What is one example that makes {topic} easier to explain?",
                ],
            },
        }

    def _build_low_quality_result(
        self,
        topic: str,
        sources: list[SearchResultItem],
        reason: str,
    ) -> TopicPrepResult:
        """검색 품질 부족 결과 생성"""
        quality = TopicPrepQuality(
            is_sufficient=False,
            source_count=len(sources),
            has_enough_sources=False,
            relevance=False,
            freshness=False,
            specificity=False,
            reason=reason,
            retry_suggestion=self._build_retry_guidance(topic),
        )
        return TopicPrepResult(
            ready=False,
            quality=quality,
            retry_guidance=quality.retry_suggestion,
            example_topics=self._build_example_topics(topic),
        )

    def _build_retry_guidance(self, topic: str) -> str:
        """주제 재입력 안내 생성"""
        examples = ", ".join(self._build_example_topics(topic))
        return (
            "이 주제에 대해 대화 준비를 만들 만큼 구체적인 검색 결과를 찾지 못했어요. "
            f"더 구체적인 사건, 날짜, 팀, 인물, 장소를 넣어 다시 입력해보세요. 예: {examples}"
        )

    def _build_example_topics(self, topic: str) -> list[str]:
        """주제 재입력 예시"""
        trimmed_topic = topic.strip()
        if not trimmed_topic:
            trimmed_topic = "최근 뉴스"
        return [
            f"2026년 5월 {trimmed_topic} 관련 최신 이슈",
            f"{trimmed_topic}의 구체적인 사건과 결과",
            f"{trimmed_topic}에 대한 찬반 쟁점",
        ]

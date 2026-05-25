"""
Search Service Layer
"""
import asyncio
import logging
from datetime import datetime

from duckduckgo_search import DDGS

from config import get_model_for_provider, get_settings
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest
from domains.search.schemas import SearchResult, SearchResultItem
from shared.exceptions import ExternalAPIException

logger = logging.getLogger(__name__)

settings = get_settings()


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

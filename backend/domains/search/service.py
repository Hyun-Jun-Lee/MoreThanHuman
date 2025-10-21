"""
Search Service Layer
"""
from datetime import datetime

import httpx

from config import get_settings
from domains.search.models import SearchResult, SearchResultItem, TavilyResponse
from shared.exceptions import ExternalAPIException

settings = get_settings()


class SearchService:
    """검색 서비스"""

    async def search(self, query: str) -> SearchResult:
        """
        검색 실행

        Args:
            query: 검색 쿼리

        Returns:
            검색 결과
        """
        # Tavily API 호출
        tavily_response = await self.call_tavily_api(query)

        # 결과 포맷팅
        return self.format_search_results(tavily_response)

    async def call_tavily_api(self, query: str) -> TavilyResponse:
        """
        Tavily API 호출

        Args:
            query: 검색 쿼리

        Returns:
            Tavily 응답

        Raises:
            ExternalAPIException: API 호출 실패
        """
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    "https://api.tavily.com/search",
                    headers={"Content-Type": "application/json"},
                    json={
                        "api_key": settings.tavily_api_key,
                        "query": query,
                        "search_depth": "basic",
                        "max_results": 5,
                    },
                    timeout=15.0,
                )
                response.raise_for_status()
                data = response.json()

                return TavilyResponse(query=query, results=data.get("results", []))
            except httpx.HTTPError as e:
                raise ExternalAPIException(f"Tavily API call failed: {str(e)}")

    def build_search_query(self, topic: str) -> str:
        """
        검색 쿼리 생성

        Args:
            topic: 주제

        Returns:
            검색 쿼리
        """
        return f"{topic} latest news"

    def format_search_results(self, tavily_response: TavilyResponse) -> SearchResult:
        """
        검색 결과 포맷팅

        Args:
            tavily_response: Tavily 응답

        Returns:
            포맷팅된 검색 결과
        """
        results = []
        for item in tavily_response.results:
            # published_date 파싱
            published_date = None
            if item.published_date:
                try:
                    published_date = datetime.fromisoformat(item.published_date.replace("Z", "+00:00"))
                except ValueError:
                    pass

            results.append(
                SearchResultItem(
                    title=item.title,
                    url=item.url,
                    snippet=item.content[:200] if item.content else "",
                    published_date=published_date,
                    score=item.score,
                )
            )

        return SearchResult(query=tavily_response.query, results=results, timestamp=datetime.utcnow())

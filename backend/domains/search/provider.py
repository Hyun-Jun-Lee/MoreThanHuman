"""
Search provider adapter
"""
from typing import Any

from shared.exceptions import ExternalAPIException


def _load_ddgs_class():
    """ddgs 패키지의 DDGS 클래스를 지연 로드"""
    try:
        from ddgs import DDGS
    except ImportError as exc:
        raise ExternalAPIException(
            "ddgs package is not installed. Install backend dependencies before using search."
        ) from exc
    return DDGS


class DuckDuckGoSearchProvider:
    """ddgs 검색 호출을 캡슐화하는 adapter"""

    def __init__(self, settings: Any):
        self.settings = settings

    def text(self, query: str, *, use_recency_timelimit: bool) -> list[dict]:
        """ddgs text 검색 결과를 서비스 내부 shape로 정규화"""
        ddgs_class = _load_ddgs_class()
        options: dict[str, Any] = {
            "region": self.settings.search_region,
            "safesearch": self.settings.search_safesearch,
            "backend": self.settings.search_backend,
            "max_results": self.settings.search_max_results,
        }
        if use_recency_timelimit:
            options["timelimit"] = self.settings.search_recent_timelimit

        try:
            ddgs = ddgs_class()
            if hasattr(ddgs, "__enter__"):
                with ddgs as search_client:
                    results = search_client.text(query, **options)
            else:
                results = ddgs.text(query, **options)
        except ExternalAPIException:
            raise
        except Exception as exc:
            raise ExternalAPIException(f"DuckDuckGo search failed: {str(exc)}") from exc

        return [self._normalize_result(result) for result in (results or [])]

    def _normalize_result(self, result: dict) -> dict:
        """ddgs 결과를 title/href/body dict로 정규화"""
        return {
            "title": str(result.get("title") or "").strip(),
            "href": str(result.get("href") or result.get("url") or "").strip(),
            "body": str(result.get("body") or result.get("snippet") or "").strip(),
        }

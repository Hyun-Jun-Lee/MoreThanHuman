"""
Search 도메인 모델 정의
"""
from datetime import datetime

from pydantic import BaseModel


class SearchResultItem(BaseModel):
    """검색 결과 항목"""

    title: str
    url: str
    snippet: str
    published_date: datetime | None = None
    score: float


class SearchResult(BaseModel):
    """검색 결과"""

    query: str
    results: list[SearchResultItem]
    timestamp: datetime


class TavilyResult(BaseModel):
    """Tavily 검색 결과"""

    title: str
    url: str
    content: str
    score: float
    published_date: str | None = None


class TavilyResponse(BaseModel):
    """Tavily API 응답"""

    query: str
    results: list[TavilyResult]

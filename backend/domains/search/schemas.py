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


class SearchResult(BaseModel):
    """검색 결과"""

    query: str
    summary: str
    sources: list[SearchResultItem]
    timestamp: datetime

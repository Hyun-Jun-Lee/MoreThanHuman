"""
Search 도메인 모델 정의
"""
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field

from shared.language import LearningLanguageContext


class SearchResultItem(BaseModel):
    """검색 결과 항목"""

    title: str
    url: str
    snippet: str


class SearchQuality(BaseModel):
    """검색 품질 판정"""

    is_sufficient: bool
    source_count: int
    relevant_source_count: int
    dropped_source_count: int
    relevance: bool
    freshness: bool
    specificity: bool
    reason: str | None = None
    retry_suggestion: str | None = None


class RejectedSearchSource(BaseModel):
    """LLM이 탈락시킨 검색 출처"""

    id: int
    reason: str


class SearchQualityJudgeResult(BaseModel):
    """LLM source judge 응답"""

    is_sufficient: bool
    accepted_source_ids: list[int] = Field(default_factory=list)
    rejected_sources: list[RejectedSearchSource] = Field(default_factory=list)
    relevance: bool
    freshness: bool
    specificity: bool
    reason: str | None = None
    retry_suggestion: str | None = None


class SearchResult(BaseModel):
    """검색 결과"""

    query: str
    enhanced_query: str
    language: LearningLanguageContext = Field(default_factory=LearningLanguageContext)
    ready: bool
    summary: str | None = None
    sources: list[SearchResultItem]
    quality: SearchQuality
    retry_guidance: str | None = None
    example_queries: list[str] = Field(default_factory=list)
    timestamp: datetime


class ConversationDirection(str, Enum):
    """주제 준비 카드 대화 방향"""

    CASUAL_CHAT = "CASUAL_CHAT"
    DEBATE = "DEBATE"
    INTERVIEW_QA = "INTERVIEW_QA"
    EXPLANATION_PRACTICE = "EXPLANATION_PRACTICE"


class TopicPrepRequest(BaseModel):
    """주제 준비 카드 생성 요청"""

    topic: str = Field(..., min_length=2, max_length=200)


class TopicPrepQuality(BaseModel):
    """검색 품질 판정"""

    is_sufficient: bool
    source_count: int
    has_enough_sources: bool
    relevance: bool
    freshness: bool
    specificity: bool
    reason: str | None = None
    retry_suggestion: str | None = None


class TopicPrepDirection(BaseModel):
    """대화 방향별 첫 질문"""

    direction: ConversationDirection
    title: str
    description: str
    first_questions: list[str] = Field(..., min_length=3, max_length=3)


class TopicPrepCard(BaseModel):
    """대화 전 주제 준비 카드"""

    topic: str
    language: LearningLanguageContext = Field(default_factory=LearningLanguageContext)
    summary: str
    directions: list[TopicPrepDirection] = Field(..., min_length=4, max_length=4)
    sources: list[SearchResultItem]
    quality: TopicPrepQuality
    timestamp: datetime


class TopicPrepResult(BaseModel):
    """주제 준비 카드 생성 결과"""

    ready: bool
    language: LearningLanguageContext = Field(default_factory=LearningLanguageContext)
    card: TopicPrepCard | None = None
    quality: TopicPrepQuality
    retry_guidance: str | None = None
    example_topics: list[str] = Field(default_factory=list)

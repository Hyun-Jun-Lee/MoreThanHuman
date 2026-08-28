"""
Search 도메인 모델 정의
"""
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field

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


class SearchQueryAnalysisResult(BaseModel):
    """LLM 검색어 분석 응답"""

    model_config = ConfigDict(extra="forbid")

    canonical_topic: str
    required_phrases: list[str]
    required_tokens: list[str]
    context_terms: list[str]
    recency_intent: bool
    exclude_terms: list[str]


class RejectedSearchSource(BaseModel):
    """LLM이 탈락시킨 검색 출처"""

    model_config = ConfigDict(extra="forbid")

    id: int
    reason: str


class SearchQualityJudgeResult(BaseModel):
    """LLM source judge 응답"""

    model_config = ConfigDict(extra="forbid")

    is_sufficient: bool
    accepted_source_ids: list[int]
    rejected_sources: list[RejectedSearchSource]
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
    EXPLANATION_PRACTICE = "EXPLANATION_PRACTICE"


class TopicPrepRequest(BaseModel):
    """주제 준비 카드 생성 요청"""

    topic: str = Field(..., min_length=2, max_length=200)


class CustomFocusQuestionsRequest(TopicPrepRequest):
    """직접 입력한 대화 방향의 첫 질문 생성 요청"""

    custom_focus: str = Field(..., min_length=2, max_length=200)


class TopicPrepDirectionsRequest(TopicPrepRequest):
    """같은 주제의 새로운 추천 방향 생성 요청"""

    previous_directions: list[str] = Field(default_factory=list, max_length=3)


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
    directions: list[TopicPrepDirection] = Field(..., min_length=3, max_length=3)
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


class CustomFocusQuestionsResult(BaseModel):
    """직접 입력 방향에 맞춘 첫 질문 결과"""

    ready: bool
    custom_focus: str
    first_questions: list[str] = Field(default_factory=list, max_length=3)
    retry_guidance: str | None = None


class TopicPrepDirectionsResult(BaseModel):
    """재생성한 추천 방향 결과"""

    directions: list[TopicPrepDirection] = Field(..., min_length=3, max_length=3)

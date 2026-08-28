"""
Search API Router
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from domains.auth.dependencies import get_current_user
from domains.auth.models import ProfileModel
from domains.search.schemas import (
    CustomFocusQuestionsRequest,
    CustomFocusQuestionsResult,
    SearchResult,
    TopicPrepDirectionsRequest,
    TopicPrepDirectionsResult,
    TopicPrepRequest,
    TopicPrepResult,
)
from domains.search.service import SearchService
from shared.exceptions import AppException
from shared.language import ensure_language_context
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/search", tags=["search"])


# Request Models
class SearchRequest(BaseModel):
    """검색 요청"""

    query: str = Field(..., min_length=2, max_length=200)


# Dependency
def get_search_service() -> SearchService:
    """SearchService 의존성"""
    return SearchService()


# Endpoints
@router.post("/", response_model=SuccessResponse[SearchResult])
async def search(
    request: SearchRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: SearchService = Depends(get_search_service),
):
    """검색 실행"""
    try:
        result = await service.search(
            request.query,
            language_context=ensure_language_context(getattr(current_user, "language", None)),
        )
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)


@router.post("/topic-prep/", response_model=SuccessResponse[TopicPrepResult])
async def prepare_topic(
    request: TopicPrepRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: SearchService = Depends(get_search_service),
):
    """대화 전 주제 준비 카드 생성"""
    try:
        result = await service.prepare_topic(
            request.topic,
            language_context=ensure_language_context(getattr(current_user, "language", None)),
        )
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)


@router.post("/topic-prep/custom-questions/", response_model=SuccessResponse[CustomFocusQuestionsResult])
async def prepare_custom_focus_questions(
    request: CustomFocusQuestionsRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: SearchService = Depends(get_search_service),
):
    """직접 입력한 대화 방향의 첫 질문 생성"""
    try:
        result = await service.prepare_custom_focus_questions(
            request.topic,
            request.custom_focus,
            language_context=ensure_language_context(getattr(current_user, "language", None)),
        )
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)


@router.post("/topic-prep/directions/", response_model=SuccessResponse[TopicPrepDirectionsResult])
async def regenerate_topic_prep_directions(
    request: TopicPrepDirectionsRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: SearchService = Depends(get_search_service),
):
    """현재 주제의 새로운 추천 대화 방향 생성"""
    try:
        result = await service.regenerate_topic_prep_directions(
            request.topic,
            request.previous_directions,
            language_context=ensure_language_context(getattr(current_user, "language", None)),
        )
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)

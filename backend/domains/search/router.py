"""
Search API Router
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from domains.auth.dependencies import get_current_user
from domains.auth.models import UserModel
from domains.search.schemas import SearchResult, TopicPrepRequest, TopicPrepResult
from domains.search.service import SearchService
from shared.exceptions import AppException
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/search", tags=["search"])


# Request Models
class SearchRequest(BaseModel):
    """검색 요청"""

    query: str


# Dependency
def get_search_service() -> SearchService:
    """SearchService 의존성"""
    return SearchService()


# Endpoints
@router.post("/", response_model=SuccessResponse[SearchResult])
async def search(
    request: SearchRequest,
    current_user: UserModel = Depends(get_current_user),
    service: SearchService = Depends(get_search_service),
):
    """검색 실행"""
    try:
        result = await service.search(request.query)
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)


@router.post("/topic-prep/", response_model=SuccessResponse[TopicPrepResult])
async def prepare_topic(
    request: TopicPrepRequest,
    current_user: UserModel = Depends(get_current_user),
    service: SearchService = Depends(get_search_service),
):
    """대화 전 주제 준비 카드 생성"""
    try:
        result = await service.prepare_topic(request.topic)
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)

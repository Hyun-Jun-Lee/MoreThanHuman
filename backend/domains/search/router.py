"""
Search API Router
"""
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from domains.search.schemas import SearchResult
from domains.search.service import SearchService
from shared.exceptions import AppException
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/search", tags=["search"])


# Request Models
class SearchRequest(BaseModel):
    """검색 요청"""

    query: str


# Endpoints
@router.post("/", response_model=SuccessResponse[SearchResult])
async def search(request: SearchRequest):
    """
    검색 실행

    Args:
        request: 검색 요청

    Returns:
        검색 결과
    """
    try:
        service = SearchService()
        result = await service.search(request.query)
        return SuccessResponse(data=result)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)

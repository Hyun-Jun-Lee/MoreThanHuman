"""
Search API Router
"""
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from backend.domains.search.models import SearchResult
from backend.domains.search.service import SearchService
from backend.shared.exceptions import AppException
from backend.shared.types import SuccessResponse

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

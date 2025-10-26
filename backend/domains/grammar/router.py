"""
Grammar API Router
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from domains.grammar.repository import GrammarRepository
from domains.grammar.schemas import GrammarFeedback, GrammarStats
from domains.grammar.service import GrammarService
from shared.exceptions import AppException, NotFoundException, RateLimitException
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/grammar", tags=["grammar"])


# Request Models
class CheckGrammarRequest(BaseModel):
    """문법 체크 요청"""

    text: str


# Dependency
def get_grammar_service(db: Session = Depends(get_db)) -> GrammarService:
    """Grammar Service 의존성"""
    repository = GrammarRepository(db)
    return GrammarService(repository)


# Endpoints
@router.post("/check/", response_model=SuccessResponse[GrammarFeedback])
async def check_grammar(
    request: CheckGrammarRequest,
    service: GrammarService = Depends(get_grammar_service),
):
    """
    문법 체크

    Args:
        request: 체크 요청
        service: Grammar Service

    Returns:
        문법 피드백
    """
    try:
        feedback = await service.check_grammar(request.text)
        return SuccessResponse(data=feedback)
    except RateLimitException as e:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/message/{message_id}/", response_model=SuccessResponse[GrammarFeedback])
def get_feedback_by_message(
    message_id: str,
    service: GrammarService = Depends(get_grammar_service),
):
    """
    메시지의 문법 피드백 조회

    Args:
        message_id: 메시지 ID
        service: Grammar Service

    Returns:
        문법 피드백
    """
    try:
        feedback = service.get_feedback(message_id)
        return SuccessResponse(data=feedback)
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/stats/", response_model=SuccessResponse[GrammarStats])
def get_stats(
    time_range: str | None = None,
    service: GrammarService = Depends(get_grammar_service),
):
    """
    문법 통계 조회

    Args:
        time_range: 시간 범위 ("7d", "30d", "90d", "all")
        service: Grammar Service

    Returns:
        문법 통계
    """
    try:
        stats = service.get_stats(time_range)
        return SuccessResponse(data=stats)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)

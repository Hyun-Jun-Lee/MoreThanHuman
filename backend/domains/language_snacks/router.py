"""Language snack API router."""
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database import get_db
from domains.auth.dependencies import get_current_user
from domains.auth.models import ProfileModel
from domains.language_snacks.dependencies import (
    get_language_snack_service,
    require_language_snack_operations_key,
)
from domains.language_snacks.schemas import LanguageSnack, LanguageSnackCreate
from domains.language_snacks.service import LanguageSnackService
from shared.types import SuccessResponse


router = APIRouter(prefix="/api/language-snacks", tags=["language snacks"])


@router.get("/", response_model=SuccessResponse[list[LanguageSnack]])
def list_language_snacks(
    _current_user: ProfileModel = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SuccessResponse[list[LanguageSnack]]:
    """인증된 학습자에게 공통 발행 스낵 목록을 반환한다."""
    service = get_language_snack_service(db)
    return SuccessResponse(data=service.list_published())


@router.post(
    "/",
    response_model=SuccessResponse[LanguageSnack],
    status_code=status.HTTP_201_CREATED,
)
def create_language_snack(
    request: LanguageSnackCreate,
    _operations_key: None = Depends(require_language_snack_operations_key),
    db: Session = Depends(get_db),
) -> SuccessResponse[LanguageSnack]:
    """운영 키가 확인된 경우 즉시 발행 스낵을 생성한다."""
    service = get_language_snack_service(db)
    return SuccessResponse(data=service.create(request))

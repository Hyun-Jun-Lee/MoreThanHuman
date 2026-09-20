"""인증된 언어별 조회와 운영 전용 스낵 관리."""

from typing import Annotated, Literal
from uuid import UUID

import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy.orm import Session

from database import get_db
from domains.auth.dependencies import get_current_user
from domains.auth.models import ProfileModel
from domains.language_snacks.basket_reset import (
    BasketResetRepository,
    BasketResetRequest,
    BasketResetState,
)
from domains.language_snacks.dependencies import (
    get_language_snack_service,
    require_language_snack_operations_key,
)
from domains.language_snacks.generation_service import SnackGenerator
from domains.language_snacks.lock import SnackError
from domains.language_snacks.schemas import (
    ArchiveRequest,
    LanguageSnack,
    LanguageSnackCreate,
)
from shared.http_clients import get_ai_http_client
from shared.types import SuccessResponse

router = APIRouter(tags=["language snacks"])


def get_snack_generator(
    db: Annotated[Session, Depends(get_db)],
    http_client: Annotated[httpx.AsyncClient, Depends(get_ai_http_client)],
):
    return SnackGenerator(
        get_language_snack_service(db).repository, http_client=http_client
    )


@router.get("/api/language-snacks/", response_model=SuccessResponse[list])
def legacy_list(_user: Annotated[ProfileModel, Depends(get_current_user)]):
    return SuccessResponse(data=[])


@router.post(
    "/api/language-snacks/",
    dependencies=[Depends(require_language_snack_operations_key)],
)
def legacy_create():
    raise HTTPException(410, "Use /api/v2/language-snacks/.")


@router.get(
    "/api/v2/language-snacks/", response_model=SuccessResponse[list[LanguageSnack]]
)
def list_language_snacks(
    user: Annotated[ProfileModel, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
    limit: int = Query(12, ge=1, le=30),
    order: Literal["latest", "random"] = Query("latest"),
):
    return SuccessResponse(
        data=get_language_snack_service(db).repository.list_published(
            user.target_language, limit, order=order
        )
    )


@router.post(
    "/api/v2/language-snacks/basket-reset/",
    response_model=SuccessResponse[BasketResetState],
    dependencies=[Depends(require_language_snack_operations_key)],
)
def reset_snack_basket(
    request: BasketResetRequest, db: Annotated[Session, Depends(get_db)]
):
    if db.get(ProfileModel, str(request.user_id)) is None:
        raise HTTPException(404, "User not found.")
    return SuccessResponse(
        data=BasketResetRepository(db).reset(
            str(request.user_id), request.content_language
        )
    )


@router.get(
    "/api/v2/language-snacks/basket-reset/",
    response_model=SuccessResponse[BasketResetState],
)
def read_snack_basket_reset(
    response: Response,
    user: Annotated[ProfileModel, Depends(get_current_user)],
    db: Annotated[Session, Depends(get_db)],
):
    response.headers["Cache-Control"] = "no-store"
    marker = BasketResetRepository(db).read(str(user.id), user.target_language)
    return SuccessResponse(
        data=marker or BasketResetState(content_language=user.target_language)
    )


@router.post(
    "/api/v2/language-snacks/",
    response_model=SuccessResponse[LanguageSnack],
    status_code=201,
    dependencies=[Depends(require_language_snack_operations_key)],
)
async def create_language_snack(
    request: LanguageSnackCreate,
    generator: Annotated[SnackGenerator, Depends(get_snack_generator)],
):
    from domains.language_snacks.service import LanguageSnackService

    try:
        row = await LanguageSnackService(generator.repository).create(
            request, generator
        )
        return SuccessResponse(data=row)
    except SnackError as error:
        raise HTTPException(error.status_code, error.code) from None


@router.patch(
    "/api/v2/language-snacks/{snack_id}/status/",
    response_model=SuccessResponse[dict],
    dependencies=[Depends(require_language_snack_operations_key)],
)
def archive_language_snack(
    snack_id: UUID, request: ArchiveRequest, db: Annotated[Session, Depends(get_db)]
):
    service = get_language_snack_service(db)
    try:
        with service.repository.locked():
            return SuccessResponse(data=service.archive(snack_id))
    except SnackError as error:
        raise HTTPException(error.status_code, error.code) from None

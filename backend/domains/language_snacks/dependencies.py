"""Language snack 라우트 의존성."""

import secrets
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from config import get_settings
from domains.language_snacks.repository import LanguageSnackRepository
from domains.language_snacks.service import LanguageSnackService


def get_language_snack_service(db: Session) -> LanguageSnackService:
    """언어 스낵 서비스 의존성."""
    return LanguageSnackService(LanguageSnackRepository(db))


def get_language_snack_operations_key() -> str | None:
    """서버 환경에만 존재하는 운영 키를 가져온다."""
    return get_settings().language_snacks_operations_key


def require_language_snack_operations_key(
    operations_key: str | None = Header(default=None, alias="X-Operations-Key"),
    configured_key: Annotated[
        str | None, Depends(get_language_snack_operations_key)
    ] = None,
) -> None:
    """생성 API를 서버의 운영 키로만 보호한다."""
    configured_key = (configured_key or "").strip()
    supplied_key = (operations_key or "").strip()
    if (
        not configured_key
        or not supplied_key
        or not secrets.compare_digest(supplied_key, configured_key)
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Valid operations key is required.",
        )

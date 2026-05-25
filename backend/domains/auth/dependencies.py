"""
Auth 의존성 (라우트 보호)
"""
from fastapi import Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database import get_db
from domains.auth.models import UserModel
from domains.auth.repository import AuthRepository
from domains.auth.service import AuthService
from shared.exceptions import AuthenticationException, NotFoundException

security = HTTPBearer()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    """AuthService 의존성"""
    return AuthService(AuthRepository(db))


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> UserModel:
    """현재 인증된 사용자 반환 (Bearer 토큰 검증)"""
    try:
        user_id = AuthService.decode_access_token(credentials.credentials)
        repository = AuthRepository(db)
        user = repository.find_by_id(user_id)
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="비활성화된 계정입니다",
            )
        return user
    except AuthenticationException as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=e.message,
            headers={"WWW-Authenticate": "Bearer"},
        )
    except NotFoundException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="사용자를 찾을 수 없습니다",
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_user_from_token_param(
    token: str = Query(..., description="JWT access token"),
    db: Session = Depends(get_db),
) -> UserModel:
    """쿼리 파라미터로 전달된 토큰에서 사용자 반환 (SSE 엔드포인트용)"""
    try:
        user_id = AuthService.decode_access_token(token)
        repository = AuthRepository(db)
        user = repository.find_by_id(user_id)
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="비활성화된 계정입니다",
            )
        return user
    except AuthenticationException as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=e.message,
        )
    except NotFoundException:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="사용자를 찾을 수 없습니다",
        )

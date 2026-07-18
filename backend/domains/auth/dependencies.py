"""
Auth 의존성 (라우트 보호)
"""
from fastapi import Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database import get_db
from domains.auth.models import ProfileModel
from domains.auth.repository import AuthRepository
from domains.auth.service import AuthService
from domains.auth.supabase import SupabaseAuthVerifier
from shared.exceptions import AuthenticationException, NotFoundException

security = HTTPBearer()


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    """AuthService 의존성"""
    return AuthService(AuthRepository(db))


def get_supabase_auth_verifier() -> SupabaseAuthVerifier:
    """Supabase Auth verifier 의존성"""
    return SupabaseAuthVerifier()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    service: AuthService = Depends(get_auth_service),
    verifier: SupabaseAuthVerifier = Depends(get_supabase_auth_verifier),
) -> ProfileModel:
    """현재 인증된 프로필 반환 (Supabase Bearer 토큰 검증)"""
    try:
        claims = await verifier.verify_access_token(credentials.credentials)
        profile = service.get_or_create_profile_from_claims(claims)
        if not profile.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="비활성화된 계정입니다",
            )
        return profile
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


async def get_current_user_from_token_param(
    token: str = Query(..., description="Supabase access token"),
    service: AuthService = Depends(get_auth_service),
    verifier: SupabaseAuthVerifier = Depends(get_supabase_auth_verifier),
) -> ProfileModel:
    """쿼리 파라미터로 전달된 Supabase token에서 프로필 반환 (SSE 엔드포인트용)"""
    try:
        claims = await verifier.verify_access_token(token)
        profile = service.get_or_create_profile_from_claims(claims)
        if not profile.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="비활성화된 계정입니다",
            )
        return profile
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

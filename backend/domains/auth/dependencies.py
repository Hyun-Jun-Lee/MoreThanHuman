"""
Auth 의존성 (라우트 보호)
"""
from dataclasses import dataclass

import httpx

from fastapi import Depends, HTTPException, Query, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from database import get_db
from domains.auth.models import ProfileModel
from domains.auth.repository import AuthRepository
from domains.auth.service import AuthService, SupabaseUserClaims
from domains.auth.supabase import SupabaseAuthVerifier
from shared.exceptions import AuthenticationException, NotFoundException
from shared.latency import latency_span
from shared.logging_config import log_exception
from shared.http_clients import get_auth_http_client

security = HTTPBearer()


@dataclass(frozen=True)
class AuthenticatedUser:
    """프로필 조회 없이 검증된 토큰에서 얻은 사용자 ID."""

    id: str


def get_auth_service(
    db: Session = Depends(get_db),
    http_client: httpx.AsyncClient = Depends(get_auth_http_client),
) -> AuthService:
    """AuthService 의존성"""
    return AuthService(AuthRepository(db), http_client=http_client)


def get_supabase_auth_verifier(
    request: Request,
    http_client: httpx.AsyncClient = Depends(get_auth_http_client),
) -> SupabaseAuthVerifier:
    """Supabase Auth verifier 의존성"""
    return getattr(request.app.state, "supabase_auth_verifier", None) or SupabaseAuthVerifier(http_client)


async def get_verified_claims(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    verifier: SupabaseAuthVerifier = Depends(get_supabase_auth_verifier),
) -> SupabaseUserClaims:
    """Bearer 토큰을 검증해 Supabase 사용자 claim을 반환해요."""
    try:
        with latency_span("auth"):
            with latency_span("auth.verify_token"):
                return await verifier.verify_access_token(credentials.credentials)
    except AuthenticationException as e:
        log_exception(e, status_code=401, error_code="AUTHENTICATION_FAILED")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=e.message,
            headers={"WWW-Authenticate": "Bearer"},
        )


def get_current_user(
    claims: SupabaseUserClaims = Depends(get_verified_claims),
) -> AuthenticatedUser:
    """프로필 조회 없이 인증된 사용자 ID를 반환해요."""
    return AuthenticatedUser(id=claims.sub)


def get_current_profile(
    current_user: AuthenticatedUser = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
) -> ProfileModel:
    """학습 언어 등 최신 프로필 필드가 필요한 요청에 사용해요."""
    try:
        with latency_span("auth.profile"):
            return service.repository.find_by_id(current_user.id)
    except NotFoundException as exc:
        raise HTTPException(status_code=409, detail="프로필 초기화가 필요합니다") from exc


def get_legacy_profile(
    claims: SupabaseUserClaims = Depends(get_verified_claims),
    service: AuthService = Depends(get_auth_service),
) -> ProfileModel:
    """전환 기간 동안 기존 모바일의 로그인 API에서 프로필을 생성해요."""
    with latency_span("auth.profile"):
        return service.get_or_create_profile_from_claims(claims)


async def get_current_user_from_token_param(
    token: str = Query(..., description="Supabase access token"),
    verifier: SupabaseAuthVerifier = Depends(get_supabase_auth_verifier),
) -> AuthenticatedUser:
    """SSE 쿼리 토큰을 검증하고 사용자 ID만 반환해요."""
    try:
        with latency_span("auth"):
            with latency_span("auth.verify_token"):
                claims = await verifier.verify_access_token(token)
        return AuthenticatedUser(id=claims.sub)
    except AuthenticationException as e:
        log_exception(e, status_code=401, error_code="AUTHENTICATION_FAILED")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=e.message,
        )

"""
Auth API Router
Supabase Auth로 검증된 현재 프로필 조회
"""
import logging
import secrets

from fastapi import APIRouter, Depends, HTTPException, status

from config import get_settings
from domains.auth.dependencies import get_auth_service, get_current_user
from domains.auth.models import ProfileModel
from domains.auth.schemas import (
    LanguagePreferencesRequest,
    LanguagePreferencesResponse,
    AppLocaleRequest,
    SwaggerTokenRequest,
    TokenResponse,
    UserProfile,
)
from domains.auth.service import AuthService
from shared.exceptions import AuthenticationException
from shared.types import SuccessResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _validate_swagger_token_issuer_access(request: SwaggerTokenRequest) -> None:
    """Swagger token helper는 dev 또는 명시 enable + secret 조합에서만 허용"""
    settings = get_settings()
    configured_secret = (settings.swagger_token_issuer_secret or "").strip()
    supplied_secret = (request.secret or "").strip()

    if settings.is_dev:
        if configured_secret and not secrets.compare_digest(supplied_secret, configured_secret):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid Swagger token issuer secret.",
            )
        return

    if not settings.swagger_token_issuer_enabled:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Swagger token issuer is disabled.",
        )

    if not configured_secret:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="SWAGGER_TOKEN_ISSUER_SECRET is required outside dev.",
        )

    if not secrets.compare_digest(supplied_secret, configured_secret):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid Swagger token issuer secret.",
        )


@router.post("/swagger/token", response_model=SuccessResponse[TokenResponse])
async def issue_swagger_token(
    request: SwaggerTokenRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Swagger 테스트용 Supabase access token 발급"""
    _validate_swagger_token_issuer_access(request)
    try:
        token = await service.issue_swagger_token(email=request.email, password=request.password)
        return SuccessResponse(data=token, message="Swagger 테스트용 토큰 발급 성공")
    except AuthenticationException as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)


@router.get("/me", response_model=SuccessResponse[UserProfile])
def get_me(
    current_user: ProfileModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 프로필 조회"""
    profile = service.get_profile(current_user.id)
    return SuccessResponse(data=profile)


@router.get("/me/language-preferences", response_model=SuccessResponse[LanguagePreferencesResponse])
def get_language_preferences(
    current_user: ProfileModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 언어 선호 조회"""
    preferences = service.get_language_preferences(current_user.id)
    return SuccessResponse(data=preferences)


@router.put("/me/language-preferences", response_model=SuccessResponse[LanguagePreferencesResponse])
def update_language_preferences(
    request: LanguagePreferencesRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 언어 선호 갱신"""
    preferences = service.update_language_preferences(current_user.id, request)
    return SuccessResponse(data=preferences)


@router.put("/me/app-locale", response_model=SuccessResponse[UserProfile])
def update_app_locale(
    request: AppLocaleRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자의 앱 표시 언어 갱신"""
    profile = service.update_app_locale(current_user.id, request)
    return SuccessResponse(data=profile)

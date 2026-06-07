"""
Auth API Router
회원가입, 로그인, Google OAuth, 프로필 조회
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status

from config import get_settings
from domains.auth.dependencies import get_auth_service, get_current_user
from domains.auth.models import UserModel
from domains.auth.schemas import (
    DevTokenRequest,
    GoogleMobileLoginRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserProfile,
)
from domains.auth.service import AuthService
from shared.exceptions import AuthenticationException, ValidationException
from shared.types import SuccessResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/register", response_model=SuccessResponse[TokenResponse])
def register(
    request: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
):
    """이메일+비밀번호 회원가입"""
    try:
        token = service.register(request.email, request.password, request.name, request.device_id)
        return SuccessResponse(data=token, message="회원가입이 완료되었습니다")
    except ValidationException as e:
        http_status = status.HTTP_409_CONFLICT if e.details.get("code") == "EMAIL_EXISTS" else status.HTTP_400_BAD_REQUEST
        raise HTTPException(status_code=http_status, detail=e.message)


@router.post("/login", response_model=SuccessResponse[TokenResponse])
def login(
    request: LoginRequest,
    service: AuthService = Depends(get_auth_service),
):
    """이메일+비밀번호 로그인"""
    try:
        token = service.login(request.email, request.password, request.device_id)
        return SuccessResponse(data=token, message="로그인 성공")
    except AuthenticationException as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)
    except ValidationException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.post("/dev/token", response_model=SuccessResponse[TokenResponse])
def issue_dev_token(
    request: DevTokenRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Swagger/local 테스트용 개발 토큰 발급"""
    if not get_settings().is_dev:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="ENV=dev에서만 사용할 수 있는 개발 전용 엔드포인트입니다",
        )

    try:
        token = service.issue_dev_token(request.email, request.name, request.device_id)
        return SuccessResponse(data=token, message="개발용 토큰 발급 성공")
    except AuthenticationException as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)
    except ValidationException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.post("/google/mobile", response_model=SuccessResponse[TokenResponse])
def google_mobile_login(
    request: GoogleMobileLoginRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Flutter Google Sign-In SDK id_token으로 로그인"""
    try:
        token = service.login_with_google_id_token(request.id_token, request.device_id)
        return SuccessResponse(data=token, message="Google 모바일 로그인 성공")
    except AuthenticationException as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=exc.message)
    except ValidationException as exc:
        http_status = (
            status.HTTP_409_CONFLICT if exc.details.get("code") == "EMAIL_EXISTS" else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=http_status, detail=exc.message)


@router.post("/refresh", response_model=SuccessResponse[TokenResponse])
def refresh(
    request: RefreshRequest,
    service: AuthService = Depends(get_auth_service),
):
    """refresh token으로 access token 재발급 (rotate 포함)"""
    try:
        token = service.refresh(request.refresh_token, request.device_id)
        return SuccessResponse(data=token, message="토큰 갱신 성공")
    except AuthenticationException as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)
    except ValidationException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.post("/logout", response_model=SuccessResponse[dict])
def logout(
    request: LogoutRequest,
    service: AuthService = Depends(get_auth_service),
):
    """refresh token revoke (기본 로그아웃)"""
    try:
        service.logout(request.refresh_token, request.device_id)
        return SuccessResponse(data={"ok": True}, message="로그아웃 성공")
    except ValidationException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/google/login")
def google_login(
    device_id: str = Query(..., description="Flutter installation ID (UUIDv4)"),
    service: AuthService = Depends(get_auth_service),
):
    """Google OAuth2 로그인 URL 반환"""
    try:
        url = service.get_google_login_url(device_id)
        return SuccessResponse(data={"url": url})
    except ValidationException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/google/callback")
async def google_callback(
    code: str,
    state: str,
    service: AuthService = Depends(get_auth_service),
):
    """Google OAuth2 콜백 → JWT 반환"""
    try:
        token = await service.handle_google_callback(code, state)
        return SuccessResponse(data=token, message="Google 로그인 성공")
    except AuthenticationException as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)
    except ValidationException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/me", response_model=SuccessResponse[UserProfile])
def get_me(
    current_user: UserModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 프로필 조회"""
    profile = service.get_profile(current_user.id)
    return SuccessResponse(data=profile)

"""
Auth API Router
회원가입, 로그인, Google OAuth, 프로필 조회
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import JSONResponse

from domains.auth.dependencies import get_auth_service, get_current_user
from domains.auth.models import UserModel
from domains.auth.schemas import LoginRequest, LogoutRequest, RefreshRequest, RegisterRequest, TokenResponse, UserProfile
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
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=e.message)


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


@router.post("/logout", response_model=SuccessResponse[dict])
def logout(
    request: LogoutRequest,
    service: AuthService = Depends(get_auth_service),
):
    """refresh token revoke (기본 로그아웃)"""
    service.logout(request.refresh_token, request.device_id)
    return SuccessResponse(data={"ok": True}, message="로그아웃 성공")


@router.get("/google/login")
def google_login(
    device_id: str,
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
    except (AuthenticationException, ValidationException) as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)


@router.get("/me", response_model=SuccessResponse[UserProfile])
def get_me(
    current_user: UserModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 프로필 조회"""
    profile = service.get_profile(current_user.id)
    return SuccessResponse(data=profile)

"""
Auth API Router
Supabase Auth로 검증된 현재 프로필 조회
"""
import secrets
import logging

import httpx
from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from config import get_settings
from database import get_db
from domains.auth.apple_revoke import revoke_apple_sign_in
from domains.auth.deletion import AccountDeletionService, DeletionAlreadyStarted
from domains.auth.consent import AIConsentService
from domains.auth.dependencies import get_auth_service, get_current_profile, get_legacy_profile, get_verified_claims
from domains.auth.models import ProfileModel
from domains.auth.schemas import (
    LanguagePreferencesRequest,
    LanguagePreferencesResponse,
    AppLocaleRequest,
    AIConsentStatus,
    NicknameRequest,
    SwaggerTokenRequest,
    TokenResponse,
    UserProfile,
    BootstrapRequest,
    GuestTransferClaimRequest,
    GuestTransferClaimResponse,
    GuestTransferReceiptResponse,
)
from domains.auth.service import AuthService, SupabaseUserClaims
from domains.auth.transfer import GuestTransferError, GuestTransferService
from shared.exceptions import AuthenticationException
from shared.logging_config import log_exception
from shared.types import SuccessResponse
from shared.http_clients import get_auth_http_client

router = APIRouter(prefix="/api/auth", tags=["auth"])
logger = logging.getLogger(__name__)


class DeleteAccountRequest(BaseModel):
    apple_identity_token: str | None = Field(default=None, max_length=10000)
    apple_authorization_code: str | None = Field(default=None, max_length=4000)


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
        log_exception(e, status_code=401, error_code="AUTHENTICATION_FAILED")
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=e.message)


@router.get("/me", response_model=SuccessResponse[UserProfile])
def get_me(
    current_user: ProfileModel = Depends(get_legacy_profile),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 프로필 조회"""
    profile = service.get_profile(current_user)
    return SuccessResponse(data=profile)


@router.delete("/me")
async def delete_me(
    response: Response,
    payload: DeleteAccountRequest | None = None,
    claims: SupabaseUserClaims = Depends(get_verified_claims),
    db: Session = Depends(get_db),
    http_client: httpx.AsyncClient = Depends(get_auth_http_client),
):
    """삭제 요청을 먼저 기록해 기존 토큰을 차단하고 필수 삭제를 수행해요."""
    if not get_settings().supabase_secret_key:
        raise HTTPException(status_code=503, detail="Account deletion is temporarily unavailable")
    deletion = AccountDeletionService(db, http_client)
    profile = db.query(ProfileModel).filter_by(id=claims.sub).one_or_none()
    is_apple = (profile.oauth_provider if profile else claims.oauth_provider) == "apple"
    revoked = False
    if is_apple and payload and payload.apple_identity_token and payload.apple_authorization_code:
        revoked = await revoke_apple_sign_in(
            http_client, claims.sub, payload.apple_identity_token, payload.apple_authorization_code,
        )
    try:
        receipt = deletion.start(claims.sub)
    except DeletionAlreadyStarted as exc:
        raise HTTPException(status_code=409, detail="Account deletion already started") from exc
    try:
        await deletion.process(claims.sub)
        state = "completed"
    except Exception:
        db.rollback()
        logger.exception("Account deletion requires retry")
        response.status_code = status.HTTP_202_ACCEPTED
        state = "processing"
    return SuccessResponse(data={"status": state, "receipt": receipt,
                                 "apple_disconnect_required": is_apple and not revoked})


@router.get("/deletion-status/{receipt}")
def deletion_status(receipt: str, db: Session = Depends(get_db)):
    """삭제 후 로그인 토큰 없이 영수증으로 완료 여부를 조회해요."""
    state = AccountDeletionService(db, None).status(receipt)
    if state is None:
        raise HTTPException(status_code=404, detail="Deletion request not found")
    return SuccessResponse(data={"status": state})


@router.post("/bootstrap", response_model=SuccessResponse[UserProfile])
def bootstrap_profile(
    request: BootstrapRequest,
    claims: SupabaseUserClaims = Depends(get_verified_claims),
    service: AuthService = Depends(get_auth_service),
):
    """로그인·세션 복원 시 프로필을 준비하고 pending 언어를 적용해요."""
    return SuccessResponse(data=service.bootstrap_profile(claims, request))


@router.get("/me/ai-consent", response_model=SuccessResponse[AIConsentStatus])
def get_ai_consent_status(
    current_user: ProfileModel = Depends(get_current_profile),
    db: Session = Depends(get_db),
):
    return SuccessResponse(data=AIConsentService(db).status(current_user.id))


@router.post("/me/ai-consent", response_model=SuccessResponse[AIConsentStatus])
def accept_ai_consent(
    current_user: ProfileModel = Depends(get_current_profile),
    db: Session = Depends(get_db),
):
    return SuccessResponse(data=AIConsentService(db).accept_current(current_user.id))


@router.post(
    "/guest-transfer/receipt",
    response_model=SuccessResponse[GuestTransferReceiptResponse],
)
def issue_guest_transfer_receipt(
    current_user: ProfileModel = Depends(get_current_profile),
    db: Session = Depends(get_db),
):
    """기존 계정 로그인 전에 게스트 소유권을 증명할 일회용 영수증을 발급해요."""
    try:
        receipt, expires_at = GuestTransferService(db).issue(current_user.id)
    except GuestTransferError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return SuccessResponse(
        data=GuestTransferReceiptResponse(receipt=receipt, expires_at=expires_at)
    )


@router.post(
    "/guest-transfer/claim",
    response_model=SuccessResponse[GuestTransferClaimResponse],
)
async def claim_guest_transfer_receipt(
    request: GuestTransferClaimRequest,
    current_user: ProfileModel = Depends(get_current_profile),
    db: Session = Depends(get_db),
    http_client: httpx.AsyncClient = Depends(get_auth_http_client),
):
    """회원 JWT로 영수증을 한 번만 사용해 게스트 데이터를 합쳐요."""
    try:
        member, guest_user_id = GuestTransferService(db).claim(
            current_user.id, request.receipt
        )
    except GuestTransferError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    try:
        await AccountDeletionService(db, http_client).process(guest_user_id)
    except Exception:
        db.rollback()
        logger.exception("Transferred guest auth deletion requires retry")
    return SuccessResponse(
        data=GuestTransferClaimResponse(
            profile=UserProfile.model_validate(member),
            guest_user_id=guest_user_id,
        )
    )


@router.get("/me/language-preferences", response_model=SuccessResponse[LanguagePreferencesResponse])
def get_language_preferences(
    current_user: ProfileModel = Depends(get_current_profile),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 언어 선호 조회"""
    preferences = service.get_language_preferences(current_user)
    return SuccessResponse(data=preferences)


@router.put("/me/language-preferences", response_model=SuccessResponse[LanguagePreferencesResponse])
def update_language_preferences(
    request: LanguagePreferencesRequest,
    current_user: ProfileModel = Depends(get_legacy_profile),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 언어 선호 갱신"""
    preferences = service.update_language_preferences(current_user.id, request)
    return SuccessResponse(data=preferences)


@router.put("/me/app-locale", response_model=SuccessResponse[UserProfile])
def update_app_locale(
    request: AppLocaleRequest,
    current_user: ProfileModel = Depends(get_current_profile),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자의 앱 표시 언어 갱신"""
    profile = service.update_app_locale(current_user.id, request)
    return SuccessResponse(data=profile)


@router.put("/me/nickname", response_model=SuccessResponse[UserProfile])
def update_nickname(
    request: NicknameRequest,
    current_user: ProfileModel = Depends(get_current_profile),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자의 닉네임을 저장해요."""
    profile = service.update_nickname(current_user.id, request)
    return SuccessResponse(data=profile)

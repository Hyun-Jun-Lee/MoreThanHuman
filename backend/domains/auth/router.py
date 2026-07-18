"""
Auth API Router
Supabase Auth로 검증된 현재 프로필 조회
"""
import logging

from fastapi import APIRouter, Depends

from domains.auth.dependencies import get_auth_service, get_current_user
from domains.auth.models import ProfileModel
from domains.auth.schemas import UserProfile
from domains.auth.service import AuthService
from shared.types import SuccessResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.get("/me", response_model=SuccessResponse[UserProfile])
def get_me(
    current_user: ProfileModel = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    """현재 사용자 프로필 조회"""
    profile = service.get_profile(current_user.id)
    return SuccessResponse(data=profile)

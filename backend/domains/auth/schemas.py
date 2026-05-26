"""
Auth 도메인 Pydantic 스키마
"""
from datetime import datetime

from pydantic import BaseModel, EmailStr


class RegisterRequest(BaseModel):
    """회원가입 요청"""

    email: EmailStr
    password: str
    name: str
    device_id: str


class LoginRequest(BaseModel):
    """로그인 요청"""

    email: EmailStr
    password: str
    device_id: str


class RefreshRequest(BaseModel):
    """토큰 갱신 요청"""

    refresh_token: str
    device_id: str


class LogoutRequest(BaseModel):
    """로그아웃 요청"""

    refresh_token: str
    device_id: str


class TokenResponse(BaseModel):
    """JWT 토큰 응답"""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserProfile(BaseModel):
    """사용자 프로필"""

    id: str
    email: str
    name: str
    is_active: bool
    oauth_provider: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

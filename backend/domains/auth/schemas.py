"""
Auth 도메인 Pydantic 스키마
"""
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    """회원가입 요청"""

    email: EmailStr
    password: str = Field(min_length=1)
    name: str = Field(min_length=1)
    device_id: str = Field(min_length=1, max_length=64)


class LoginRequest(BaseModel):
    """로그인 요청"""

    email: EmailStr
    password: str = Field(min_length=1)
    device_id: str = Field(min_length=1, max_length=64)


class DevTokenRequest(BaseModel):
    """Swagger/local 테스트용 개발 토큰 요청"""

    email: EmailStr = "swagger-test@example.com"
    name: str = Field(default="Swagger Test User", min_length=1)
    device_id: str = Field(default="swagger-local", min_length=1, max_length=64)


class GoogleMobileLoginRequest(BaseModel):
    """Flutter Google Sign-In SDK id_token 로그인 요청"""

    id_token: str = Field(min_length=1)
    device_id: str = Field(min_length=1, max_length=64)


class RefreshRequest(BaseModel):
    """토큰 갱신 요청"""

    refresh_token: str = Field(min_length=1)
    device_id: str = Field(min_length=1, max_length=64)


class LogoutRequest(BaseModel):
    """로그아웃 요청"""

    refresh_token: str = Field(min_length=1)
    device_id: str = Field(min_length=1, max_length=64)


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
    avatar_url: str | None = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

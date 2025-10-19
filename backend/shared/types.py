"""
공통 타입 정의
"""
from datetime import datetime
from typing import Generic, TypeVar
from uuid import UUID, uuid4

from pydantic import BaseModel, Field

T = TypeVar("T")


class UUIDMixin(BaseModel):
    """UUID 필드 믹스인"""

    id: UUID = Field(default_factory=uuid4)


class TimestampMixin(BaseModel):
    """생성/수정 시간 믹스인"""

    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class BaseResponse(BaseModel):
    """API 응답 기본 모델"""

    success: bool
    message: str | None = None


class SuccessResponse(BaseResponse, Generic[T]):
    """성공 응답"""

    success: bool = True
    data: T


class ErrorResponse(BaseResponse):
    """에러 응답"""

    success: bool = False
    error: str
    details: dict | None = None

from datetime import datetime, timezone
import secrets
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session

from config import get_settings
from database import get_db
from domains.admin.access import (
    AdminAccessDenied, AdminAccessLocked, AdminAccessService, AdminCodeUnavailable,
    attempt_key, clear_session_cookie, cookie_name, set_session_cookie,
)
from domains.admin.models import AdminAccessSessionModel
from domains.admin.service import AdminEntitlementService
from domains.auth.models import ProfileModel
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/admin/users", tags=["admin"])
access_router = APIRouter(prefix="/api/admin/access", tags=["admin"])


class AdminCodeRequest(BaseModel):
    code: str


class ManualEntitlementRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    request_id: UUID
    resource_kind: Literal['slots', 'turns']
    quantity: int = Field(gt=0)


def get_access_session(request: Request, db: Session = Depends(get_db)) -> AdminAccessSessionModel:
    session = AdminAccessService(db).session(request.cookies.get(cookie_name()))
    if session is None:
        raise HTTPException(status_code=401, detail="Admin access session required")
    return session


def require_admin(session: AdminAccessSessionModel = Depends(get_access_session)) -> AdminAccessSessionModel:
    return session


def check_csrf(request: Request, row: AdminAccessSessionModel, supplied: str | None) -> None:
    origin = request.headers.get("origin")
    if origin is not None and origin.rstrip("/") != get_settings().admin_public_origin.rstrip("/"):
        raise HTTPException(status_code=403, detail="Invalid request origin")
    if not supplied or not secrets.compare_digest(supplied, row.csrf_token):
        raise HTTPException(status_code=403, detail="Invalid CSRF token")


def require_admin_write(
    request: Request,
    session: AdminAccessSessionModel = Depends(get_access_session),
    csrf_token: str | None = Header(default=None, alias="X-CSRF-Token"),
) -> AdminAccessSessionModel:
    check_csrf(request, session, csrf_token)
    return session


def get_admin_service(db: Session = Depends(get_db)) -> AdminEntitlementService:
    return AdminEntitlementService(db)


def _verify_code(
    db: Session, code: str, request: Request, response: Response,
) -> SuccessResponse:
    try:
        row, token = AdminAccessService(db).verify_code(
            code, attempt_key(request), previous_token=request.cookies.get(cookie_name()),
        )
    except AdminCodeUnavailable as exc:
        raise HTTPException(status_code=503, detail="Admin code is not configured") from exc
    except AdminAccessLocked as exc:
        raise HTTPException(status_code=429, detail="Try again later") from exc
    except AdminAccessDenied as exc:
        raise HTTPException(status_code=403, detail="Invalid admin code") from exc
    set_session_cookie(response, token)
    return SuccessResponse(data={"verified": True, "csrf_token": row.csrf_token,
                                 "expires_at": row.expires_at})


@access_router.post("/verify/")
def verify_access(
    payload: AdminCodeRequest,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    return _verify_code(db, payload.code, request, response)


@access_router.get("/status/")
def access_status(session: AdminAccessSessionModel = Depends(get_access_session)):
    return SuccessResponse(data={"verified": True,
                                 "csrf_token": session.csrf_token, "expires_at": session.expires_at})


@access_router.post("/logout/")
def logout_access(
    request: Request,
    response: Response,
    session: AdminAccessSessionModel = Depends(get_access_session),
    csrf_token: str | None = Header(default=None, alias="X-CSRF-Token"),
    db: Session = Depends(get_db),
):
    check_csrf(request, session, csrf_token)
    AdminAccessService(db).logout(session)
    clear_session_cookie(response)
    return SuccessResponse(data={"logged_out": True})


def _target(service: AdminEntitlementService, user_id: UUID) -> ProfileModel:
    profile = service.user(str(user_id))
    if profile is None:
        raise HTTPException(status_code=404, detail="User not found")
    return profile


@router.get("/")
def list_users(
    _admin: Annotated[AdminAccessSessionModel, Depends(require_admin)],
    service: Annotated[AdminEntitlementService, Depends(get_admin_service)],
    q: str | None = Query(default=None, max_length=255),
    is_admin: bool | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    return SuccessResponse(data=service.list_users(
        q=q, is_admin=is_admin, limit=limit, offset=offset,
    ))


@router.get("/{user_id}/")
def get_user(
    user_id: UUID,
    _admin: Annotated[AdminAccessSessionModel, Depends(require_admin)],
    service: Annotated[AdminEntitlementService, Depends(get_admin_service)],
):
    return SuccessResponse(data=service.user_data(_target(service, user_id)))


@router.get("/{user_id}/entitlement/")
def get_entitlement(
    user_id: UUID,
    _admin: Annotated[AdminAccessSessionModel, Depends(require_admin)],
    service: Annotated[AdminEntitlementService, Depends(get_admin_service)],
):
    return SuccessResponse(data=service.entitlement_detail(_target(service, user_id)))


@router.get("/{user_id}/manual-entitlement/history/")
def get_history(
    user_id: UUID,
    _admin: Annotated[AdminAccessSessionModel, Depends(require_admin)],
    service: Annotated[AdminEntitlementService, Depends(get_admin_service)],
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
):
    _target(service, user_id)
    return SuccessResponse(data=service.history(str(user_id), limit=limit, offset=offset))


@router.put("/{user_id}/manual-entitlement/")
def put_manual(
    user_id: UUID,
    request: ManualEntitlementRequest,
    _admin: Annotated[AdminAccessSessionModel, Depends(require_admin_write)],
    service: Annotated[AdminEntitlementService, Depends(get_admin_service)],
):
    try:
        result = service.put_manual(str(user_id), str(request.request_id), request.resource_kind, request.quantity)
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    if result is None:
        raise HTTPException(status_code=404, detail="User not found")
    return SuccessResponse(data=result)


@router.delete("/{user_id}/manual-entitlement/{grant_id}/")
def delete_manual(
    user_id: UUID,
    grant_id: UUID,
    _admin: Annotated[AdminAccessSessionModel, Depends(require_admin_write)],
    service: Annotated[AdminEntitlementService, Depends(get_admin_service)],
):
    result = service.delete_manual(str(user_id), str(grant_id))
    if result is None:
        raise HTTPException(status_code=404, detail="User not found")
    return SuccessResponse(data=result)

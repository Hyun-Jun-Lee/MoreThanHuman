"""tomatalk 구독 상태와 Apple 서버 알림 API."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from config import get_settings
from database import get_db
from domains.auth.dependencies import get_current_user
from domains.auth.models import ProfileModel
from domains.billing.apple import AppleConfigurationError, AppleGateway, AppleUnavailableError, AppleVerificationError
from domains.billing.service import BillingService, PurchaseOwnedByAnotherAccount
from shared.logging_config import log_exception
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/billing", tags=["billing"])


class VerifyPurchaseRequest(BaseModel):
    signed_transaction: str = Field(min_length=100, max_length=20000)


class NotificationRequest(BaseModel):
    signedPayload: str = Field(min_length=100, max_length=100000)


def get_billing_service(db: Session = Depends(get_db)) -> BillingService:
    try:
        return BillingService(db, AppleGateway(get_settings()))
    except AppleConfigurationError as exc:
        log_exception(exc, status_code=503, error_code="APPLE_NOT_CONFIGURED")
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Apple 결제가 아직 준비되지 않았어요")


@router.get("/entitlement/")
def get_entitlement(current_user: ProfileModel = Depends(get_current_user), db: Session = Depends(get_db)):
    from shared.subscription import entitlement_for_user
    return SuccessResponse(data=entitlement_for_user(db, current_user.id))


@router.post("/apple/verify/")
def verify_purchase(
    payload: VerifyPurchaseRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: BillingService = Depends(get_billing_service),
):
    try:
        return SuccessResponse(data=service.verify_purchase(current_user.id, payload.signed_transaction))
    except PurchaseOwnedByAnotherAccount as exc:
        log_exception(exc, status_code=409, error_code="PURCHASE_ACCOUNT_CONFLICT")
        raise HTTPException(status_code=409, detail={"code": "PURCHASE_ACCOUNT_CONFLICT", "message": str(exc)})
    except AppleVerificationError as exc:
        log_exception(exc, status_code=400, error_code="INVALID_APPLE_PURCHASE")
        raise HTTPException(status_code=400, detail={"code": "INVALID_APPLE_PURCHASE", "message": str(exc)})
    except AppleUnavailableError as exc:
        log_exception(exc, status_code=503, error_code="APPLE_UNAVAILABLE")
        raise HTTPException(status_code=503, detail={"code": "APPLE_UNAVAILABLE", "message": "Apple 구독 확인을 다시 시도해 주세요"})


@router.post("/apple/notifications/")
def apple_notification(payload: NotificationRequest, service: BillingService = Depends(get_billing_service)):
    try:
        service.process_notification(payload.signedPayload)
        return {"success": True}
    except AppleVerificationError as exc:
        log_exception(exc, status_code=400, error_code="INVALID_APPLE_NOTIFICATION")
        raise HTTPException(status_code=400, detail="Invalid Apple notification")
    except AppleUnavailableError as exc:
        log_exception(exc, status_code=503, error_code="APPLE_UNAVAILABLE")
        raise HTTPException(status_code=503, detail="Apple status unavailable")

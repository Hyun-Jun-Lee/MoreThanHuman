"""검증된 Apple 구독을 Convia 계정에 연결하고 갱신해요."""
from datetime import datetime
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.auth.models import ProfileModel
from domains.billing.apple import AppleGateway, AppleVerificationError, VerifiedSubscription
from shared.subscription import AppleNotificationModel, AppleSubscriptionModel, entitlement_for_user


class PurchaseOwnedByAnotherAccount(ValueError):
    pass


def _same_uuid(left: str, right: str) -> bool:
    try:
        return UUID(left) == UUID(right)
    except ValueError:
        return False


class BillingService:
    def __init__(self, db: Session, gateway: AppleGateway):
        self.db = db
        self.gateway = gateway

    def entitlement(self, user_id: str) -> dict:
        return entitlement_for_user(self.db, user_id)

    def verify_purchase(self, user_id: str, signed_transaction: str) -> dict:
        supplied = self.gateway.decode_transaction(signed_transaction)
        if supplied.appAccountToken and not _same_uuid(supplied.appAccountToken, user_id):
            raise PurchaseOwnedByAnotherAccount("이 Apple 구독은 다른 Convia 계정에 연결되어 있어요")
        source = self.db.query(AppleSubscriptionModel).filter_by(
            original_transaction_id=supplied.originalTransactionId
        ).one_or_none()
        if source is not None and source.user_id != user_id:
            raise PurchaseOwnedByAnotherAccount("이미 다른 Convia 계정에 연결된 구매예요")
        current = self.gateway.current_subscription(supplied.originalTransactionId)
        return self._save(current, user_id, source_original=supplied.originalTransactionId)

    def _save(self, current: VerifiedSubscription, user_id: str, *, source_original: str | None = None) -> dict:
        if current.app_account_token and not _same_uuid(current.app_account_token, user_id):
            raise PurchaseOwnedByAnotherAccount("이 Apple 구독은 다른 Convia 계정에 연결되어 있어요")
        try:
            # 대화 권한 갱신과 발화/생성은 같은 프로필 행에서 직렬화해요.
            self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one()
            record = self.db.query(AppleSubscriptionModel).filter_by(
                original_transaction_id=current.original_transaction_id
            ).with_for_update().one_or_none()
            if record is not None and record.user_id != user_id:
                raise PurchaseOwnedByAnotherAccount("이미 다른 Convia 계정에 연결된 구매예요")
            if source_original and source_original != current.original_transaction_id:
                source = self.db.query(AppleSubscriptionModel).filter_by(
                    original_transaction_id=source_original
                ).with_for_update().one_or_none()
                if source is not None:
                    if source.user_id != user_id:
                        raise PurchaseOwnedByAnotherAccount("이미 다른 Convia 계정에 연결된 구매예요")
                    source.status = "expired"
            if record is None:
                record = AppleSubscriptionModel(original_transaction_id=current.original_transaction_id, user_id=user_id)
                self.db.add(record)
            record.last_transaction_id = current.transaction_id
            record.product_id = current.product_id
            record.environment = current.environment
            record.status = current.status
            record.expires_at = current.expires_at
            record.grace_expires_at = current.grace_expires_at
            record.verified_at = datetime.utcnow()
            self.db.commit()
        except IntegrityError as exc:
            self.db.rollback()
            raise PurchaseOwnedByAnotherAccount("이미 다른 Convia 계정에 연결된 구매예요") from exc
        except Exception:
            self.db.rollback()
            raise
        return self.entitlement(user_id)

    def process_notification(self, signed_payload: str) -> None:
        from shared.latency import latency_span

        with latency_span("auth"):
            notification = self.gateway.decode_notification(signed_payload)
        if not notification.notificationUUID:
            raise AppleVerificationError("Apple 알림 ID가 없어요")
        if self.db.query(AppleNotificationModel).filter_by(notification_uuid=notification.notificationUUID).first():
            return
        signed_transaction = notification.data.signedTransactionInfo if notification.data else None
        if not signed_transaction:
            self.db.add(AppleNotificationModel(notification_uuid=notification.notificationUUID))
            self.db.commit()
            return
        transaction = self.gateway.decode_transaction(signed_transaction)
        current = self.gateway.current_subscription(transaction.originalTransactionId)
        record = self.db.query(AppleSubscriptionModel).filter_by(
            original_transaction_id=transaction.originalTransactionId
        ).one_or_none()
        user_id = record.user_id if record else current.app_account_token
        if user_id and self.db.query(ProfileModel).filter_by(id=user_id).first():
            self._save(current, user_id, source_original=transaction.originalTransactionId)
        try:
            self.db.add(AppleNotificationModel(
                notification_uuid=notification.notificationUUID,
                original_transaction_id=transaction.originalTransactionId,
            ))
            self.db.commit()
        except IntegrityError:
            self.db.rollback()

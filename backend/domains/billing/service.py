"""검증된 Apple 구독을 tomatalk 계정에 연결하고 갱신해요."""
from datetime import datetime
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.auth.models import AccountDeletionModel, ProfileModel
from domains.billing.apple import AppleGateway, AppleVerificationError, VerifiedSubscription
from shared.subscription import AppleNotificationModel, AppleSubscriptionModel, entitlement_for_user


class PurchaseOwnedByAnotherAccount(ValueError):
    pass


def _same_uuid(left: str, right: str) -> bool:
    try:
        return UUID(str(left)) == UUID(str(right))
    except (TypeError, ValueError):
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
            raise PurchaseOwnedByAnotherAccount("이 Apple 구독은 다른 tomatalk 계정에 연결되어 있어요")
        source = self.db.query(AppleSubscriptionModel).filter_by(
            original_transaction_id=supplied.originalTransactionId
        ).one_or_none()
        if source is not None and source.user_id != user_id:
            raise PurchaseOwnedByAnotherAccount("이미 다른 tomatalk 계정에 연결된 구매예요")
        current = self.gateway.current_subscription(supplied.originalTransactionId)
        return self._save(current, user_id, source_original=supplied.originalTransactionId)

    def restore_purchase(self, user_id: str, signed_transaction: str) -> dict:
        """명시적 복원에서 삭제된 계정의 남은 이용 권한만 이전해요."""
        supplied = self.gateway.decode_transaction(signed_transaction)
        current = self.gateway.current_subscription(supplied.originalTransactionId)
        now = datetime.utcnow()
        valid = ((current.status == "active" and current.expires_at and current.expires_at > now)
                 or (current.status == "grace" and current.grace_expires_at and current.grace_expires_at > now))
        if not valid:
            raise AppleVerificationError("현재 유효한 Apple 구독이 없어요")
        for token in (current.app_account_token, supplied.appAccountToken):
            if token and not _same_uuid(token, user_id) and not self.db.query(
                AccountDeletionModel
            ).filter_by(user_id=str(token), status="completed").first():
                raise PurchaseOwnedByAnotherAccount("이 Apple 구독은 다른 활성 계정에 연결되어 있어요")
        try:
            self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one()
            supplied_record = self.db.query(AppleSubscriptionModel).filter_by(
                original_transaction_id=supplied.originalTransactionId
            ).with_for_update().one_or_none()
            if supplied_record is not None and supplied_record.user_id != user_id:
                if not self.db.query(AccountDeletionModel).filter_by(
                    user_id=supplied_record.user_id, status="completed"
                ).first():
                    raise PurchaseOwnedByAnotherAccount("이미 다른 활성 계정에 연결된 구매예요")
            if (supplied_record is not None and supplied_record.user_id == user_id
                    and supplied_record.original_transaction_id != current.original_transaction_id):
                supplied_record.status = "expired"
            record = self.db.query(AppleSubscriptionModel).filter_by(
                original_transaction_id=current.original_transaction_id
            ).with_for_update().one_or_none()
            if record is not None and record.user_id != user_id:
                if not self.db.query(AccountDeletionModel).filter_by(
                    user_id=record.user_id, status="completed"
                ).first():
                    raise PurchaseOwnedByAnotherAccount("이미 다른 활성 계정에 연결된 구매예요")
            if record is None:
                record = AppleSubscriptionModel(original_transaction_id=current.original_transaction_id, user_id=user_id)
                self.db.add(record)
            else:
                record.user_id = user_id
            record.last_transaction_id = current.transaction_id
            record.product_id = current.product_id
            record.environment = current.environment
            record.status = current.status
            record.expires_at = current.expires_at
            record.grace_expires_at = current.grace_expires_at
            record.verified_at = now
            self.db.flush()  # 원거래 ID의 단독 소유권을 먼저 확보해요.
            if not current.app_account_token or not _same_uuid(current.app_account_token, user_id):
                self.gateway.set_app_account_token(current.original_transaction_id, user_id)
            self.db.commit()
        except IntegrityError as exc:
            self.db.rollback()
            raise PurchaseOwnedByAnotherAccount("이미 다른 계정에 연결된 구매예요") from exc
        except Exception:
            self.db.rollback()
            raise
        return self.entitlement(user_id)

    def _save(self, current: VerifiedSubscription, user_id: str, *, source_original: str | None = None) -> dict:
        if current.app_account_token and not _same_uuid(current.app_account_token, user_id):
            previous_deleted = self.db.query(AccountDeletionModel).filter_by(
                user_id=str(current.app_account_token), status="completed"
            ).first() is not None
            assigned = self.db.query(AppleSubscriptionModel).filter_by(
                original_transaction_id=current.original_transaction_id, user_id=user_id,
            ).first() is not None
            if not (previous_deleted and assigned):
                raise PurchaseOwnedByAnotherAccount("이 Apple 구독은 다른 tomatalk 계정에 연결되어 있어요")
        try:
            # 대화 권한 갱신과 발화/생성은 같은 프로필 행에서 직렬화해요.
            self.db.query(ProfileModel).filter_by(id=user_id).with_for_update().one()
            record = self.db.query(AppleSubscriptionModel).filter_by(
                original_transaction_id=current.original_transaction_id
            ).with_for_update().one_or_none()
            if record is not None and record.user_id != user_id:
                raise PurchaseOwnedByAnotherAccount("이미 다른 tomatalk 계정에 연결된 구매예요")
            if source_original and source_original != current.original_transaction_id:
                source = self.db.query(AppleSubscriptionModel).filter_by(
                    original_transaction_id=source_original
                ).with_for_update().one_or_none()
                if source is not None:
                    if source.user_id != user_id:
                        raise PurchaseOwnedByAnotherAccount("이미 다른 tomatalk 계정에 연결된 구매예요")
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
            raise PurchaseOwnedByAnotherAccount("이미 다른 tomatalk 계정에 연결된 구매예요") from exc
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

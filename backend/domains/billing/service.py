"""서명 거래별 한 번 지급과 환불·삭제 terminal 처리를 담당해요."""
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import NoResultFound

from domains.auth.models import AccountDeletionModel, ProfileModel
from domains.billing.apple import AppleGateway, AppleVerificationError, PRODUCTS
from shared.billing_models import CreditLotModel, PurchaseDeliveryModel, PurchaseNotificationModel
from shared.billing_tombstones import find_tombstone, keyring, remember
from shared.credit_ledger import CreditLedger
from shared.subscription import entitlement_for_user


class PurchaseOwnedByAnotherAccount(ValueError):
    pass


class BillingService:
    def __init__(self, db: Session, gateway: AppleGateway):
        self.db = db
        self.gateway = gateway

    def entitlement(self, user_id: str) -> dict:
        result = entitlement_for_user(self.db, user_id)
        self.db.commit()
        return result

    def _deleted(self, token: str) -> bool:
        return bool(find_tombstone(self.db, 'account', token) or
                    self.db.query(AccountDeletionModel).filter_by(user_id=token).first())

    def _terminal(self, tx) -> dict | None:
        token = str(UUID(str(tx.appAccountToken)))
        if self._deleted(token):
            remember(self.db, 'transaction', tx.transactionId, 'deleted')
            self.db.commit()
            return {'delivery_status': 'deleted', 'terminal': True}
        return None

    def terminalize_purchase(self, signed_transaction: str) -> dict:
        keyring()
        tx = self.gateway.decode_transaction(signed_transaction)
        result = self._terminal(tx)
        if result:
            return result
        raise PurchaseOwnedByAnotherAccount('원래 구매한 tomatalk 계정으로 로그인해 주세요')

    def verify_purchase(self, user_id: str, signed_transaction: str) -> dict:
        keyring()
        tx = self.gateway.decode_transaction(signed_transaction)
        terminal = self._terminal(tx)
        if terminal:
            return terminal
        if UUID(str(tx.appAccountToken)) != UUID(user_id):
            raise PurchaseOwnedByAnotherAccount('원래 구매한 tomatalk 계정으로 로그인해 주세요')
        try:
            try:
                profile = CreditLedger(self.db).lock(user_id)
            except NoResultFound:
                terminal = self._terminal(tx)
                if terminal:
                    return terminal
                raise PurchaseOwnedByAnotherAccount('구매 계정을 찾을 수 없어요')
            terminal = self._terminal(tx)
            if terminal:
                return terminal
            if profile.is_guest:
                raise PurchaseOwnedByAnotherAccount('이 계정에는 구매를 지급할 수 없어요')
            tombstone = find_tombstone(self.db, 'transaction', tx.transactionId)
            if tombstone:
                self.db.commit()
                return {'delivery_status': tombstone.status, 'terminal': True}
            record = self.db.get(PurchaseDeliveryModel, tx.transactionId)
            if record and record.user_id != user_id:
                raise PurchaseOwnedByAnotherAccount('이미 다른 계정에 지급한 구매예요')
            kind, quantity = PRODUCTS[tx.productId]
            if record is None:
                record = PurchaseDeliveryModel(transaction_id=tx.transactionId, user_id=user_id,
                    product_id=tx.productId, environment=getattr(tx.environment, 'value', tx.environment),
                    resource_kind=kind, quantity=quantity,
                    status='revoked' if tx.revocationDate is not None else 'granted')
                self.db.add(record)
                self.db.flush()
                if kind == 'turns' and record.status == 'granted':
                    CreditLedger(self.db).grant_turns(profile, quantity, source='apple', source_key=tx.transactionId)
            elif tx.revocationDate is not None:
                self._refund(profile, record)
            result = {**entitlement_for_user(self.db, user_id), 'delivery_status': record.status, 'terminal': True}
            self.db.commit()
            return result
        except Exception:
            self.db.rollback()
            raise

    def _refund(self, profile: ProfileModel, record: PurchaseDeliveryModel) -> None:
        record.status = 'revoked'
        lot = self.db.query(CreditLotModel).filter_by(user_id=profile.id, source='apple', source_key=record.transaction_id).one_or_none()
        if lot:
            CreditLedger(self.db).revoke_lot(profile, lot)

    def process_notification(self, signed_payload: str) -> None:
        keyring()
        from shared.latency import latency_span
        with latency_span('auth'):
            notification = self.gateway.decode_notification(signed_payload)
        if not notification.notificationUUID:
            raise AppleVerificationError('Apple 알림 ID가 없어요')
        if self.db.get(PurchaseNotificationModel, notification.notificationUUID):
            return
        kind = getattr(notification.notificationType, 'value', notification.notificationType)
        signed = notification.data.signedTransactionInfo if notification.data else None
        tx = self.gateway.decode_transaction(signed) if signed else None
        if kind == 'REFUND' and tx is None:
            raise AppleVerificationError('환불 거래 정보가 없어요')
        try:
            if kind == 'REFUND' and tx:
                token = str(UUID(str(tx.appAccountToken)))
                profile = self.db.query(ProfileModel).filter_by(id=token).populate_existing().with_for_update().one_or_none()
                if profile and not self._deleted(token):
                    record = self.db.get(PurchaseDeliveryModel, tx.transactionId)
                    if record:
                        if record.user_id != token:
                            raise AppleVerificationError('거래 소유자가 일치하지 않아요')
                        self._refund(profile, record)
                    else:
                        resource, quantity = PRODUCTS[tx.productId]
                        self.db.add(PurchaseDeliveryModel(transaction_id=tx.transactionId, user_id=token,
                            product_id=tx.productId, environment=getattr(tx.environment, 'value', tx.environment),
                            resource_kind=resource, quantity=quantity, status='refund-before-delivery'))
                else:
                    remember(self.db, 'transaction', tx.transactionId, 'refund-before-delivery')
            # CONSUMPTION_REQUEST는 동의 없는 소비 정보 전송 없이 감사 기록만 남겨요.
            self.db.add(PurchaseNotificationModel(notification_uuid=notification.notificationUUID,
                                                 notification_type=kind or 'UNKNOWN'))
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            if not self.db.get(PurchaseNotificationModel, notification.notificationUUID):
                raise
        except Exception:
            self.db.rollback()
            raise

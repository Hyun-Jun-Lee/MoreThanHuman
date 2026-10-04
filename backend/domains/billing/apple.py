"""Apple 공식 라이브러리 기반 거래·알림 검증과 현재 상태 조회."""
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

from appstoreserverlibrary.api_client import APIException, AppStoreServerAPIClient
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.Status import Status
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from config import Settings

PRODUCTS = {"Advance", "Plus"}
GROUP_ID = "22439301"
ROOTS = Path(__file__).resolve().parents[2] / "certs" / "apple"


class AppleConfigurationError(RuntimeError):
    pass


class AppleVerificationError(ValueError):
    pass


class AppleUnavailableError(RuntimeError):
    pass


@dataclass(frozen=True)
class VerifiedSubscription:
    original_transaction_id: str
    transaction_id: str
    app_account_token: str | None
    product_id: str
    environment: str
    status: str
    expires_at: datetime | None
    grace_expires_at: datetime | None


def _from_millis(value: int | None) -> datetime | None:
    return datetime.utcfromtimestamp(value / 1000) if value is not None else None


class AppleGateway:
    """서명과 App Store Server API를 모두 확인해요."""

    def __init__(self, settings: Settings):
        fields = (
            settings.apple_iap_environment, settings.apple_iap_bundle_id,
            settings.apple_iap_issuer_id, settings.apple_iap_key_id,
            settings.apple_iap_private_key,
        )
        if not all(fields) or (settings.apple_iap_environment == "production" and not settings.apple_iap_app_id):
            raise AppleConfigurationError("Apple IAP server settings are incomplete")
        environment = Environment.PRODUCTION if settings.apple_iap_environment == "production" else Environment.SANDBOX
        certificates = [path.read_bytes() for path in sorted(ROOTS.glob("*.cer"))]
        if len(certificates) < 3:
            raise AppleConfigurationError("Apple root certificates are missing")
        self.environment = environment
        self.bundle_id = settings.apple_iap_bundle_id
        self.verifier = SignedDataVerifier(
            certificates, True, environment, self.bundle_id, settings.apple_iap_app_id,
        )
        self.client = AppStoreServerAPIClient(
            settings.apple_iap_private_key.replace("\\n", "\n").encode("utf-8"),
            settings.apple_iap_key_id, settings.apple_iap_issuer_id,
            self.bundle_id, environment,
        )

    def decode_transaction(self, signed_transaction: str):
        try:
            transaction = self.verifier.verify_and_decode_signed_transaction(signed_transaction)
        except (VerificationException, ValueError) as exc:
            raise AppleVerificationError("Apple 거래 서명을 확인할 수 없어요") from exc
        if (transaction.productId not in PRODUCTS or
                transaction.subscriptionGroupIdentifier != GROUP_ID or
                not transaction.originalTransactionId or not transaction.transactionId):
            raise AppleVerificationError("지원하지 않는 Apple 구독 거래예요")
        return transaction

    def decode_notification(self, signed_payload: str):
        try:
            return self.verifier.verify_and_decode_notification(signed_payload)
        except (VerificationException, ValueError) as exc:
            raise AppleVerificationError("Apple 알림 서명을 확인할 수 없어요") from exc

    def current_subscription(self, transaction_id: str) -> VerifiedSubscription:
        try:
            response = self.client.get_all_subscription_statuses(transaction_id)
        except APIException as exc:
            raise AppleUnavailableError("Apple 구독 상태를 조회하지 못했어요") from exc
        if response.bundleId != self.bundle_id or response.environment != self.environment:
            raise AppleVerificationError("다른 앱 또는 환경의 구독 상태예요")
        candidates = []
        for group in response.data or []:
            if group.subscriptionGroupIdentifier != GROUP_ID:
                continue
            for item in group.lastTransactions or []:
                if not item.signedTransactionInfo or not item.originalTransactionId:
                    continue
                tx = self.decode_transaction(item.signedTransactionInfo)
                if tx.originalTransactionId != item.originalTransactionId:
                    raise AppleVerificationError("Apple 원거래 ID가 일치하지 않아요")
                renewal = None
                if item.signedRenewalInfo:
                    try:
                        renewal = self.verifier.verify_and_decode_renewal_info(item.signedRenewalInfo)
                    except VerificationException as exc:
                        raise AppleVerificationError("Apple 갱신 정보 서명이 유효하지 않아요") from exc
                status = {
                    Status.ACTIVE: "active", Status.BILLING_GRACE_PERIOD: "grace",
                    Status.EXPIRED: "expired", Status.BILLING_RETRY: "billing_retry",
                    Status.REVOKED: "revoked",
                }.get(item.status)
                if status is None:
                    continue
                if tx.revocationDate is not None:
                    status = "revoked"
                candidates.append(VerifiedSubscription(
                    original_transaction_id=tx.originalTransactionId,
                    transaction_id=tx.transactionId,
                    app_account_token=tx.appAccountToken,
                    product_id=tx.productId,
                    environment=self.environment.value,
                    status=status,
                    expires_at=_from_millis(tx.expiresDate),
                    grace_expires_at=_from_millis(renewal.gracePeriodExpiresDate) if renewal else None,
                ))
        if not candidates:
            raise AppleVerificationError("해당 구독 그룹의 거래가 없어요")
        # App Store의 그룹 상태 중 유효한 최신 거래를 사용해요.
        now = datetime.utcnow()
        def priority(item: VerifiedSubscription):
            valid = item.status == "active" and item.expires_at and item.expires_at > now
            grace = item.status == "grace" and item.grace_expires_at and item.grace_expires_at > now
            return (bool(valid or grace), item.expires_at or datetime.min, item.transaction_id)
        return max(candidates, key=priority)

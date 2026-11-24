"""Apple 공식 라이브러리로 소비성 거래와 서버 알림을 검증해요."""
from pathlib import Path
from uuid import UUID

from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from config import Settings

PRODUCTS = {
    'com.morethanhuman.curitalk.slots.plus.1': ('slots', 1),
    'com.morethanhuman.curitalk.slots.plus.3': ('slots', 3),
    'com.morethanhuman.curitalk.turns.5': ('turns', 5),
    'com.morethanhuman.curitalk.turns.10': ('turns', 10),
    'com.morethanhuman.curitalk.turns.20': ('turns', 20),
}
ROOTS = Path(__file__).resolve().parents[2] / 'certs' / 'apple'


class AppleConfigurationError(RuntimeError):
    pass


class AppleVerificationError(ValueError):
    pass


class AppleUnavailableError(RuntimeError):
    pass


class AppleGateway:
    def __init__(self, settings: Settings):
        if not settings.apple_iap_environment or not settings.apple_iap_bundle_id or (
            settings.apple_iap_environment == 'production' and not settings.apple_iap_app_id
        ):
            raise AppleConfigurationError('Apple IAP server settings are incomplete')
        self.environment = Environment.PRODUCTION if settings.apple_iap_environment == 'production' else Environment.SANDBOX
        self.bundle_id = settings.apple_iap_bundle_id
        certificates = [path.read_bytes() for path in sorted(ROOTS.glob('*.cer'))]
        if len(certificates) < 3:
            raise AppleConfigurationError('Apple root certificates are missing')
        self.verifier = SignedDataVerifier(certificates, True, self.environment, self.bundle_id, settings.apple_iap_app_id)

    def decode_transaction(self, signed_transaction: str):
        try:
            tx = self.verifier.verify_and_decode_signed_transaction(signed_transaction)
        except (VerificationException, ValueError) as exc:
            raise AppleVerificationError('Apple 거래 서명을 확인할 수 없어요') from exc
        if (tx.productId not in PRODUCTS or getattr(tx.type, 'value', tx.type) != 'Consumable'
                or not tx.transactionId or tx.bundleId != self.bundle_id
                or tx.environment != self.environment or tx.quantity != 1):
            raise AppleVerificationError('지원하지 않는 Apple 소비성 거래예요')
        try:
            UUID(str(tx.appAccountToken))
        except (ValueError, TypeError) as exc:
            raise AppleVerificationError('구매 계정 토큰이 없거나 잘못됐어요') from exc
        return tx

    def decode_notification(self, signed_payload: str):
        try:
            return self.verifier.verify_and_decode_notification(signed_payload)
        except (VerificationException, ValueError) as exc:
            raise AppleVerificationError('Apple 알림 서명을 확인할 수 없어요') from exc

"""공식 Apple 라이브러리와 구독 상태 응답의 연결을 검증해요."""
from datetime import datetime, timedelta
from types import SimpleNamespace

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.Status import Status

from domains.billing.apple import AppleGateway


def test_gateway_accepts_p8_key_and_maps_current_subscription():
    key = ec.generate_private_key(ec.SECP256R1()).private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    settings = SimpleNamespace(
        apple_iap_environment="sandbox",
        apple_iap_bundle_id="com.morethanhuman.curitalk",
        apple_iap_app_id=None,
        apple_iap_issuer_id="00000000-0000-0000-0000-000000000000",
        apple_iap_key_id="ABCDEFGHIJ",
        apple_iap_private_key=key,
    )
    gateway = AppleGateway(settings)
    expiry = int((datetime.utcnow() + timedelta(days=5)).timestamp() * 1000)
    gateway.client = SimpleNamespace(get_all_subscription_statuses=lambda _: SimpleNamespace(
        bundleId=settings.apple_iap_bundle_id,
        environment=Environment.SANDBOX,
        data=[SimpleNamespace(subscriptionGroupIdentifier="22439301", lastTransactions=[
            SimpleNamespace(
                signedTransactionInfo="signed", signedRenewalInfo=None,
                originalTransactionId="100", status=Status.ACTIVE,
            ),
        ])],
    ))
    gateway.decode_transaction = lambda _: SimpleNamespace(
        originalTransactionId="100", transactionId="101",
        appAccountToken=None, productId="Advance", expiresDate=expiry,
        revocationDate=None,
    )

    current = gateway.current_subscription("100")
    assert current.product_id == "Advance"
    assert current.status == "active"
    assert current.expires_at > datetime.utcnow()

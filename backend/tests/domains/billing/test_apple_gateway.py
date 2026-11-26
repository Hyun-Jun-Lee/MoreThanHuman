from types import SimpleNamespace
from uuid import uuid4
import pytest
from appstoreserverlibrary.models.Environment import Environment
from domains.billing.apple import AppleGateway, AppleVerificationError, PRODUCTS


def gateway():
    instance = AppleGateway(SimpleNamespace(apple_iap_environment='sandbox',
        apple_iap_bundle_id='com.morethanhuman.curitalk', apple_iap_app_id=None))
    tx = SimpleNamespace(productId=next(iter(PRODUCTS)), type='Consumable',
        transactionId='100', bundleId=instance.bundle_id, environment=Environment.SANDBOX,
        quantity=1, appAccountToken=str(uuid4()))
    instance.verifier = SimpleNamespace(verify_and_decode_signed_transaction=lambda _: tx)
    return instance, tx


def test_consumable_signature_result_is_allowlisted():
    instance, tx = gateway()
    assert instance.decode_transaction('signed') is tx


@pytest.mark.parametrize('field,value', [('productId', 'Advance'), ('type', 'Non-Consumable'),
    ('bundleId', 'other'), ('environment', Environment.PRODUCTION), ('appAccountToken', None),
    ('transactionId', None), ('quantity', 2)])
def test_wrong_transaction_is_rejected(field, value):
    instance, tx = gateway()
    setattr(tx, field, value)
    with pytest.raises(AppleVerificationError):
        instance.decode_transaction('signed')

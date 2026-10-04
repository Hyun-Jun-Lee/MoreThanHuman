"""Apple 알림 누락에 대비해 저장된 구독의 현재 상태를 다시 조회해요."""
import logging

from config import get_settings
from database import SessionLocal
from domains.billing.apple import AppleGateway
from domains.billing.service import BillingService
from shared.subscription import AppleSubscriptionModel

logger = logging.getLogger(__name__)


def reconcile() -> tuple[int, int]:
    gateway = AppleGateway(get_settings())
    checked = 0
    failed = 0
    with SessionLocal() as db:
        subscriptions = db.query(AppleSubscriptionModel).all()
        for subscription in subscriptions:
            try:
                current = gateway.current_subscription(subscription.original_transaction_id)
                BillingService(db, gateway)._save(
                    current, subscription.user_id,
                    source_original=subscription.original_transaction_id,
                )
                checked += 1
            except Exception:
                db.rollback()
                failed += 1
                logger.exception("Apple subscription reconciliation failed for %s", subscription.original_transaction_id)
    return checked, failed


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    checked_count, failed_count = reconcile()
    print(f"checked={checked_count} failed={failed_count}")
    if failed_count:
        raise SystemExit(1)

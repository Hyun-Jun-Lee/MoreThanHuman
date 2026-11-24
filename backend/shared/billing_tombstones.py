"""삭제·환불 거래 재전송 차단용 버전형 HMAC. 원문 식별자는 저장하지 않아요."""
import hashlib
import hmac

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from config import get_settings
from shared.billing_models import BillingTombstoneModel


class TombstoneKeysMissing(RuntimeError):
    pass


def keyring() -> tuple[str, dict[str, str]]:
    settings = get_settings()
    keys = settings.billing_hmac_keys
    current = settings.billing_hmac_current_key
    if not current or current not in keys or any(len(value.encode()) < 32 for value in keys.values()):
        raise TombstoneKeysMissing('BILLING_HMAC_KEYS and BILLING_HMAC_CURRENT_KEY are required')
    return current, keys


def validate_key_versions(db: Session) -> None:
    """Retained tombstones must stay searchable across key rotation."""
    _, keys = keyring()
    retained = {row[0] for row in db.query(BillingTombstoneModel.key_version).distinct()}
    if retained - keys.keys():
        raise TombstoneKeysMissing("Retained billing HMAC key versions are missing")


def _digest(kind: str, value: str, secret: str) -> str:
    return hmac.new(secret.encode(), f'{kind}:{value}'.encode(), hashlib.sha256).hexdigest()


def find_tombstone(db: Session, kind: str, value: str) -> BillingTombstoneModel | None:
    _, keys = keyring()
    return db.query(BillingTombstoneModel).filter(
        BillingTombstoneModel.kind == kind,
        or_(*(and_(BillingTombstoneModel.key_version == version,
                   BillingTombstoneModel.digest == _digest(kind, value, secret))
              for version, secret in keys.items())),
    ).first()


def remember(db: Session, kind: str, value: str, status: str) -> BillingTombstoneModel:
    existing = find_tombstone(db, kind, value)
    if existing:
        return existing
    current, keys = keyring()
    from sqlalchemy.dialects.postgresql import insert as pg_insert
    from sqlalchemy.dialects.sqlite import insert as sqlite_insert
    insert = pg_insert if db.get_bind().dialect.name == 'postgresql' else sqlite_insert
    digest = _digest(kind, value, keys[current])
    db.execute(insert(BillingTombstoneModel).values(kind=kind, digest=digest,
        key_version=current, status=status).on_conflict_do_nothing())
    return db.get(BillingTombstoneModel, (kind, digest, current))

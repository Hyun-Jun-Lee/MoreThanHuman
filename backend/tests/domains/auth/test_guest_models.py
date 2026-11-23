from datetime import datetime, timedelta

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import (
    AccountDeletionModel,
    GuestTransferReceiptModel,
    ProfileModel,
    UserConsentModel,
)
from domains.conversation.models import GuestTurnUsageModel


def _session():
    engine = create_engine("sqlite:///:memory:")

    @event.listens_for(engine, "connect")
    def _enable_foreign_keys(dbapi_connection, _connection_record):
        dbapi_connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(bind=engine)
    return sessionmaker(bind=engine)()


def _guest(*, profile_id: str = "guest-1") -> ProfileModel:
    return ProfileModel(
        id=profile_id,
        email=None,
        name="Guest",
        is_guest=True,
        last_active_at=datetime.utcnow(),
    )


def test_guest_profile_can_own_consent_usage_and_transfer_receipt():
    db = _session()
    now = datetime.utcnow()
    guest = _guest()
    db.add(guest)
    db.flush()

    db.add_all(
        [
            UserConsentModel(
                id="consent-1",
                user_id=guest.id,
                consent_kind="ai_data_processing",
                version="2026-11-23",
                accepted_at=now,
            ),
            GuestTurnUsageModel(
                id="usage-1",
                user_id=guest.id,
                request_key="request-1",
                status="committed",
                created_at=now,
                committed_at=now,
            ),
            GuestTransferReceiptModel(
                id="receipt-1",
                guest_user_id=guest.id,
                receipt_hash="a" * 64,
                status="pending",
                created_at=now,
                expires_at=now + timedelta(minutes=10),
            ),
        ]
    )
    db.commit()

    assert db.get(ProfileModel, guest.id).email is None
    assert db.query(UserConsentModel).count() == 1
    assert db.query(GuestTurnUsageModel).count() == 1
    assert db.query(GuestTransferReceiptModel).count() == 1


def test_guest_usage_request_key_is_unique_per_user():
    db = _session()
    guest = _guest()
    db.add(guest)
    db.flush()
    now = datetime.utcnow()
    db.add(
        GuestTurnUsageModel(
            id="usage-1",
            user_id=guest.id,
            request_key="same-request",
            status="reserved",
            created_at=now,
        )
    )
    db.commit()

    db.add(
        GuestTurnUsageModel(
            id="usage-2",
            user_id=guest.id,
            request_key="same-request",
            status="reserved",
            created_at=now,
        )
    )
    with pytest.raises(IntegrityError):
        db.commit()


@pytest.mark.parametrize(
    ("model"),
    [
        lambda now: GuestTurnUsageModel(
            id="usage-invalid",
            user_id="guest-1",
            request_key="request-invalid",
            status="unknown",
            created_at=now,
        ),
        lambda now: GuestTransferReceiptModel(
            id="receipt-invalid",
            guest_user_id="guest-1",
            receipt_hash="b" * 64,
            status="unknown",
            created_at=now,
            expires_at=now + timedelta(minutes=10),
        ),
        lambda now: GuestTransferReceiptModel(
            id="receipt-expired",
            guest_user_id="guest-1",
            receipt_hash="c" * 64,
            status="pending",
            created_at=now,
            expires_at=now - timedelta(seconds=1),
        ),
    ],
)
def test_guest_ledger_and_receipt_constraints_reject_invalid_rows(model):
    db = _session()
    db.add(_guest())
    db.commit()

    db.add(model(datetime.utcnow()))
    with pytest.raises(IntegrityError):
        db.commit()


def test_profile_delete_cascades_guest_data_but_keeps_deletion_tombstone():
    db = _session()
    now = datetime.utcnow()
    guest = _guest()
    db.add(guest)
    db.flush()
    db.add_all(
        [
            UserConsentModel(
                id="consent-1",
                user_id=guest.id,
                consent_kind="privacy_policy",
                version="2026-11-23",
                accepted_at=now,
            ),
            GuestTurnUsageModel(
                id="usage-1",
                user_id=guest.id,
                request_key="request-1",
                status="reserved",
                created_at=now,
            ),
            AccountDeletionModel(
                user_id=guest.id,
                receipt_hash="d" * 64,
                status="processing",
                created_at=now,
            ),
        ]
    )
    db.commit()

    db.delete(guest)
    db.commit()

    assert db.query(UserConsentModel).count() == 0
    assert db.query(GuestTurnUsageModel).count() == 0
    assert db.query(AccountDeletionModel).count() == 1

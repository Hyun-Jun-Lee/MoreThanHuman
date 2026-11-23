from datetime import datetime, timedelta
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import (
    AccountDeletionModel,
    GuestTransferReceiptModel,
    ProfileModel,
    UserConsentModel,
)
from domains.auth.transfer import GuestTransferError, GuestTransferService
from domains.conversation.enums import ConversationType
from domains.conversation.models import ConversationModel, GuestTurnUsageModel


def _db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_claim_moves_guest_canonical_data_without_overwriting_member_profile():
    db = _db()
    guest_id, member_id, conversation_id = str(uuid4()), str(uuid4()), str(uuid4())
    now = datetime.utcnow()
    db.add_all(
        [
            ProfileModel(
                id=guest_id,
                email=None,
                name="Guest",
                is_guest=True,
                native_language="ko",
                target_language="en",
                feedback_language="ko",
            ),
            ProfileModel(
                id=member_id,
                email="member@example.com",
                name="Member",
                is_guest=False,
                native_language="en",
                target_language="ko",
                feedback_language="en",
            ),
            ConversationModel(
                id=conversation_id,
                user_id=guest_id,
                conversation_type=ConversationType.FREE_CHAT,
                slot_active=True,
            ),
            UserConsentModel(
                id=str(uuid4()),
                user_id=guest_id,
                consent_kind="privacy_policy",
                version="2026-11-23",
                accepted_at=now,
            ),
            GuestTurnUsageModel(
                id=str(uuid4()),
                user_id=guest_id,
                request_key=str(uuid4()),
                conversation_id=conversation_id,
                status="committed",
                created_at=now,
                committed_at=now,
            ),
        ]
    )
    db.commit()
    service = GuestTransferService(db)
    receipt, _ = service.issue(guest_id)

    member, transferred_guest_id = service.claim(member_id, receipt)

    assert transferred_guest_id == guest_id
    assert member.native_language == "en"
    assert member.target_language == "ko"
    conversation = db.get(ConversationModel, conversation_id)
    assert conversation.user_id == member_id
    assert conversation.slot_active is True
    assert member.slot_limit_snapshot == 1
    assert db.query(UserConsentModel).filter_by(user_id=member_id).count() == 1
    assert db.query(GuestTurnUsageModel).filter_by(user_id=member_id).count() == 1
    assert db.get(ProfileModel, guest_id).is_active is False
    assert db.get(AccountDeletionModel, guest_id).status == "processing"
    with pytest.raises(GuestTransferError, match="already used"):
        service.claim(member_id, receipt)


def test_expired_receipt_cannot_be_claimed():
    db = _db()
    guest_id, member_id = str(uuid4()), str(uuid4())
    db.add_all(
        [
            ProfileModel(id=guest_id, email=None, name="Guest", is_guest=True),
            ProfileModel(
                id=member_id,
                email="member@example.com",
                name="Member",
                is_guest=False,
            ),
        ]
    )
    db.commit()
    service = GuestTransferService(db)
    receipt, _ = service.issue(guest_id)
    transfer = db.query(GuestTransferReceiptModel).filter_by(status="pending").one()
    transfer.created_at = datetime.utcnow() - timedelta(minutes=2)
    transfer.expires_at = datetime.utcnow() - timedelta(seconds=1)
    db.commit()

    with pytest.raises(GuestTransferError, match="expired"):
        service.claim(member_id, receipt)

    assert transfer.status == "expired"

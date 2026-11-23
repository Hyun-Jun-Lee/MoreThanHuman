from datetime import datetime, timedelta
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.models import AccountDeletionModel, ProfileModel
from scripts import cleanup_inactive_guests


def test_cleanup_candidates_recheck_activity_before_start(monkeypatch):
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine)
    monkeypatch.setattr(cleanup_inactive_guests, "SessionLocal", sessions)
    now = datetime.utcnow()
    cutoff = now - timedelta(days=30)
    stale_id, boundary_id, recent_id, member_id = (
        str(uuid4()),
        str(uuid4()),
        str(uuid4()),
        str(uuid4()),
    )
    with sessions() as db:
        db.add_all(
            [
                ProfileModel(
                    id=stale_id,
                    name="Stale guest",
                    is_guest=True,
                    last_active_at=cutoff - timedelta(seconds=1),
                ),
                ProfileModel(
                    id=boundary_id,
                    name="Boundary guest",
                    is_guest=True,
                    last_active_at=cutoff,
                ),
                ProfileModel(
                    id=recent_id,
                    name="Recent guest",
                    is_guest=True,
                    last_active_at=cutoff + timedelta(seconds=1),
                ),
                ProfileModel(
                    id=member_id,
                    email="member@example.com",
                    name="Member",
                    is_guest=False,
                    last_active_at=cutoff - timedelta(days=1),
                ),
            ]
        )
        db.commit()

    assert set(cleanup_inactive_guests.candidate_ids(cutoff)) == {
        stale_id,
        boundary_id,
    }
    with sessions() as db:
        db.get(ProfileModel, stale_id).last_active_at = now
        db.commit()

    assert cleanup_inactive_guests.start_if_still_inactive(stale_id, cutoff) is False
    assert cleanup_inactive_guests.start_if_still_inactive(boundary_id, cutoff) is True
    with sessions() as db:
        assert db.get(AccountDeletionModel, boundary_id).status == "processing"

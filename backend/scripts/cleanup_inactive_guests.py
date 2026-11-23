"""30일 이상 활동하지 않은 미전환 게스트를 기존 계정 삭제 흐름으로 정리해요."""

import asyncio
import logging
from datetime import datetime, timedelta

import httpx

from config import get_settings
from database import SessionLocal
from domains.auth.deletion import AccountDeletionService, DeletionAlreadyStarted
from domains.auth.models import ProfileModel


def candidate_ids(cutoff: datetime) -> list[str]:
    with SessionLocal() as db:
        return [
            user_id
            for (user_id,) in db.query(ProfileModel.id)
            .filter(
                ProfileModel.is_guest.is_(True),
                ProfileModel.is_active.is_(True),
                ProfileModel.last_active_at <= cutoff,
            )
            .all()
        ]


def start_if_still_inactive(user_id: str, cutoff: datetime) -> bool:
    with SessionLocal() as db:
        profile = (
            db.query(ProfileModel)
            .filter(
                ProfileModel.id == user_id,
                ProfileModel.is_guest.is_(True),
                ProfileModel.is_active.is_(True),
                ProfileModel.last_active_at <= cutoff,
            )
            .with_for_update()
            .one_or_none()
        )
        if profile is None:
            db.rollback()
            return False
        try:
            AccountDeletionService(db, None).start(user_id)
        except DeletionAlreadyStarted:
            return False
        return True


async def cleanup(*, now: datetime | None = None) -> tuple[int, int]:
    settings = get_settings()
    cutoff = (now or datetime.utcnow()) - timedelta(days=settings.guest_retention_days)
    started = completed = 0
    async with httpx.AsyncClient() as client:
        for user_id in candidate_ids(cutoff):
            if not start_if_still_inactive(user_id, cutoff):
                continue
            started += 1
            try:
                with SessionLocal() as db:
                    await AccountDeletionService(db, client).process(user_id)
                completed += 1
            except Exception:
                logging.exception("Inactive guest deletion requires retry")
    return started, completed


async def main() -> None:
    started, completed = await cleanup()
    print(
        f"inactive_guest_deletions_started={started} "
        f"inactive_guest_deletions_completed={completed}"
    )


if __name__ == "__main__":
    asyncio.run(main())

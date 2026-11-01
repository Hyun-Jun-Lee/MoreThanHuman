"""Run periodically to finish deletion requests blocked by transient failures."""

import asyncio
import logging

import httpx

from database import SessionLocal
from domains.auth.deletion import AccountDeletionService
from domains.auth.models import AccountDeletionModel


async def main() -> None:
    async with httpx.AsyncClient() as client:
        with SessionLocal() as db:
            ids = [row[0] for row in db.query(AccountDeletionModel.user_id)
                   .filter_by(status="processing").all()]
        for user_id in ids:
            try:
                with SessionLocal() as db:
                    await AccountDeletionService(db, client).process(user_id)
            except Exception:
                logging.exception("Account deletion retry failed")


if __name__ == "__main__":
    asyncio.run(main())

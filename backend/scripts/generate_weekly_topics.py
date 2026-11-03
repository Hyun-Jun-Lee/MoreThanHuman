"""언어쌍별 주간 추천 주제를 수동 생성해요. python -m scripts.generate_weekly_topics"""

import argparse
import asyncio
import json

from config import get_settings
from database import SessionLocal
from domains.conversation.topic_generation_service import TopicPublicationError, WeeklyTopicGenerator, weekly_slot
from domains.conversation.topic_repository import WeeklyTopicRepository
from shared.http_clients import create_http_client


async def run(pair: str, slot: str | None = None, *, republish: bool = False) -> int:
    results = []
    pairs = {"ko-en": ("ko", "en"), "en-ko": ("en", "ko")}
    async with create_http_client(get_settings()) as client:
        for key in pairs if pair == "all" else (pair,):
            with SessionLocal() as db:
                try:
                    result = await WeeklyTopicGenerator(WeeklyTopicRepository(db), client).generate(
                        *pairs[key], week_start=slot or weekly_slot(), republish=republish
                    )
                except TopicPublicationError as error:
                    db.rollback()
                    result = {"status": "failed", "error": error.code, **error.counts}
                except Exception:
                    db.rollback()
                    result = {"status": "failed", "error": "generation_failed"}
                results.append({"pair": key, **result})
    print(json.dumps(results, ensure_ascii=False))
    return 1 if any(result["status"] == "failed" for result in results) else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pair", choices=("ko-en", "en-ko", "all"), default="all")
    parser.add_argument("--week-start", help="YYYY-MM-DD slot; default is current Seoul week")
    parser.add_argument("--republish", action="store_true", help="replace an existing week's active topics while preserving their IDs")
    args = parser.parse_args()
    return asyncio.run(run(args.pair, args.week_start, republish=args.republish))


if __name__ == "__main__":
    raise SystemExit(main())

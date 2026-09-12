"""주간 언어 스낵 생성. python -m scripts.generate_language_snacks."""

import argparse
import asyncio
import json
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from config import get_settings
from database import SessionLocal
from domains.language_snacks.generation_service import SnackGenerator
from domains.language_snacks.lock import SnackError
from domains.language_snacks.repository import LanguageSnackRepository


def weekly_slot(now=None):
    now = (now or datetime.now(ZoneInfo("Asia/Seoul"))).astimezone(
        ZoneInfo("Asia/Seoul")
    )
    start = (now - timedelta(days=now.weekday())).replace(
        hour=5, minute=0, second=0, microsecond=0
    )
    if now < start:
        start -= timedelta(days=7)
    return start.strftime("%Y-%m-%d")


async def run(args):
    results = []
    for language in ("en", "ko") if args.language == "all" else (args.language,):
        with SessionLocal() as db:
            try:
                generator = SnackGenerator(LanguageSnackRepository(db))
                result = await generator.generate(
                    f"{args.run_key or 'weekly:' + weekly_slot()}:{language}",
                    language,
                    args.per_type,
                    args.dry_run,
                )
            except SnackError as error:
                result = {
                    "status": "skipped"
                    if error.code == "generation_busy"
                    else "failed",
                    "error": error.code,
                }
            except Exception:  # noqa: BLE001 - CLI 로그에 provider 원문을 노출하지 않아요.
                # provider 예외의 body에는 비밀 값이나 원문이 포함될 수 있어요.
                result = {"status": "failed", "error": "generation_unavailable"}
            results.append({"language": language, **result})
    print(json.dumps(results, ensure_ascii=False))
    return 1 if any(item["status"] in ("failed", "partial") for item in results) else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", choices=("en", "ko", "all"), default="all")
    parser.add_argument(
        "--per-type",
        type=int,
        choices=range(1, 7),
        default=get_settings().language_snacks_per_type,
    )
    parser.add_argument(
        "--run-key", help="Same key resumes the same run; omit for current weekly slot."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="LLM candidate preview; no DB writes, still consumes LLM usage.",
    )
    return asyncio.run(run(parser.parse_args()))


if __name__ == "__main__":
    raise SystemExit(main())

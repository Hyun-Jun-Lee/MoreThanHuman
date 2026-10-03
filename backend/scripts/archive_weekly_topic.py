"""문제 주제를 보관해 노출과 새 대화 시작을 막아요."""

import argparse
from uuid import UUID

from database import SessionLocal
from domains.conversation.topic_repository import WeeklyTopicRepository


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("topic_id", type=UUID)
    args = parser.parse_args()
    with SessionLocal() as db:
        found = WeeklyTopicRepository(db).archive(str(args.topic_id))
    print("archived" if found else "not_found")
    return 0 if found else 1


if __name__ == "__main__":
    raise SystemExit(main())

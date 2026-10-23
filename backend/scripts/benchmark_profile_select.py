"""같은 DB 연결에서 왕복 기준선과 프로필 조회를 비교해요.

실행: cd backend && .venv/bin/python scripts/benchmark_profile_select.py --samples 10
선택: --profile-id <개발 계정의 프로필 ID>
프로필 값, 연결 문자열, SQL 매개변수는 출력하지 않아요.
"""

import argparse
import json
import math
import statistics
import sys
from pathlib import Path
from time import perf_counter

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Connection
from sqlalchemy.exc import SQLAlchemyError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from config import get_settings


PROFILE_SQL = text("SELECT * FROM profiles WHERE id = :profile_id LIMIT 1")
BASELINE_SQL = text("SELECT 1")
EXPLAIN_SQL = text(
    "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "
    "SELECT * FROM profiles WHERE id = :profile_id LIMIT 1"
)


def measure(connection: Connection, profile_id: str, *, profile_first: bool) -> tuple[float, float]:
    """한 연결에서 두 SELECT를 수행하고 실행·결과 수신 시간을 재요."""
    def baseline() -> float:
        started = perf_counter()
        connection.execute(BASELINE_SQL).scalar_one()
        return (perf_counter() - started) * 1000

    def profile() -> float:
        started = perf_counter()
        row = connection.execute(PROFILE_SQL, {"profile_id": profile_id}).first()
        duration_ms = (perf_counter() - started) * 1000
        if row is None:
            raise ValueError("지정한 프로필을 찾을 수 없어요.")
        return duration_ms

    if profile_first:
        profile_ms = profile()
        baseline_ms = baseline()
    else:
        baseline_ms = baseline()
        profile_ms = profile()
    return baseline_ms, profile_ms


def summarize(samples: list[float]) -> str:
    ordered = sorted(samples)
    p95 = ordered[math.ceil(len(ordered) * 0.95) - 1]
    return f"median={statistics.median(ordered):.1f} p95={p95:.1f} min={ordered[0]:.1f} max={ordered[-1]:.1f} ms"


def server_plan(connection: Connection, profile_id: str) -> tuple[float, float, str]:
    """PostgreSQL 서버 안에서 측정한 계획·실행 시간만 추출해요."""
    raw = connection.execute(EXPLAIN_SQL, {"profile_id": profile_id}).scalar_one()
    payload = json.loads(raw) if isinstance(raw, str) else raw
    plan = payload[0]
    root = plan["Plan"]
    child = root.get("Plans", [root])[0]
    return float(plan["Planning Time"]), float(plan["Execution Time"]), str(child["Node Type"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=10)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--profile-id", help="생략하면 profiles의 첫 ID를 사용해요. ID는 출력하지 않아요.")
    args = parser.parse_args()
    if not 1 <= args.samples <= 100 or not 0 <= args.warmup <= 20:
        parser.error("samples는 1~100, warmup은 0~20이어야 해요.")

    database_url = get_settings().database_url
    if not database_url:
        parser.exit(1, "DATABASE_URL이 필요해요.\n")
    engine = create_engine(database_url)
    try:
        with engine.connect() as connection:
            profile_id = args.profile_id or connection.execute(text("SELECT id FROM profiles LIMIT 1")).scalar_one_or_none()
        if profile_id is None:
            parser.exit(1, "측정할 프로필이 없어요.\n")

        baseline_samples: list[float] = []
        profile_samples: list[float] = []
        for index in range(-args.warmup, args.samples):
            with engine.connect() as connection:
                baseline_ms, profile_ms = measure(connection, profile_id, profile_first=index % 2 == 0)
            if index >= 0:
                baseline_samples.append(baseline_ms)
                profile_samples.append(profile_ms)

        print(f"same pooled DB connection | warmup={args.warmup} samples={args.samples}")
        print(f"SELECT 1 client elapsed: {summarize(baseline_samples)}")
        print(f"profile SELECT client elapsed: {summarize(profile_samples)}")
        print(f"paired difference: {summarize([p - b for b, p in zip(baseline_samples, profile_samples)])}")
        if engine.dialect.name == "postgresql":
            with engine.connect() as connection:
                planning_ms, execution_ms, node_type = server_plan(connection, profile_id)
            print(f"PostgreSQL EXPLAIN: planning={planning_ms:.2f} execution={execution_ms:.2f} ms, access={node_type}")
            print("EXPLAIN은 별도 실행 1회의 서버 시간이며 네트워크 왕복을 포함하지 않아요.")
        else:
            print("서버 실행 계획 계측은 PostgreSQL 연결에서만 제공해요.")
    except SQLAlchemyError as exc:
        parser.exit(1, f"DB 계측에 실패했어요: {type(exc).__name__}\n")
    finally:
        engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

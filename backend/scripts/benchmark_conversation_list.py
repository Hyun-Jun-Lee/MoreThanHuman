"""키체인의 개발 계정으로 로컬 대화 목록 API 지연을 측정해요."""

import argparse
import math
import statistics
import subprocess
from dataclasses import dataclass
from time import perf_counter
from urllib.parse import urlsplit
from uuid import uuid4

import httpx


KEYCHAIN_SERVICE = "tomatalk-supabase-test-password"


class BenchmarkError(Exception):
    """비밀값을 포함하지 않는 측정 오류예요."""


@dataclass(frozen=True)
class Sample:
    number: int
    duration_ms: float
    request_id: str


def read_password(email: str) -> str:
    """키체인 항목의 비밀번호를 프로세스 메모리로만 읽어요."""
    try:
        result = subprocess.run(
            ["security", "find-generic-password", "-a", email, "-s", KEYCHAIN_SERVICE, "-w"],
            capture_output=True,
            text=True,
            check=True,
            timeout=15,
        )
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
        raise BenchmarkError("키체인에서 개발 계정 비밀번호를 읽지 못했어요.") from exc
    password = result.stdout.rstrip("\r\n")
    if not password:
        raise BenchmarkError("키체인에 저장된 개발 계정 비밀번호가 비어 있어요.")
    return password


def validate_base_url(base_url: str) -> str:
    try:
        parsed = urlsplit(base_url)
        hostname = parsed.hostname
        port = parsed.port
    except ValueError as exc:
        raise BenchmarkError("측정 주소 형식이 올바르지 않아요.") from exc
    if (
        parsed.scheme != "http"
        or hostname not in {"127.0.0.1", "localhost", "::1"}
        or port is None
        or parsed.username is not None
        or parsed.password is not None
        or parsed.path not in {"", "/"}
        or parsed.query
        or parsed.fragment
    ):
        raise BenchmarkError("측정 주소는 로컬 HTTP 서버의 기본 URL이어야 해요.")
    return base_url.rstrip("/")


def issue_token(client: httpx.Client, email: str, password: str) -> str:
    try:
        response = client.post(
            "/api/auth/swagger/token",
            json={"email": email, "password": password},
        )
    except httpx.HTTPError as exc:
        raise BenchmarkError("개발 계정 토큰 발급 요청에 실패했어요.") from exc
    if response.status_code != 200:
        raise BenchmarkError(f"개발 계정 토큰 발급이 HTTP {response.status_code}로 실패했어요.")
    try:
        token = response.json()["data"]["access_token"]
    except (ValueError, KeyError, TypeError) as exc:
        raise BenchmarkError("토큰 발급 응답 형식이 예상과 달라요.") from exc
    if not isinstance(token, str) or not token:
        raise BenchmarkError("토큰 발급 응답에 access token이 없어요.")
    return token


def run_benchmark(
    client: httpx.Client,
    token: str,
    *,
    samples: int,
    warmup: int,
    limit: int | None = None,
    offset: int | None = None,
) -> list[Sample]:
    params = {key: value for key, value in {"limit": limit, "offset": offset}.items() if value is not None}
    results: list[Sample] = []
    for index in range(-warmup, samples):
        request_id = uuid4().hex
        try:
            started = perf_counter()
            response = client.get(
                "/api/conversations/",
                params=params,
                headers={"Authorization": f"Bearer {token}", "X-Request-ID": request_id},
            )
            duration_ms = (perf_counter() - started) * 1000
        except httpx.HTTPError as exc:
            raise BenchmarkError(f"목록 요청 {max(index + 1, 0)}의 연결에 실패했어요.") from exc
        if response.status_code != 200:
            raise BenchmarkError(
                f"목록 요청 {max(index + 1, 0)}이 HTTP {response.status_code}로 실패했어요. "
                f"X-Request-ID={request_id}"
            )
        if index >= 0:
            results.append(Sample(index + 1, duration_ms, request_id))
    return results


def print_report(results: list[Sample], warmup: int) -> None:
    times = sorted(item.duration_ms for item in results)
    p95 = times[math.ceil(len(times) * 0.95) - 1]
    print(f"GET /api/conversations/ | warmup={warmup} samples={len(results)}")
    print(
        f"client_ms: min={times[0]:.1f} median={statistics.median(times):.1f} "
        f"p95={p95:.1f} max={times[-1]:.1f}"
    )
    print("slowest requests (client_ms, X-Request-ID):")
    for item in sorted(results, key=lambda sample: sample.duration_ms, reverse=True)[:5]:
        print(f"  #{item.number}: {item.duration_ms:.1f} {item.request_id}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True, help="Supabase 이메일·비밀번호 개발 계정")
    parser.add_argument("--base-url", default="http://127.0.0.1:8010")
    parser.add_argument("--samples", type=int, default=20)
    parser.add_argument("--warmup", type=int, default=2)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--offset", type=int)
    args = parser.parse_args()

    if not 1 <= args.samples <= 200 or not 0 <= args.warmup <= 20:
        parser.error("samples는 1~200, warmup은 0~20이어야 해요.")
    if args.limit is not None and not 1 <= args.limit <= 100:
        parser.error("limit은 1~100이어야 해요.")
    if args.offset is not None and args.offset < 0:
        parser.error("offset은 0 이상이어야 해요.")

    try:
        base_url = validate_base_url(args.base_url)
        password = read_password(args.email)
        with httpx.Client(base_url=base_url, timeout=30, trust_env=False) as client:
            token = issue_token(client, args.email, password)
            del password
            results = run_benchmark(
                client, token, samples=args.samples, warmup=args.warmup,
                limit=args.limit, offset=args.offset,
            )
        print_report(results, args.warmup)
    except BenchmarkError as exc:
        parser.exit(1, f"측정 실패: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

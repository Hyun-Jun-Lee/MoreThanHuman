"""로컬 개발 계정으로 홈·주제 준비·대화 스트림·재진입 API 지연을 측정해요."""

import argparse
import json
import math
import statistics
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from time import perf_counter
from uuid import UUID, uuid4

import httpx

from scripts.benchmark_conversation_list import (
    BenchmarkError,
    issue_token,
    read_password,
    validate_base_url,
)


HOME_REQUESTS = {
    "recent": ("/api/conversations/", {"limit": 5, "offset": 0}),
    "weekly_topics": ("/api/conversation-topics/weekly/", None),
    "snacks": ("/api/v2/language-snacks/", {"order": "random", "limit": 12}),
    "basket_reset": ("/api/v2/language-snacks/basket-reset/", None),
}


@dataclass(frozen=True)
class TimedRequest:
    duration_ms: float
    request_id: str
    data: object


@dataclass(frozen=True)
class FlowSample:
    number: int
    timings: dict[str, float | None]
    request_ids: dict[str, str]
    metadata: dict[str, str | int | bool] = field(default_factory=dict)


def _headers(token: str, request_id: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}", "X-Request-ID": request_id}


def _request_json(
    client: httpx.Client,
    token: str,
    label: str,
    path: str,
    *,
    method: str = "GET",
    params: dict | None = None,
    payload: dict | None = None,
) -> TimedRequest:
    request_id = uuid4().hex
    started = perf_counter()
    try:
        response = client.request(
            method, path, params=params, json=payload,
            headers=_headers(token, request_id),
        )
    except httpx.HTTPError as exc:
        raise BenchmarkError(f"{label} 연결 실패. X-Request-ID={request_id}") from exc
    duration_ms = (perf_counter() - started) * 1000
    if response.status_code != 200:
        raise BenchmarkError(
            f"{label} HTTP {response.status_code}. X-Request-ID={request_id}"
        )
    try:
        body = response.json()
        if not isinstance(body, dict) or body.get("success") is not True or "data" not in body:
            raise ValueError
    except ValueError as exc:
        raise BenchmarkError(f"{label} 응답 형식 오류. X-Request-ID={request_id}") from exc
    return TimedRequest(duration_ms, request_id, body["data"])


def _home(client: httpx.Client, token: str, number: int) -> FlowSample:
    started = perf_counter()
    profile = _request_json(client, token, "profile", "/api/auth/me")
    with ThreadPoolExecutor(max_workers=len(HOME_REQUESTS)) as pool:
        pending = {
            name: pool.submit(_request_json, client, token, name, path, params=params)
            for name, (path, params) in HOME_REQUESTS.items()
        }
        results = {name: future.result() for name, future in pending.items()}
    return FlowSample(
        number,
        {"flow_total": (perf_counter() - started) * 1000,
         "profile": profile.duration_ms,
         **{name: item.duration_ms for name, item in results.items()}},
        {"profile": profile.request_id,
         **{name: item.request_id for name, item in results.items()}},
    )


def _topic_prep(client: httpx.Client, token: str, number: int, topic: str) -> FlowSample:
    item = _request_json(
        client, token, "topic_prep", "/api/search/topic-prep/",
        method="POST", payload={"topic": topic},
    )
    if not isinstance(item.data, dict) or not isinstance(item.data.get("ready"), bool):
        raise BenchmarkError(f"topic_prep 결과 형식 오류. X-Request-ID={item.request_id}")
    return FlowSample(
        number, {"topic_prep": item.duration_ms}, {"topic_prep": item.request_id},
        {"ready": item.data["ready"]},
    )


def _messages(client: httpx.Client, token: str, number: int, conversation_id: str) -> FlowSample:
    base = f"/api/conversations/{conversation_id}"
    started = perf_counter()
    first = _request_json(
        client, token, "messages_first", f"{base}/messages/",
        params={"limit": 40, "offset": 0},
    )
    if not isinstance(first.data, dict) or not isinstance(first.data.get("pagination"), dict):
        raise BenchmarkError(f"messages_first 페이지 형식 오류. X-Request-ID={first.request_id}")
    count = first.data["pagination"].get("total_count")
    if not isinstance(count, int) or count < 0:
        raise BenchmarkError(f"messages_first 전체 개수 오류. X-Request-ID={first.request_id}")
    timings: dict[str, float | None] = {"messages_first": first.duration_ms, "messages_latest": None}
    ids = {"messages_first": first.request_id}
    if count > 40:
        latest = _request_json(
            client, token, "messages_latest", f"{base}/messages/",
            params={"limit": 40, "offset": count - 40},
        )
        timings["messages_latest"] = latest.duration_ms
        ids["messages_latest"] = latest.request_id
    turns = _request_json(client, token, "turns", f"{base}/turns/")
    access = _request_json(client, token, "access", f"{base}/access/")
    timings.update({"turns": turns.duration_ms, "access": access.duration_ms,
                    "flow_total": (perf_counter() - started) * 1000})
    ids.update({"turns": turns.request_id, "access": access.request_id})
    return FlowSample(number, timings, ids, {"total_messages": count})


def _stream_payload(args: argparse.Namespace, request_key: str) -> tuple[str, dict]:
    if args.kind == "free-chat":
        return "/api/conversations/start/free-chat/stream/", {"first_message": args.text}
    if args.kind == "roleplay":
        return "/api/conversations/start/roleplay/stream/", {"role_character": args.role_character}
    if args.kind == "suggested":
        return "/api/conversations/start/free-chat/suggested/stream/", {
            "topic_id": args.topic_id, "start_request_id": request_key,
        }
    return f"/api/conversations/{args.conversation_id}/turn/stream/", {"text": args.text}


def _stream(client: httpx.Client, token: str, number: int, args: argparse.Namespace) -> FlowSample:
    request_id = uuid4().hex
    request_key = str(uuid4())
    path, payload = _stream_payload(args, request_key)
    started = perf_counter()
    timings: dict[str, float | None] = {
        "headers": None, "first_text": None, "first_audio": None, "completed": None,
    }
    audio_status = "unknown"
    try:
        with client.stream(
            "POST", path, json=payload,
            headers={**_headers(token, request_id), "Idempotency-Key": request_key,
                     "Accept": "application/x-ndjson"},
        ) as response:
            timings["headers"] = (perf_counter() - started) * 1000
            if response.status_code != 200:
                raise BenchmarkError(
                    f"stream HTTP {response.status_code}. X-Request-ID={request_id}"
                )
            if not response.headers.get("content-type", "").startswith("application/x-ndjson"):
                raise BenchmarkError(f"stream 응답 타입 오류. X-Request-ID={request_id}")
            completed = False
            for line in response.iter_lines():
                if not line:
                    continue
                try:
                    event = json.loads(line)
                    name = event["event"]
                except (ValueError, KeyError, TypeError) as exc:
                    raise BenchmarkError(f"stream 이벤트 형식 오류. X-Request-ID={request_id}") from exc
                elapsed = (perf_counter() - started) * 1000
                if name == "text_delta" and timings["first_text"] is None:
                    timings["first_text"] = elapsed
                elif name == "audio_segment" and timings["first_audio"] is None:
                    timings["first_audio"] = elapsed
                elif name == "turn_error":
                    raise BenchmarkError(f"stream turn_error. X-Request-ID={request_id}")
                elif name == "turn_completed":
                    timings["completed"] = elapsed
                    if isinstance(event.get("audio_status"), str):
                        audio_status = event["audio_status"]
                    completed = True
            if not completed:
                raise BenchmarkError(f"stream 완료 이벤트 누락. X-Request-ID={request_id}")
    except httpx.HTTPError as exc:
        raise BenchmarkError(f"stream 연결 실패. X-Request-ID={request_id}") from exc
    timings["http_total"] = (perf_counter() - started) * 1000
    return FlowSample(number, timings, {"stream": request_id}, {"audio_status": audio_status})


def run_benchmark(client: httpx.Client, token: str, args: argparse.Namespace) -> list[FlowSample]:
    results: list[FlowSample] = []
    for index in range(-args.warmup, args.samples):
        number = index + 1 if index >= 0 else 0
        if args.flow == "home":
            sample = _home(client, token, number)
        elif args.flow == "topic-prep":
            sample = _topic_prep(client, token, number, args.topic)
        elif args.flow == "messages":
            sample = _messages(client, token, number, args.conversation_id)
        else:
            sample = _stream(client, token, number, args)
        if index >= 0:
            results.append(sample)
    return results


def print_report(flow: str, samples: list[FlowSample], warmup: int) -> None:
    print(f"{flow} | warmup={warmup} samples={len(samples)}")
    for label in samples[0].timings:
        times = sorted(
            value for sample in samples
            if (value := sample.timings.get(label)) is not None
        )
        if not times:
            print(f"{label}: n=0")
            continue
        p95 = times[math.ceil(len(times) * 0.95) - 1]
        print(
            f"{label}_ms: n={len(times)} min={times[0]:.1f} "
            f"median={statistics.median(times):.1f} p95={p95:.1f} max={times[-1]:.1f}"
        )
    print("samples (ms; X-Request-ID):")
    for sample in samples:
        details = " ".join(
            f"{label}={value:.1f}" if value is not None else f"{label}=-"
            for label, value in sample.timings.items()
        )
        ids = " ".join(f"{label}:{request_id}" for label, request_id in sample.request_ids.items())
        metadata = " ".join(f"{key}={value}" for key, value in sample.metadata.items())
        print(f"  #{sample.number} {details} | {ids}{f' | {metadata}' if metadata else ''}")


def _uuid(value: str) -> str:
    try:
        return str(UUID(value))
    except ValueError as exc:
        raise argparse.ArgumentTypeError("UUID 형식이어야 해요.") from exc


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--email", required=True, help="키체인에 등록한 Supabase 개발 계정")
    parser.add_argument("--base-url", default="http://127.0.0.1:8010")
    subparsers = parser.add_subparsers(dest="flow", required=True)
    for name in ("home", "topic-prep", "stream", "messages"):
        sub = subparsers.add_parser(name)
        costly = name in {"topic-prep", "stream"}
        sub.add_argument("--samples", type=int, default=1 if costly else 10)
        sub.add_argument("--warmup", type=int, default=0 if costly else 1)
        if name == "topic-prep":
            sub.add_argument("--topic", required=True)
            sub.add_argument("--allow-cost", action="store_true")
        elif name == "stream":
            sub.add_argument("--kind", choices=("free-chat", "roleplay", "suggested", "turn"), required=True)
            sub.add_argument("--text")
            sub.add_argument("--role-character")
            sub.add_argument("--topic-id", type=_uuid)
            sub.add_argument("--conversation-id", type=_uuid)
            sub.add_argument("--allow-writes", action="store_true")
        elif name == "messages":
            sub.add_argument("--conversation-id", type=_uuid, required=True)
    return parser


def _validate_args(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    costly = args.flow in {"topic-prep", "stream"}
    if not 1 <= args.samples <= (30 if costly else 200):
        parser.error("samples 범위를 확인해요 (조회 1~200, 외부 호출 1~30).")
    if not 0 <= args.warmup <= (5 if costly else 20):
        parser.error("warmup 범위를 확인해요 (조회 0~20, 외부 호출 0~5).")
    if args.flow == "topic-prep":
        if not args.topic.strip() or not args.allow_cost:
            parser.error("주제 준비에는 --topic과 --allow-cost가 필요해요.")
    if args.flow == "stream":
        if not args.allow_writes:
            parser.error("스트림 측정에는 --allow-writes가 필요해요.")
        required = {
            "free-chat": ("text",),
            "roleplay": ("role_character",),
            "suggested": ("topic_id",),
            "turn": ("conversation_id", "text"),
        }[args.kind]
        if any(not getattr(args, field) for field in required):
            parser.error(f"{args.kind} 측정에 필요한 입력이 없어요.")


def main() -> int:
    parser = _parser()
    args = parser.parse_args()
    _validate_args(parser, args)
    try:
        base_url = validate_base_url(args.base_url)
        password = read_password(args.email)
        with httpx.Client(base_url=base_url, timeout=360, trust_env=False) as client:
            token = issue_token(client, args.email, password)
            del password
            results = run_benchmark(client, token, args)
        print_report(args.flow, results, args.warmup)
    except BenchmarkError as exc:
        parser.exit(1, f"측정 실패: {exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

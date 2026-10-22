"""SearXNG JSON 검색을 간단히 시험해요.

저장소 루트에서 실행 예시:
    python backend/scripts/test_searxng.py "coffee culture in Seoul"
    python backend/scripts/test_searxng.py "AI news" --url http://localhost:8888
"""

import argparse
import json
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


def main() -> int:
    parser = argparse.ArgumentParser(description="SearXNG 검색 결과와 응답 시간을 확인해요.")
    parser.add_argument("query", help="검색어 (공백이 있으면 따옴표로 감싸세요)")
    parser.add_argument("--url", default="http://127.0.0.1:8080", help="SearXNG 주소")
    parser.add_argument("--limit", type=int, default=6, help="표시할 결과 수 (기본 6)")
    parser.add_argument("--timeout", type=float, default=10.0, help="요청 제한 시간, 초 (기본 10)")
    args = parser.parse_args()

    if args.limit < 1 or args.timeout <= 0:
        parser.error("--limit과 --timeout은 0보다 커야 해요.")

    endpoint = f"{args.url.rstrip('/')}/search?{urlencode({'q': args.query, 'format': 'json'})}"
    started = time.perf_counter()
    try:
        with urlopen(Request(endpoint, headers={"Accept": "application/json"}), timeout=args.timeout) as response:
            payload = json.load(response)
    except HTTPError as exc:
        detail = " (인스턴스에서 JSON 형식을 활성화해야 해요)" if exc.code == 403 else ""
        print(f"HTTP {exc.code}{detail}", file=sys.stderr)
        return 1
    except (URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"검색 요청 실패: {exc}", file=sys.stderr)
        return 1

    elapsed = time.perf_counter() - started
    results = payload.get("results", [])
    print(f"검색어: {args.query}")
    print(f"응답 시간: {elapsed:.3f}초 | 결과: {len(results)}개 | 표시: {min(len(results), args.limit)}개")
    for index, result in enumerate(results[: args.limit], start=1):
        print(f"\n{index}. {result.get('title', '(제목 없음)')}")
        print(f"   {result.get('url', '(URL 없음)')}")
        if content := result.get("content"):
            print(f"   {content}")
        if engine := result.get("engine"):
            print(f"   엔진: {engine}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

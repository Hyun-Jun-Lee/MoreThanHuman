# Topic Prep 검색 결정 계약

> Status: ACTIVE · Updated: 2026-10-23

## 판정

- `POST /api/search/topic-prep/`는 기존 검색어 분석 LLM 응답의 `search_required: bool`을 사용해요.
- 명시적인 최신성, 결과, 일정, 가격, 맛집 요청은 코드 규칙이 검색을 강제해요.
- LLM 응답이 없거나 `search_required`가 JSON Boolean이 아니면 검색해요.
- 일반 검색 API `POST /api/search/`는 항상 검색해요.

## Topic Prep 응답

- `data.search_required=true`: 웹 검색과 출처 품질 판정을 거쳐요. 출처가 부족하면 `ready=false`예요.
- `data.search_required=false`: 웹 검색과 출처 판정을 생략하고 주제로 카드를 생성해요. `card.sources=[]`, `quality.source_count=0`, `quality.has_enough_sources=false`일 수 있으며, 완전한 카드이면 `ready=true`예요.
- 카드의 요약, 방향 세 개, 각 방향의 질문 세 개가 완전하지 않으면 두 경로 모두 `ready=false`예요.
- 직접 입력 질문과 방향 재생성은 주제만 사용하고 검색을 다시 호출하지 않아요.

## 단계별 스트림 측정

- `POST /api/search/topic-prep/stream/`은 기존 Topic Prep 판정과 품질 기준을 그대로 사용하고 NDJSON을 반환해요.
- `summary_ready`는 카드 생성 LLM의 `quality.is_sufficient=true`와 완성된 `summary`를 확인한 뒤 한 번만 보냅니다. 방향·질문이 완성되기 전의 잠정 값이에요.
- `card_ready`는 전체 카드가 검증된 `TopicPrepResult`를 담아요. 낮은 품질 결과도 이 이벤트로 전달해요.
- 스트림 시작 후 실패하면 `error` 이벤트로 종료해요. 부분 실패에 대한 별도 재시도는 이 단계에서 제공하지 않아요.
- 서버는 요청 시작 기준 `summary_ready`와 `card_ready` 시각을 같은 trace_id로 기록해요. 클라이언트도 두 이벤트 수신 시각을 기록해요.

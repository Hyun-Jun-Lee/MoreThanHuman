# Conversation/Message Pagination 메타 도입 계획

> 범위: FastAPI 백엔드 API · 최종 갱신: 2026-05-26

## 0. 결정 완료(사용자 확정)

- Conversation 목록 정렬: `updated_at desc`
- Message 목록: “최신이 아래로 쌓여서 가장 먼저 보이게” (API 기본 정렬은 `created_at asc` 유지 권장)
- `next_offset`: `offset + len(results)`
- `total_count`: 정확 count(`COUNT(*)`)
- `limit` 상한: 최대 100
- 권한/소유권 체크: 이번 작업 범위에서는 고려하지 않음
- 응답 구조 키: `results` / `pagination`

`docs/FEEDBACK.md`의 개선 후보인 “conversation/message pagination 응답 메타 추가”를 구현하기 위한 계획이에요.

## 1. 목표

모바일(향후 Flutter) 앱에서 무한 스크롤을 구현할 때, `limit/offset` 기반 목록 API의 응답에 **페이지 메타**를 포함해요.

- 클라이언트가 `has_more`, `next_offset`, `total_count`를 서버 응답만으로 판단할 수 있어요.
- 목록 호출 시 “다음 페이지 요청” 로직이 단순해져요.

## 2. 현재 상태

현재 목록 API는 아래처럼 list만 반환해요.

- `GET /api/conversations/` → `SuccessResponse[list[Conversation]]`
- `GET /api/conversations/{conversation_id}/messages/` → `SuccessResponse[list[Message]]`

## 3. 변경 범위(대상 엔드포인트)

### 3.1 Conversation 목록

- `GET /api/conversations/?limit=&offset=`

### 3.2 Message 목록

- `GET /api/conversations/{conversation_id}/messages/?limit=&offset=`

## 4. 응답 계약(확정)

### 4.1 PaginationMeta

```json
{
  "limit": 50,
  "offset": 0,
  "total_count": 123,
  "has_more": true,
  "next_offset": 50
}
```

### 4.2 Paginated 응답 형태

기존 `data: list[T]` 대신 아래 형태로 반환해요.

```json
{
  "success": true,
  "data": {
    "results": [],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 123,
      "has_more": true,
      "next_offset": 50
    }
  }
}
```

## 5. 구현 단계(권장 순서)

### 5.1 계약 확정 및 문서 동기화(선행)

API 변경은 아래 표면을 같은 작업 단위로 갱신해요.

- `README.md`
- `docs/DSL.md`
- `backend/domains/conversation/router.py`

### 5.2 스키마 추가

- `backend/domains/conversation/schemas.py`
  - `PaginationMeta`
  - `Paginated[T]`(Generic) 또는 명시 타입(`PaginatedConversations`, `PaginatedMessages`)
    - 필드: `results: list[T]`, `pagination: PaginationMeta`

권장: Generic을 쓰되, FastAPI response_model 안정성이 걱정되면 명시 타입으로 고정해요.

### 5.3 Repository에 count 메서드 추가

- `backend/domains/conversation/repository.py`
  - `count_conversations(user_id) -> int`
  - `count_messages(conversation_id) -> int`
  - 정렬 반영
    - conversations: `updated_at desc`
    - messages: `created_at asc`(최신이 아래로 쌓임)

### 5.4 Service에서 results + pagination 조립

- `backend/domains/conversation/service.py`
  - `get_conversations_paginated(user_id, limit, offset)`
  - `get_messages_paginated(conversation_id, user_id, limit, offset)`

메타 계산(권장):

- `has_more = (offset + len(results)) < total_count`
- `next_offset = offset + len(results)`

메시지 목록 UI(“최신이 아래”) 권장 호출:

- 첫 로딩 시: `offset = max(total_count - limit, 0)`로 마지막 페이지를 가져와요.
- 과거로 더 보기: `offset`을 줄여가며 이전 페이지를 가져와요(또는 별도 API/정렬 전략으로 확장).

### 5.5 Router 반환 변경

- `backend/domains/conversation/router.py`
  - `response_model`을 `SuccessResponse[Paginated[...]]`로 변경
  - 기존 list 반환 대신 `{results, pagination}` 반환

Query validation(권장):

- `limit`: 1 이상, 최대 100
- `offset`: 0 이상

## 6. Breaking change 여부

`data`가 list에서 object로 바뀌므로 기존 클라이언트에는 breaking change예요. 이번 작업에서는 기존 클라이언트 호환을 고려하지 않아요.

## 7. 추후 개선(옵션)

offset pagination은 데이터가 새로 삽입되면 페이지 경계가 흔들릴 수 있어요.

향후 필요하면 아래로 발전시켜요.

- cursor pagination(예: `created_at` + `id` 기반)
- `next_cursor`/`prev_cursor` 메타 제공

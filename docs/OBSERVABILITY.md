# API 로그와 지연 진단

> 갱신: 2026-10-11 · API JSON stdout 계약

API는 요청 완료, 처리 단계, 예외를 한 줄짜리 JSON으로 stdout에 기록해요. nginx 접근 로그도 JSON으로 stdout에 기록해요. Docker가 각 컨테이너 로그를 보관하고 회전하며, 향후 Grafana Alloy가 이 출력을 Loki로 보낼 수 있어요. 현재 구성에는 Alloy·Loki 서버가 포함되지 않아요.

## 식별자와 필드

| 필드 | 의미 |
|------|------|
| `trace_id` | 클라이언트가 보낸 유효한 `X-Request-ID` 또는 서버가 만든 32자리 ID. 같은 사용자 동작의 재시도에서 같을 수 있어요. |
| `request_id` | FastAPI에 도달한 HTTP 시도마다 새로 만드는 32자리 ID예요. |
| `proxy_request_id` | nginx의 `$request_id`예요. nginx가 내부 헤더 `X-Proxy-Request-ID`로 API에 전달하며 인증에 사용하지 않아요. |
| `ts` | API 로그의 초 단위 UTC 시각이에요. nginx는 `$time_iso8601`을 써요. |
| `duration_ms` | API의 단조 시계로 잰 처리 시간(밀리초)이에요. |
| `status_code`, `status`, `response_complete` | HTTP 상태, 성공·오류·취소 분류, 최종 body 전송 여부예요. 응답 전 오류에도 내부 분류용 500이 기록될 수 있어요. |
| `route` | 실제 URL이나 쿼리 문자열을 제외한 FastAPI 경로 템플릿이에요. 매칭되지 않은 경로는 `<unmatched>`예요. |
| `error_code` | `http.exception`의 오류 분류예요. 안전한 형식의 `detail.code`가 있는 HTTP 오류는 그 코드를 기록하고, 없으면 `HTTP_<상태 코드>`를 기록해요. |

모든 API 로그는 `ts`, `level`, `service`, `environment`, `trace_id`, `request_id`를 공유해요. `schema_version`과 `event`는 출력하지 않아요. 요청 완료는 `method`·`route`·`response_complete`, 단계는 `stage`·`duration_ms`, 처리된 예외는 `error_code`·`exception_type`으로 구분해요. 응답 후 작업 실패는 `exception_type`·`stack_frames`가 있고 `status_code`가 없는 오류 로그예요. `auth` 단계는 보호 API의 인증 확인 구간을 뜻해요. 기존 음성 대화의 `stt`, `llm`, `tts`, `audio_encode`, `server_total` 단계도 유지해요. `server_total`은 기존 대화 POST에서만 추가 출력하고, 전체 API의 지연 비교에는 요청 완료 로그의 `duration_ms`를 사용해요.

음성 스트림 충돌 진단에는 `source`(`precheck` 또는 `reserve_integrity`)와 `pending_count`·`failed_count`를 사용해요. DB 무결성 오류가 원인이면 `db_sqlstate`·`db_constraint`·`db_table`·`db_column`에 DB가 제공한 식별자만 안전한 형식으로 남겨요. 대화별 미해결 turn 조회는 `source` 없이 같은 상태별 개수를 남겨요. 이 로그에는 사용자·대화 ID와 답변 내용을 넣지 않아요.

대화 스트림의 첫 32개 델타에는 `llm_delta`(LLM에서 수신)와 `text_delta_sent`(NDJSON 송출)의 `stage`, `duration_ms`, `delta_index`, `delta_chars`, `turn_id`, `attempt_id`를 기록해요. `delta_index`는 0부터 시작하고 `delta_chars`는 원문 대신 글자 수예요. 앱의 같은 `trace_id`에 있는 `[latency]` `text_delta`·`first_text_frame`과 비교하는 절차는 [음성 지연 실험](VOICE_LATENCY.md)에 있어요.

5xx 오류의 `stack_frames`에는 프로젝트 상대 `file`, `function`, `line`만 담아요. `traceback.format_exc()`의 전체 문자열에는 예외 메시지와 SQL 매개변수 등이 포함될 수 있어 기본 로그에 사용하지 않아요. 예외 메시지, 지역 변수, 소스 코드 줄, 요청·응답 본문, 토큰, 검색어, 파일명, provider 응답 본문은 출력하지 않아요. 일반 Python 로거의 자유 형식 메시지도 JSON 출력에는 넣지 않아요. 필요한 진단값은 허용된 구조화 필드로 기록해야 해요.

## 시간 경계

nginx `request_time`은 nginx가 요청을 읽기 시작한 때부터 응답 전송이 끝날 때까지의 초 단위 시간이에요. `upstream_connect_time`, `upstream_header_time`, `upstream_response_time`은 upstream 연결·첫 헤더·응답 수신 시간을 나타내요. 재시도나 여러 upstream을 거치면 한 필드에 여러 값이 들어갈 수 있어 문자열로 기록해요. API `duration_ms`는 ASGI 미들웨어 진입부터 마지막 응답 body가 서버 전송 계층으로 전달될 때까지예요. 응답 후 문법 작업은 포함하지 않아요. 이 시간들은 경계가 다르므로 서로 단순히 더하거나 빼서 순수 네트워크 지연으로 해석하지 않아요. [음성 지연 실험](VOICE_LATENCY.md)은 앱의 녹음 종료부터 첫 재생까지를 별도로 측정해요.

### 음성 없는 GET 요청의 구간별 계측

- `auth.verify_token`은 전체 token 검증, `auth.remote_user`는 원격 Supabase `/user` 호출, `auth.jwks_fetch`는 공개 키 조회, `auth.profile`은 프로필 조회·최초 생성 시간이에요. `auth`는 전체 인증 시간이에요.
- `GET /api/auth/me`와 `GET /api/auth/me/language-preferences`는 인증 의존성이 같은 요청에서 읽은 프로필을 응답 변환에 재사용해요. 기존 프로필 기준 별도의 핸들러 SELECT를 수행하지 않으며, 토큰 검증과 `auth.profile` 조회는 요청마다 유지해요. 언어 설정 수정 PUT의 저장 경로는 이 최적화와 별개예요.
- 단계 로그의 `start_offset_ms`는 해당 HTTP 요청이 ASGI에 들어온 뒤 단계가 시작되기까지의 단조 시계 시간이에요. `response_start_ms`는 첫 응답 헤더를 전송한 시점, `response_body_ms`는 최종 본문을 전송한 시점이에요. `handler` 단계는 지정한 GET 엔드포인트의 실행 시간이며, 요청 시작부터 `handler` 시작 전까지에는 의존성 처리와 스레드풀 대기가 함께 포함될 수 있어요.
- 요청 완료 로그의 `db_query_count`, `db_query_total_ms`, `db_max_query_ms`는 SQLAlchemy 커서 실행 횟수·누적·최장 시간이고, `db_checkout_count`는 풀 연결 체크아웃 횟수예요. PostgreSQL의 `db_acquire_total_ms`, `db_max_acquire_ms`는 QueuePool에서 커넥션을 받는 전체 시간이에요. `db_pool_wait_count`, `db_pool_wait_total_ms`, `db_pool_wait_max_ms`는 풀이 포화되어 연결 반환을 기다릴 수 있는 블로킹 큐 조회의 시도·누적·최장 시간이에요. 즉시 반환된 경우에는 소량의 큐 처리 시간도 포함돼요. `db_connect_count`, `db_connect_total_ms`, `db_connect_max_ms`는 새 DBAPI 연결을 여는 시도·누적·최장 시간이며, 연결 실패 시도도 포함해요. `db_acquire_other_ms`는 전체 획득 시간에서 두 시간을 뺀 나머지로 체크아웃 검사·풀 내부 처리 등이 포함돼요. 수치는 요청별 합계이고 반올림 오차가 있을 수 있어요. `db_commit_count`와 `db_commit_total_ms`는 ORM commit 호출 구간이에요. 커서 시간에는 PostgreSQL 행 잠금 대기가 포함될 수 있지만 연결 풀 대기·결과 fetch·ORM 객체 생성은 포함하지 않아요.
- 250ms 이상인 쿼리는 SQL·값·테이블명 없이 `query_kind`(SELECT/INSERT/UPDATE/DELETE/OTHER)와 시간만 추가 기록해요. `handler` 단계의 `operation`(`access_summary`, `turn_access`, `conversation_list`, `message_list`, `turn_list`)과 `entitlement_lock`·`entitlement_held_after_reconcile` 단계를 요청 ID로 묶어요. 마지막 단계는 슬롯 재조정이 끝난 후부터 commit까지의 시간이며 잠금 보유 시간 전체는 아니에요. 실제 PostgreSQL 잠금 원인은 DB의 `wait_event_type`·잠금 대기 로그로 확인해요.
- 대화 목록은 저장된 활성 슬롯을 읽으며 `slot_reconcile`·`access_summary` 단계를 실행하지 않아요. 목록과 전체 개수 조회는 별도의 두 SQL이고, 인증 프로필 조회는 공통 의존성에서 수행해요.
- 모바일 일반 GET에도 요청마다 `X-Request-ID`를 붙이고 `[latency]`의 `http_response`, `http_total`을 기록해요. `operation`은 안전한 조회 종류, `request_source`는 홈 최근 대화·히스토리·대화 메시지·권한·turn 복구처럼 고정된 호출 위치, `auth_retry`는 401 후 토큰 갱신 재시도 여부예요. 경로·토큰·사용자 ID를 로그에 넣지 않아요. 진단 시 같은 `trace_id`로 앱·API·nginx를 연결해요. 화면 진입과 새로고침 같은 세부 트리거는 현재 구분하지 않아요.

## 로컬 조회

```bash
docker compose logs --no-log-prefix --since 30m api | jq -c 'select(.method != null and .route != null and .duration_ms >= 1000)'
docker compose logs --no-log-prefix --since 30m api | jq -c 'select(.trace_id == "<trace_id>")'
docker compose logs --no-log-prefix --since 30m nginx | jq -c 'select(.proxy_request_id == "<proxy_request_id>")'
```

API의 `proxy_request_id`로 nginx의 같은 시도를 찾고, `trace_id`로 앱의 같은 동작을 찾아요. nginx가 자체 생성한 429·502·504에는 API 로그와 `trace_id`가 없을 수 있어 nginx의 `proxy_request_id`와 상태·시간을 확인해요. `/health`는 API에 도달하면 완료 로그를 남기지만 nginx 접근 로그에서는 제외돼요. nginx의 기본 오류 메시지에는 원본 요청 줄이 포함될 수 있어 오류 로그는 `crit` 이상만 출력하고, 일반 upstream 실패는 JSON 접근 로그의 상태와 시간으로 조사해요.

### 개발 계정으로 대화 목록 반복 측정

로컬 FastAPI의 `ENV=dev`와 Supabase 이메일·비밀번호 개발 계정을 준비해요. 테스트 비밀번호는 macOS 로그인 키체인의 `tomatalk-supabase-test-password` 서비스에 계정 이메일로 저장해요. `security add-generic-password -a '<개발 계정 이메일>' -s tomatalk-supabase-test-password -U -w`를 실행하면 비밀번호를 대화형으로 입력할 수 있어 셸 명령 기록에 남지 않아요. 실제 사용자 계정의 비밀번호나 서비스 역할 키를 사용하지 않아요.

`cd backend && .venv/bin/python -m scripts.benchmark_conversation_list --email '<개발 계정 이메일>' --samples 20`을 실행해요. 스크립트는 로컬 `/api/auth/swagger/token`으로 실행마다 새 access token을 한 번 받고, 같은 연결에서 `GET /api/conversations/`를 순차 반복해요. 기본 준비 요청 2회는 통계에서 제외해요. 모든 목록 요청이 성공하면 클라이언트의 중앙값·p95·최댓값을 출력하고, 요청 실패 시 HTTP 코드만 표시하고 측정을 중단해요. 본문·비밀번호·토큰은 출력하지 않아요. `X-Request-ID`를 함께 출력하므로 API 로그에서 같은 요청의 `auth`, `handler`, `db_query_total_ms`를 비교할 수 있어요. 클라이언트 시간에는 로컬 전송 시간이 포함돼 서버 `duration_ms`와 측정 경계가 달라요. 측정용 계정의 대화 개수·구독 상태가 다르면 실제 사용자 요청과 시간값을 직접 비교할 수 없어요.

토큰 발급 API는 개발 환경에서만 기본 허용돼요. 만약 로컬 `SWAGGER_TOKEN_ISSUER_SECRET`이 설정되어 있으면 이 스크립트는 사용하지 않고 별도 인증 구성을 확인해요. 측정 후 키체인 비밀번호는 `security delete-generic-password -a '<개발 계정 이메일>' -s tomatalk-supabase-test-password`로 삭제할 수 있어요.

Loki 도입 시 `service`, `environment`처럼 값 종류가 적은 필드만 라벨로 두고, `trace_id`, `request_id`, `proxy_request_id`, `route`는 JSON 필드로 검색해요. 예: `{service="api"} | json | trace_id="<trace_id>"`. [Loki 라벨 가이드](https://grafana.com/docs/loki/latest/get-started/labels/)를 따르세요.

## 보관과 장애 확인

Compose는 API와 nginx에 Docker `json-file` 회전을 컨테이너당 `20m × 5`로 설정해요. 이는 용량 상한이며 시간 기준 보존 기간은 보장하지 않아요. 배포 후 로그량과 디스크 여유를 보고 조정해요. 로깅 출력 실패가 API 응답을 바꾸지 않도록 구성했지만, 로그가 빠질 수 있으므로 수집 장애에서는 Docker 로그와 nginx 상태를 함께 확인해요. 배포·설정 점검 절차는 [운영 가이드](OPERATIONS.md)에 있어요.

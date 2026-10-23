# API 로그와 지연 진단

> 갱신: 2026-10-19 · API JSON stdout 계약

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

- `auth.verify_token`은 전체 token 검증, `auth.remote_user`는 원격 Supabase `/user` 호출, `auth.jwks_fetch`는 공개 키 조회예요. `auth`는 토큰 검증 구간이고, 프로필이 필요한 API에서만 `auth.profile`로 별도 조회·초기화 시간을 기록해요.
- `GET /api/auth/me`와 `GET /api/auth/me/language-preferences`는 인증 의존성이 같은 요청에서 읽은 프로필을 응답 변환에 재사용해요. 기존 프로필 기준 별도의 핸들러 SELECT를 수행하지 않으며, 토큰 검증과 `auth.profile` 조회는 요청마다 유지해요. 언어 설정 수정 PUT의 저장 경로는 이 최적화와 별개예요.
- 단계 로그의 `start_offset_ms`는 해당 HTTP 요청이 ASGI에 들어온 뒤 단계가 시작되기까지의 단조 시계 시간이에요. `response_start_ms`는 첫 응답 헤더를 전송한 시점, `response_body_ms`는 최종 본문을 전송한 시점이에요. `handler` 단계는 지정한 GET 엔드포인트의 실행 시간이며, 요청 시작부터 `handler` 시작 전까지에는 의존성 처리와 스레드풀 대기가 함께 포함될 수 있어요.
- 요청 완료 로그의 `db_query_count`, `db_query_total_ms`, `db_max_query_ms`는 SQLAlchemy 커서 실행 횟수·누적·최장 시간이고, `db_checkout_count`는 풀 연결 체크아웃 횟수예요. PostgreSQL의 `db_acquire_total_ms`, `db_max_acquire_ms`는 QueuePool에서 커넥션을 받는 전체 시간이에요. `db_pool_wait_count`, `db_pool_wait_total_ms`, `db_pool_wait_max_ms`는 풀이 포화되어 연결 반환을 기다릴 수 있는 블로킹 큐 조회의 시도·누적·최장 시간이에요. 즉시 반환된 경우에는 소량의 큐 처리 시간도 포함돼요. `db_connect_count`, `db_connect_total_ms`, `db_connect_max_ms`는 새 DBAPI 연결을 여는 시도·누적·최장 시간이며, 연결 실패 시도도 포함해요. `db_acquire_other_ms`는 전체 획득 시간에서 두 시간을 뺀 나머지로 체크아웃 검사·풀 내부 처리 등이 포함돼요. 수치는 요청별 합계이고 반올림 오차가 있을 수 있어요. `db_commit_count`와 `db_commit_total_ms`는 ORM commit 호출 구간이에요. 커서 시간에는 PostgreSQL 행 잠금 대기가 포함될 수 있지만 연결 풀 대기·결과 fetch·ORM 객체 생성은 포함하지 않아요.
- 250ms 이상인 쿼리는 SQL·값·테이블명 없이 `query_kind`(SELECT/INSERT/UPDATE/DELETE/OTHER)와 시간만 추가 기록해요. `handler` 단계의 `operation`(`access_summary`, `turn_access`, `conversation_list`, `message_list`, `turn_list`)과 `entitlement_lock`·`entitlement_held_after_reconcile` 단계를 요청 ID로 묶어요. 마지막 단계는 슬롯 재조정이 끝난 후부터 commit까지의 시간이며 잠금 보유 시간 전체는 아니에요. 실제 PostgreSQL 잠금 원인은 DB의 `wait_event_type`·잠금 대기 로그로 확인해요.
- 대화 목록은 저장된 활성 슬롯을 읽으며 `slot_reconcile`·`access_summary`·인증 프로필 조회를 실행하지 않아요. 목록과 전체 개수 조회는 별도의 두 SQL이에요.
- 메시지 목록은 대화·사용자 조건을 전체 개수와 메시지 페이지 SQL에 각각 결합해요. 별도의 대화 소유권 SELECT는 하지 않으며, 빈 대화의 전체 개수 0과 존재하지 않거나 타인 소유인 대화의 404를 구분해요. 완료된 assistant 음성의 재생 가능 여부는 메시지가 있는 페이지에서만 별도 조회해요.
- 모바일 일반 GET에도 요청마다 `X-Request-ID`를 붙이고 `[latency]`의 `http_response`, `http_total`을 기록해요. `operation`은 안전한 조회 종류, `request_source`는 홈 최근 대화·히스토리·대화 메시지·권한·turn 복구처럼 고정된 호출 위치, `auth_retry`는 401 후 토큰 갱신 재시도 여부예요. 경로·토큰·사용자 ID를 로그에 넣지 않아요. 진단 시 같은 `trace_id`로 앱·API·nginx를 연결해요. 화면 진입과 새로고침 같은 세부 트리거는 현재 구분하지 않아요.

### Topic Prep 단계별 시간

스트림 Topic Prep의 `topic_prep.summary_ready`와 `topic_prep.card_ready`는 이벤트를 보낼 때 기록해요. 각 로그의 `start_offset_ms`는 서버 요청 시작 기준이에요. 모바일 `[latency]`의 같은 이벤트는 HTTP 요청 시작 기준 수신 시각이에요. 스트림 카드 LLM 로그에는 전체 응답의 provider·토큰 메타데이터가 제공되지 않을 수 있어요.

2026-10-23 로컬 백엔드 프로세스에서 동일한 `퇴사` 주제로 실제 OpenRouter 호출을 5회 측정했어요. 모두 검색 생략·카드 완성이었고, 서비스 호출 시작 기준 요약 중앙값은 3.41초, 카드 중앙값은 4.95초, 같은 요청 안의 요약→카드 간격 중앙값은 1.30초였어요(범위 1.20초에서 2.56초). 인증·프로필 조회·HTTP 전송·앱 렌더링은 제외한 값이므로 실제 화면 시각은 모바일·서버의 동일 trace_id 로그로 확인해야 해요.

`POST /api/search/topic-prep/`는 요청별 `trace_id`에서 `topic_prep.total`과 `search.query_analysis` → `search.provider_search` → `search.quality_judge` → `topic_prep.card_generation`의 완료 로그를 남겨요. `search_decision.search_required=false`이면 검색·출처 판정 로그 없이 카드 생성으로 이동해요. 각 `duration_ms`는 해당 단계의 시작부터 완료까지이고 `start_offset_ms`는 API 요청 시작 기준이에요. 검색 결과가 없으면 품질 판정을, 검색 품질이 부족하면 카드 생성을 건너뛰므로 해당 단계 로그가 없어요. 실패 단계에는 `status=error`를 남기고 예외는 기존 응답 정책대로 전파해요. 이미 있는 provider 세부 로그와 함께 비교할 수 있으며 검색어·출처 본문·LLM 응답은 로그에 넣지 않아요. `topic_prep.total`에는 결과 구성도 포함되고, 전체 요청의 `auth` 및 응답 직렬화는 포함되지 않아요. 이 단계들은 포함 관계가 있으므로 `topic_prep.total`과 하위 시간을 더하지 않아요.

검색어 분석은 `search.query_analysis.llm_request`와 `search.query_analysis.parse`, 카드 생성은 `topic_prep.card_llm_request`·`topic_prep.card_parse`·`topic_prep.card_build`로 나눠 기록해요. LLM 요청 로그에는 요청 모델명, OpenRouter가 응답 메타데이터로 제공한 실제 provider·service tier·생성 시간, 입력·출력 토큰 수와 응답 글자 수를 기록해요. 메타데이터가 없으면 해당 필드는 생략해요. OpenRouter 호출 시간은 HTTP 연결·라우팅·모델 처리·응답 수신을 모두 포함하며, 생성 시간 메타데이터는 공급자 측 값이므로 둘을 단순한 네트워크 지연 차이로 해석하지 않아요.

프로필 조회의 `auth.profile.select`는 `profiles` ORM 조회·행 fetch·객체 구성을 포함해요. 같은 요청의 `db_slow_query`는 커서 실행 시간을 기록하므로 두 구간의 차이로 Python 측 잔여 비용을 대략 확인할 수 있어요. SQL 실행 시간만으로 DB 서버 처리와 서울–시드니 왕복 시간을 분리할 수는 없으며, 이를 확인할 때는 별도 진단에서 같은 연결의 `SELECT 1`과 프로필 조회, 서버 측 실행 계획을 비교해요.

검색 공급자 안에서는 `search.provider_load`(ddgs import), `search.provider_client`(클라이언트 생성), `search.provider_request`(ddgs 텍스트 검색), `search.provider_normalize`(결과 정규화)를 같은 요청 ID로 기록해요. 검색 호출에는 설정된 `backend`·`region`·`requested_results`·`recency_intent`와 성공 시 `result_count`, 오류 시 `exception_type`만 남겨요. `backend=auto`일 때 ddgs 내부에서 실제로 선택한 검색 엔진이나 재시도 횟수는 이 로그만으로 식별할 수 없어요. 공급자 전체 `search.provider_search`는 스레드 실행 대기를 포함하므로 내부 구간의 합보다 길 수 있어요. 수집 상한은 기본 6개이며 `source_count`·`accepted_count`·`sufficient`를 함께 비교해 품질 변화를 확인해요.

`search.quality_judge`는 `SEARCH_QUALITY_JUDGE_MODEL`의 OpenRouter 모델을 사용하며 `search.pipeline`의 `quality_judge` 시작·완료 로그에 모델명을 남겨요. 검색어 분석과 준비 카드 생성은 기존 `LLM_PROVIDER`·`OPENROUTER_MODEL` 설정을 유지해요. 모델 교체 전후에는 같은 주제로 준비 카드 완성 여부와 출처 채택 수까지 함께 비교해요.

Topic Prep의 OpenRouter 요청은 모델 환경변수를 나누지 않고 검색 필요 여부 분석·출처 품질 판정에 `provider.sort=latency`, 카드 생성에 `provider.sort=throughput`을 전달해요. Ollama 요청에는 OpenRouter 전용 옵션을 보내지 않아요. structured output 미지원으로 재시도할 때도 `provider.sort`를 유지하며 `response_format`만 제외해요. 실제 선택된 upstream provider와 `service_tier`는 LLM 세부 로그에서 확인해요.

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

### 앱 주요 흐름 반복 측정

`backend/scripts/benchmark_api_flows.py`는 같은 로컬 개발 계정과 연결 재사용으로 아래 다섯 흐름을 측정해요. 토큰 발급은 표본에서 제외하며 각 요청에 `X-Request-ID`를 붙여 API 로그와 연결해요. 출력에는 요청·응답 본문, 토큰, 검색어, 이메일을 넣지 않아요. 주소는 `http://localhost`·`127.0.0.1`·`::1`과 명시적 포트만 허용해요.

| 흐름 | CLI 선택 | 요청과 측정 경계 |
|------|---------|----------------|
| 홈 | `home` | `/auth/me` 뒤 최근 대화 5개·주간 주제·스낵 12개·바구니 리셋 GET을 병렬 시작해 개별 완료와 묶음 완료를 기록해요. 앱 UI 프레임 시간은 포함하지 않아요. |
| 자유 대화 준비 | `topic-prep --topic '...'` | `POST /search/topic-prep/`의 전체 HTTP 응답을 측정해요. 검색·LLM 비용이 매 표본에 발생해요. |
| 자유 대화 준비 스트림 | `topic-prep-stream --topic '...'` | `POST /search/topic-prep/stream/`의 요약 수신, 카드 수신, 두 이벤트 간격과 전체 HTTP 시간을 측정해요. 검색·LLM 비용이 매 표본에 발생해요. |
| 대화 시작·이어 말하기 | `stream --kind free-chat --text '...'`, `stream --kind roleplay --role-character '...'`, `stream --kind suggested --topic-id UUID`, `stream --kind turn --conversation-id UUID --text '...'` | NDJSON 응답 헤더, 첫 `text_delta`, 첫 `audio_segment`, `turn_completed`까지의 시간을 기록해요. 첫 화면 프레임·실제 재생은 모바일 로그로 확인해요. 모든 표본은 새 요청 ID로 영속 대화 또는 발화를 만들고 LLM/TTS 비용이 발생해요. `--allow-writes`가 필요해요. |
| 기존 대화 진입 | `messages --conversation-id UUID` | 메시지 첫 40개를 읽고 총 40개 초과면 마지막 40개를 추가 조회해요. 이어서 미해결 turn과 대화별 권한 GET을 기록해요. |

예시는 `cd backend && .venv/bin/python -m scripts.benchmark_api_flows --email '<개발 계정 이메일>' home --samples 20`이에요. 주제 준비는 `topic-prep --topic 'coffee culture' --samples 3 --allow-cost`, 단계별 준비는 `topic-prep-stream --topic 'coffee culture' --samples 3 --allow-cost`처럼 실행해요. 대화 스트림은 `stream --kind free-chat --text 'I like coffee.' --samples 1 --allow-writes`처럼 실행해요. 기존 대화 진입은 `messages --conversation-id UUID`예요. 조회의 기본은 10회와 준비 1회이고 주제 준비·스트림의 기본은 1회와 준비 0회예요. 쓰기 흐름에는 자동 정리를 하지 않아요. 측정용 계정의 슬롯·발화 제한을 확인하고, 반복 표본의 대화·메시지 증가와 주제·답변 내용 변화가 결과에 영향을 줄 수 있어요. 중앙값·p95와 개별 요청 ID, 주제 준비의 `ready`, 스트림의 `audio_status`, 재진입의 메시지 수를 출력하며 실패·불완전 스트림은 통계에 넣지 않고 중단해요. p95는 표본이 적으면 안정적인 상위 지연 추정이 아니에요.

클라이언트 시간에는 로컬 전송과 JSON/NDJSON 파싱이 포함돼요. 서버 요청 완료 로그의 `duration_ms`, 인증·DB 단계, 스트림의 `first_text_delta`·`first_audio_segment`와 같은 요청 ID로 비교해요. 홈의 병렬 묶음은 실제 Flutter 화면 표시 시간과 다르고, 스트림 첫 오디오는 재생 시작 시간이 아니에요.

Loki 도입 시 `service`, `environment`처럼 값 종류가 적은 필드만 라벨로 두고, `trace_id`, `request_id`, `proxy_request_id`, `route`는 JSON 필드로 검색해요. 예: `{service="api"} | json | trace_id="<trace_id>"`. [Loki 라벨 가이드](https://grafana.com/docs/loki/latest/get-started/labels/)를 따르세요.

## 보관과 장애 확인

Compose는 API와 nginx에 Docker `json-file` 회전을 컨테이너당 `20m × 5`로 설정해요. 이는 용량 상한이며 시간 기준 보존 기간은 보장하지 않아요. 배포 후 로그량과 디스크 여유를 보고 조정해요. 로깅 출력 실패가 API 응답을 바꾸지 않도록 구성했지만, 로그가 빠질 수 있으므로 수집 장애에서는 Docker 로그와 nginx 상태를 함께 확인해요. 배포·설정 점검 절차는 [운영 가이드](OPERATIONS.md)에 있어요.

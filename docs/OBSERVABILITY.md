# API 로그와 지연 진단

> 갱신: 2026-10-09 · API JSON stdout 계약

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

5xx 오류의 `stack_frames`에는 프로젝트 상대 `file`, `function`, `line`만 담아요. `traceback.format_exc()`의 전체 문자열에는 예외 메시지와 SQL 매개변수 등이 포함될 수 있어 기본 로그에 사용하지 않아요. 예외 메시지, 지역 변수, 소스 코드 줄, 요청·응답 본문, 토큰, 검색어, 파일명, provider 응답 본문은 출력하지 않아요. 일반 Python 로거의 자유 형식 메시지도 JSON 출력에는 넣지 않아요. 필요한 진단값은 허용된 구조화 필드로 기록해야 해요.

## 시간 경계

nginx `request_time`은 nginx가 요청을 읽기 시작한 때부터 응답 전송이 끝날 때까지의 초 단위 시간이에요. `upstream_connect_time`, `upstream_header_time`, `upstream_response_time`은 upstream 연결·첫 헤더·응답 수신 시간을 나타내요. 재시도나 여러 upstream을 거치면 한 필드에 여러 값이 들어갈 수 있어 문자열로 기록해요. API `duration_ms`는 ASGI 미들웨어 진입부터 마지막 응답 body가 서버 전송 계층으로 전달될 때까지예요. 응답 후 문법 작업은 포함하지 않아요. 이 시간들은 경계가 다르므로 서로 단순히 더하거나 빼서 순수 네트워크 지연으로 해석하지 않아요. [음성 지연 실험](VOICE_LATENCY.md)은 앱의 녹음 종료부터 첫 재생까지를 별도로 측정해요.

## 로컬 조회

```bash
docker compose logs --no-log-prefix --since 30m api | jq -c 'select(.method != null and .route != null and .duration_ms >= 1000)'
docker compose logs --no-log-prefix --since 30m api | jq -c 'select(.trace_id == "<trace_id>")'
docker compose logs --no-log-prefix --since 30m nginx | jq -c 'select(.proxy_request_id == "<proxy_request_id>")'
```

API의 `proxy_request_id`로 nginx의 같은 시도를 찾고, `trace_id`로 앱의 같은 동작을 찾아요. nginx가 자체 생성한 429·502·504에는 API 로그와 `trace_id`가 없을 수 있어 nginx의 `proxy_request_id`와 상태·시간을 확인해요. `/health`는 API에 도달하면 완료 로그를 남기지만 nginx 접근 로그에서는 제외돼요. nginx의 기본 오류 메시지에는 원본 요청 줄이 포함될 수 있어 오류 로그는 `crit` 이상만 출력하고, 일반 upstream 실패는 JSON 접근 로그의 상태와 시간으로 조사해요.

Loki 도입 시 `service`, `environment`처럼 값 종류가 적은 필드만 라벨로 두고, `trace_id`, `request_id`, `proxy_request_id`, `route`는 JSON 필드로 검색해요. 예: `{service="api"} | json | trace_id="<trace_id>"`. [Loki 라벨 가이드](https://grafana.com/docs/loki/latest/get-started/labels/)를 따르세요.

## 보관과 장애 확인

Compose는 API와 nginx에 Docker `json-file` 회전을 컨테이너당 `20m × 5`로 설정해요. 이는 용량 상한이며 시간 기준 보존 기간은 보장하지 않아요. 배포 후 로그량과 디스크 여유를 보고 조정해요. 로깅 출력 실패가 API 응답을 바꾸지 않도록 구성했지만, 로그가 빠질 수 있으므로 수집 장애에서는 Docker 로그와 nginx 상태를 함께 확인해요. 배포·설정 점검 절차는 [운영 가이드](OPERATIONS.md)에 있어요.

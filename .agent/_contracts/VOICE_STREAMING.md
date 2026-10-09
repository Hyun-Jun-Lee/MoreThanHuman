# Voice Streaming v1 — REVIEW

> 상태: REVIEW · 갱신: 2026-10-09 · 기준: [음성 스트리밍 설계](../../docs/VOICE_STREAMING.md)

이 계약은 대화 화면 전체의 문장별 완성 오디오를 정의해요. 1~6단계의 경로와 앱 연결을 구현했고, 실기기·프록시·동시 부하 검증은 7단계로 남아 있어요. 활성 경로는 [DSL](../../docs/DSL.md)에 있어요.

## 범위와 불변식

- Free Chat 시작, 주간 추천 Free Chat 시작, Roleplay 시작, 기존 대화의 텍스트·음성 이어 말하기에 적용해요. 검색·문법·운영 콘텐츠용 내부 LLM 호출은 범위 밖이에요.
- 기존 JSON 경로는 유지하고 각 경로의 `/stream/` 형제 경로가 `application/x-ndjson`을 반환해요. 한 줄이 이벤트 하나이며 오디오는 완성된 문장별 Base64예요.
- 확정된 사용자 발화는 AI 생성 실패 후에도 남아요. 미완성 assistant 텍스트는 정상 메시지로 저장하지 않아요. 앱은 자동 재생성하지 않고 사용자의 재시도 입력을 기다려요.
- 완성된 assistant 텍스트의 TTS만 실패하면 assistant 메시지는 유지하고 저장된 같은 텍스트의 오디오만 다시 합성해요.

## 경로

| 메서드·경로 | 요청 | 성공 응답 | 상태 |
|-------------|------|-----------|------|
| `POST /api/conversations/start/free-chat/stream/` | 기존 Free Chat 텍스트 JSON 또는 `audio_file` multipart | NDJSON | 구현 |
| `POST /api/conversations/start/free-chat/suggested/stream/` | 기존 `topic_id`, `start_request_id` JSON | NDJSON | 구현 |
| `POST /api/conversations/start/roleplay/stream/` | 기존 `role_character`, `search_context` JSON | NDJSON | 구현 |
| `POST /api/conversations/{id}/turn/stream/` | 기존 `text` JSON 또는 `audio_file` multipart | NDJSON | 구현 |
| `POST /api/conversations/{id}/message/stream/` | 기존 `message` JSON | NDJSON | 구현 |
| `GET /api/conversations/turns/{turn_id}/` | 인증·소유권 확인 | JSON 상태 | 구현 |
| `GET /api/conversations/turns/by-request/{request_id}/` | 첫 이벤트 전 끊긴 요청의 소유자·요청 키 확인 | JSON 상태 | 구현 |
| `GET /api/conversations/{id}/turns/` | 인증·대화 소유권 확인 | JSON 미완료·실패 turn 목록 | 구현 |
| `POST /api/conversations/turns/{turn_id}/retry/stream/` | 실패 turn 재시도. STT 전에 실패한 녹음은 원래 시작 경로로 다시 전송 | NDJSON | 구현 |
| `POST /api/conversations/messages/{assistant_message_id}/audio/stream/` | 저장된 assistant 메시지의 음성만 재합성 | NDJSON | 구현 |

스트림 경로에서는 음성 출력이 필수예요. 기존 요청에 `include_audio_response`가 있어도 스트림 응답은 항상 오디오를 생성해요. 새 앱은 `Accept: application/x-ndjson`을 보내고 성공 응답은 `Content-Type: application/x-ndjson; charset=utf-8`, `Cache-Control: no-store`를 사용해요. 기존 JSON 경로의 입력·출력은 바꾸지 않아요.

## 요청 식별자와 멱등성

- 새 스트림 시작 요청마다 앱이 UUID `Idempotency-Key`를 생성해요. 같은 사용자·키는 하나의 논리적 `turn_id`를 가리켜요. 다른 사용자 키와 충돌하지 않아요.
- 주간 추천 시작에서는 기존 `start_request_id`가 같은 논리적 요청 키예요. 서버의 별도 `turn_id`를 가리키며, 스트림 요청의 `Idempotency-Key`와 본문 `start_request_id`는 일치해야 해요. 기존 JSON 요청의 `start_request_id` 동작은 유지해요.
- 동일한 주간 추천 요청 ID가 기존 JSON 경로에서 이미 성공했다면 스트림 경로도 그 대화·첫 AI 메시지를 재사용해요. 경로가 달라졌다는 이유로 대화를 다시 만들지 않아요.
- 서버는 생성 시도마다 새 `attempt_id`를 만들어요. 중복 최초 요청이나 재시도 버튼 연타가 동시에 LLM·TTS를 실행하지 못하도록 사용자·turn에 영속 고유 제약과 상태 전이를 적용해요.
- 첫 요청이 진행 중이면 `409 TURN_IN_PROGRESS`, 완료됐으면 `409 TURN_ALREADY_COMPLETED`, 실패했으면 `409 TURN_FAILED_RETRY_REQUIRED`와 상태 조회 경로를 반환해요. 실패한 turn은 명시적 재시도 경로에서만 새 `attempt_id`를 만들어요. 재시도 요청도 별도 UUID `Idempotency-Key`로 중복 전송을 막아요.
- 현재 `X-Request-ID`는 진단용 trace 연결 값이에요. `Idempotency-Key`, `turn_id`, `attempt_id`와 서로 다른 역할을 유지해요.

## NDJSON 이벤트

각 줄은 UTF-8 JSON 객체예요. 공통 필드는 `event`, `seq`(0부터 증가), `turn_id`, `attempt_id`예요. HTTP 네트워크 chunk와 줄 경계는 일치하지 않을 수 있어요. 앱은 증분 UTF-8 decoder로 완성된 줄만 처리해요.

| 이벤트 | 추가 필드 | 발생 조건 |
|--------|-----------|-----------|
| `turn_started` | `trace_id` | 첫 이벤트. 저장된 대화가 아직 없으면 `conversation_id`를 생략해요. |
| `user_message_committed` | `conversation_id`, `user_message_id`, `text`, `input_mode: text\|audio` | 텍스트 입력 또는 STT 전사가 저장된 뒤 한 번. Roleplay·주간 추천 시작에는 없어요. |
| `text_delta` | `delta` | 생성된 임시 텍스트. 주간 추천은 저장된 첫 질문을 표시하는 데 사용해요. |
| `audio_segment` | `segment_index`, `text`, `content_type`, `format`, `base64` | 한 문장 전체의 합성이 끝나면 순서대로 보내요. |
| `audio_error` | `segment_index?`, `code` | 텍스트는 완성됐지만 오디오 합성·전송에 실패했을 때 보내요. |
| `turn_completed` | `conversation_id`, `assistant_message_id`, `text`, `audio_status: completed\|failed` | assistant 텍스트가 DB에 저장되고 TTS가 완료되거나 실패로 확정된 뒤 한 번. |
| `turn_error` | `code`, `retryable`, `conversation_id?`, `user_message_id?` | assistant 텍스트가 완성되지 못한 시도의 종료. |

`turn_completed`와 `turn_error` 중 하나만 terminal event예요. 인증·입력·권한·슬롯·발화 한도 오류는 스트림 시작 전에 기존 의미의 HTTP 상태와 JSON 오류로 반환해요. 스트림 시작 후에는 HTTP 상태를 변경할 수 없으므로 `turn_error`를 사용해요. 연결이 terminal event 없이 끊기면 앱은 turn 상태를 조회하고 완료를 추정하지 않아요. 이벤트의 `seq`와 `turn_id`·`attempt_id`로 중복·이전 시도 이벤트를 버려요.

오디오 전용 재합성 경로는 동일한 `audio_segment` 내용을 쓰되 모든 이벤트에 `assistant_message_id`, `audio_attempt_id`, `seq`를 넣고 `audio_started` → `audio_segment` 반복 → `audio_completed` 또는 `audio_error`로 끝나요. 이 경로는 assistant 텍스트나 사용자 발화를 추가 저장하지 않아요.

## 저장과 상태 전이

- 서버는 인증 사용자 소유의 영속 turn과 시도 이력을 보관해요. turn에는 종류·시작 입력 또는 대화 ID·사용자 메시지 ID·assistant 메시지 ID·`pending/completed/failed` 상태·실패 사유·`pending/completed/failed` 오디오 상태를 기록해요. 시도 이력에는 `attempt_id`, 시작·종료 시각과 결과를 남겨요.
- 서버가 중단되어 `pending`이 남지 않도록 turn에 기한을 두고, 기한이 지난 시도는 상태 조회 또는 재시도 요청 때 실패로 정리해요. 보관하는 시작 입력은 재시도에 필요한 최소 필드로 제한하고 소유권으로 보호해요.
- 텍스트 입력이 확정되거나 STT가 완료되면 사용자 메시지를 한 번 저장해요. 이후 실패하더라도 삭제하지 않고 같은 내용을 문법 평가에 사용해요. 재시도는 그 메시지를 재사용하며 STT와 발화 수 계산을 반복하지 않아요.
- Free Chat 시작의 AI 생성이 실패하면 대화와 첫 사용자 메시지를 남겨요. 이 대화는 기존 슬롯 하나를 사용하며 재시도는 같은 대화에서 진행해요. 다음 사용자 발화는 실패한 답변이 해결될 때까지 막아요.
- Roleplay 시작에는 사용자 발화가 없어요. 생성 중 영속 슬롯 예약으로 동시 생성 한도를 지키되 목록에 빈 대화를 노출하지 않고, 인사 생성 실패·예약 기한 만료 시 슬롯을 해제해요. 재시도에는 저장한 시작 입력을 재사용해요.
- 주간 추천 시작의 첫 assistant 메시지는 이미 저장된 텍스트예요. TTS 또는 연결 문제는 텍스트를 삭제하지 않고 오디오 상태만 실패로 표시해요. 기존 `start_request_id`의 대화·메시지 멱등성도 유지해요.
- LLM 텍스트가 끝까지 생성되면 assistant 메시지를 짧은 DB 트랜잭션으로 저장하고 turn을 완료 상태로 전환해요. TTS worker는 계속 돌 수 있으며 오디오 상태는 별도로 갱신해요. TTS 실패나 이후 연결 단절은 assistant를 삭제하지 않아요. 텍스트 완성 전 실패는 turn 실패로 기록하고 assistant 메시지는 만들지 않아요.
- 외부 provider 대기와 오디오 전송 동안 DB 트랜잭션을 열어 두지 않아요. 요청 수명 밖 문법 작업과 상태 갱신은 각각 자신의 DB session을 사용해요.

## 상태 조회와 수동 복구

`GET /api/conversations/turns/{turn_id}/`는 `{turn_id, kind, status, attempt_id, conversation_id?, user_message_id?, assistant_message_id?, audio_status, error_code?, retryable}`를 JSON envelope에 담아요. 다른 사용자 turn은 404로 숨겨요. 대화 재진입에는 `GET /api/conversations/{id}/turns/`로 진행 중·실패 turn과 음성만 실패한 완료 turn을 조회해 오류·재시도·음성 다시 듣기 버튼을 복원해요.

첫 `turn_started` 이벤트 전에 연결이 끊겼다면 앱은 UUID 요청 키로 `GET /api/conversations/turns/by-request/{request_id}/`를 호출해요. 찾지 못하면 재전송할 수 있고, 조회 자체가 실패하면 자동 재전송하지 않고 사용자의 다음 상태 확인을 기다려요.

재시도와 오디오 재합성도 turn·대화·메시지의 인증 사용자 소유권을 확인해요. 타 사용자 식별자는 404로 숨기고, 잠긴 대화·현재 권한 제한은 기존 409 오류 의미를 사용해요.

- 연결이 끊기면 앱은 답변을 자동 재생성하지 않아요. 상태 조회 결과가 완료면 메시지를 다시 읽고, 실패면 버튼을 보여줘요. 진행 중이면 완료·실패가 확정될 때까지 버튼을 비활성화해요.
- 실패한 turn의 재시도는 저장된 사용자 메시지나 Roleplay 시작 입력으로 새 AI 시도를 실행해요. STT 전에 실패한 녹음은 앱이 원본 파일을 다시 업로드해야 해요. 재시도는 추가 사용자 발화나 슬롯을 만들지 않지만 현재 대화 접근 권한은 다시 확인해요.
- 사용자가 이미 일부 음성을 들었을 수 있으므로 재시도로 생성된 답변이 이전의 미완성 내용과 다를 수 있음을 앱에 안내해요. 임시 텍스트와 남은 재생 큐는 실패 시 지워요.
- TTS 또는 기기 재생에 실패한 turn은 AI 재시도 버튼 대신 음성 다시 듣기 버튼을 제공해요. 오디오 전용 경로는 저장된 assistant 텍스트만 사용하며 이미 완료된 음성도 명시적 다시 듣기에 재합성할 수 있어요.

## 취소와 자원 한계

- 앱의 화면 이탈·명시적 취소·연결 단절 시 서버는 LLM reader, TTS worker, 응답 중계를 취소·await하고 upstream HTTP 응답을 닫아요. 텍스트가 미완성이면 turn은 실패(`CLIENT_CANCELLED` 또는 `STREAM_DISCONNECTED`)예요. 텍스트가 저장됐으면 turn은 완료이고 오디오 상태만 실패예요.
- TTS worker는 하나를 사용해 순서를 보장해요. 문장 큐와 결과 큐는 각각 최대 두 항목이며 느린 수신자에게는 backpressure를 걸어요. 각 TTS 출력은 기존 음성 서비스의 바이트 제한을 따르고 전체 turn에는 토큰 설정 제한을 적용해요.
- 첫 LLM delta 45초, 다음 delta 간 60초, TTS 문장당 60초, 전체 turn 300초를 초기 제한으로 적용해요. 실기기와 서버 p95를 본 뒤 조정해요. heartbeat는 전체 제한을 연장하지 않아요.
- 프록시 buffering·gzip·timeout, Base64 이벤트 크기, iOS·Android 재생 간격을 실환경에서 확인해요.

## ACTIVE 전 확인

- 기존 JSON 응답·주간 추천 `start_request_id`·구독 슬롯/발화 한도와 새 경로의 동시 요청 의미가 일치해야 해요.
- 스트림 시작 전 JSON 오류, 시작 후 `turn_error`, terminal event 없이 끊긴 경우를 각각 확인해요.
- 사용자 발화 보존, 문법 작업의 단일 실행, 재시도의 발화 수 중복 방지, Roleplay 슬롯 예약 해제를 확인해요.
- TTS만 실패한 경우의 텍스트 보존과 오디오 재합성, 오래 열린 스트림의 취소·DB session·HTTP 연결 정리를 확인해요.

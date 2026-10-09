# 음성 응답 스트리밍 설계와 구현 순서

> 버전: 0.7 · 갱신: 2026-10-05 · 상태: 1~3단계 구현, 4~7단계 계획 · HTTP 풀 v1 기반

## 목표

사용자가 말을 끝낸 뒤 첫 응답 음성을 듣기까지의 시간을 줄여요. LLM이 첫 문장을 완성하면 그 문장을 TTS에 전달하고, 앱이 첫 문장을 재생하는 동안 나머지 문장을 생성·합성해요.

현재 계측과 실험 절차는 [음성 지연 문서](VOICE_LATENCY.md)를 참조해요. 1~3단계에서는 주간 추천 시작의 전용 스트림 경로·turn 저장·앱 재생 큐를 연결했어요. 활성 경로는 [DSL](DSL.md)에, 나머지 흐름의 목표 계약은 [Voice Streaming DRAFT 계약](../.agent/_contracts/VOICE_STREAMING.md)에 있어요.

## 합의된 구현 방향

2026-10-05에 첫 구현 범위를 다음과 같이 결정했어요:

- 첫 버전은 **문장별 완성 오디오**까지 구현해요. 문장 내부 오디오 조각 스트리밍과 실시간 마이크는 후속 단계예요.
- 대화 AI 응답을 반환하는 Free Chat 시작, 주간 추천 Free Chat 시작, Roleplay 시작, 기존 대화의 `/turn/`·`/message/`에 적용해요. 주간 추천은 첫 질문 텍스트가 이미 저장돼 있으므로 오디오 전송 부분만 스트리밍해요.
- 오디오 세그먼트는 NDJSON 이벤트의 Base64 데이터로 전달해요.
- 기존 JSON 경로와 분리된 `/stream/` 경로에서 음성 이벤트를 제공해요.
- 완료된 답변만 정상 답변으로 저장해요. 취소나 연결 끊김으로 끝난 부분 답변은 실패 상태로 처리하고 정상 완료로 저장하지 않아요.
- 답변 중간에 실패해도 확정된 사용자 발화는 보존하고, 앱에는 미완성 AI 답변 대신 오류와 재시도 버튼을 보여줘요.
- 연결이 끊겼을 때 앱은 답변 생성을 자동 재시도하지 않아요. 사용자가 재시도 버튼을 눌러 다시 요청해요.

이 문서의 범위는 대화 화면에서 사용자에게 재생하는 AI 응답이에요. 검색 결과 준비, 문법 평가, 운영 콘텐츠 생성에 쓰이는 내부 LLM 호출은 이 음성 출력 범위에 포함하지 않아요.

## 스트림 전용 경로 — 결정된 방향

기존 POST 경로는 현재 JSON envelope를 반환하고, 새 `/stream/` 경로는 문장별 음성 이벤트를 `Content-Type: application/x-ndjson; charset=utf-8`로 반환해요. 새 앱은 스트림 경로를 호출하고 `Accept: application/x-ndjson`을 보내요. 응답에는 `Cache-Control: no-store`를 설정해요. 스트림 경로에서는 `include_audio_response`를 별도로 요구하지 않고 음성을 포함해요.

| 기존 JSON 경로 | 새 NDJSON 경로 | 입력·처리 |
|----------------|---------------|-----------|
| `/api/conversations/start/free-chat/` | `/api/conversations/start/free-chat/stream/` | 기존 텍스트 JSON 또는 녹음 파일 multipart를 받아 전사·생성·문장별 TTS를 진행해요. |
| `/api/conversations/start/free-chat/suggested/` | `/api/conversations/start/free-chat/suggested/stream/` | 기존 주제 ID와 `start_request_id`를 받아 저장된 첫 질문을 문장별로 합성해요. 새 LLM 생성은 없어요. |
| `/api/conversations/start/roleplay/` | `/api/conversations/start/roleplay/stream/` | 기존 역할·상황 입력으로 첫 인사를 생성해요. 사용자 발화는 없어요. |
| `/api/conversations/{id}/turn/` | `/api/conversations/{id}/turn/stream/` | 기존 텍스트 JSON 또는 녹음 파일 multipart를 받아 이어 말해요. |
| `/api/conversations/{id}/message/` | `/api/conversations/{id}/message/stream/` | 기존 텍스트 요청의 AI 응답에도 같은 음성 스트림을 적용해요. |

응답 형식은 경로로 구분해요. 기존 경로는 JSON, 새 스트림 경로는 NDJSON만 반환해요. 스트림 경로의 정상 응답은 공통 JSON envelope를 사용하지 않고, 인증·입력 검증 같은 스트림 시작 전 오류는 HTTP 상태와 JSON 오류 본문으로 반환해요. OpenAPI에는 각 경로의 실제 응답 형식을 따로 표시해요.

## 후속 단계에서 확정할 항목

- [DRAFT 계약](../.agent/_contracts/VOICE_STREAMING.md)의 나머지 생성·재시도 경로를 구현하면서 [DSL](DSL.md)·아키텍처에 반영하고 전체 계약을 REVIEW·ACTIVE로 승격해요.
- 전송 큐의 문장 수·바이트 수, 첫 토큰·첫 오디오·idle·전체 turn 제한의 초기값을 [지연 계측](VOICE_LATENCY.md)과 실기기 측정으로 정해요.
- 요청 종료·화면 이탈·서버 종료 때 LLM reader, TTS worker, HTTP 응답, DB session의 정리 순서를 구현 계약으로 확정해요.

## 권장 접근

```text
파일 업로드 → STT 확정 → LLM 스트림 reader
                           │
                           ▼
                   문장 분리 + 제한된 큐
                           │
                           ▼
                    TTS worker (순서 유지)
                           │
                           ▼
                  HTTP 이벤트 응답 → 앱 재생 큐
```

LLM reader와 TTS worker가 실제로 동시에 진행돼야 해요. 토큰을 읽는 같은 루프에서 TTS 완료를 기다리면 나머지 토큰 수신이 막힐 수 있어요. 처음에는 TTS worker 하나로 순서를 보장하고, 병렬 합성이 필요하다는 증거가 생기면 문장 번호별 재정렬을 추가해요.

### 1단계: 문장별 완성 오디오

기존 파일 업로드·STT를 유지하고 첫 문장이 완성되면 해당 문장만 합성해요. 문장 하나의 오디오가 완성되면 즉시 앱에 보내고, 재생하는 동안 다음 문장을 합성해요. 전체 답변 완성은 기다리지 않지만 **문장 하나의 전체 합성은 기다리는 방식**이에요.

현재 `BytesSource` 재생을 문장별 큐로 확장해 검증할 수 있어요. 플랫폼의 파일별 초기화 때문에 문장 사이 틈이 생길 수 있으므로 gapless 재생을 보장한다고 가정하지 않아요. 첫 재생 지연뿐 아니라 문장 간 침묵·억양도 평가해요.

### 2단계: 문장 내부의 오디오도 스트리밍

TTS 첫 바이트부터 중계하고 앱은 작은 버퍼로 즉시 재생해요. HTTPX streaming context/iterator로 응답을 읽고 완료·취소 시 닫아요. 앱에는 PCM 입력이나 증분 디코딩 가능한 플레이어가 필요해요. provider의 샘플레이트·채널·샘플 형식을 명시적으로 맞춰요.

MP3 네트워크 chunk를 독립 파일처럼 재생하면 안 돼요. 컨테이너·프레임과 네트워크 chunk 경계는 달라요. 버퍼를 줄이면 시작은 빨라도 underrun이 생길 수 있으므로 함께 측정해요.

### 3단계: 실시간 마이크와 끼어들기

녹음 중 업로드·실시간 STT·발화 종료 감지를 추가할 때 WebSocket 또는 WebRTC를 검토해요. 영어 학습자의 문장 중간 침묵을 발화 종료로 오판하지 않도록 검증해요. 중간 전사를 확정 메시지나 문법 평가 입력으로 바로 사용하지 않아요.

사용자가 끼어들면 이전 플레이어·큐·LLM·TTS를 취소하고, 뒤늦게 도착하는 이전 turn 이벤트를 무시해요.

## 전송과 호환성

WebSocket은 필수가 아니에요. 앱은 multipart POST로 파일을 보내고 서버는 요청 동안 열린 HTTP 응답으로 이벤트를 전달할 수 있어요. 서버 ↔ LLM과 앱 ↔ 서버의 프로토콜은 독립적이에요.

| 방식 | 적합한 상황 |
|------|-------------|
| POST + NDJSON/SSE 응답 | 현재 파일 전송 UX의 점진적 전환, 텍스트·상태·오디오 이벤트 |
| 별도 바이너리 오디오 스트림 | Base64 전송량 감소. 텍스트 연결 ID·취소 소유권 필요 |
| WebSocket | 연속 음성 입력·출력·취소를 같은 양방향 연결로 처리 |
| WebRTC | 통화형 미디어와 지터·에코·기기 오디오 처리가 중요할 때 |

첫 구현은 위 `/stream/` 경로로 NDJSON을 제공해요. 기존 JSON 경로의 요청·응답 계약은 그대로 유지해요. 모바일은 새 경로를 사용하고, 구버전 앱은 기존 경로를 계속 사용할 수 있어요.

Flutter Dio의 `ResponseType.stream`을 쓰고 현재 공통 JSON envelope parser 대신 별도 증분 decoder를 두어요. UTF-8 문자가 chunk 사이에서 나뉠 수 있으므로 증분 UTF-8 디코딩 후 줄/이벤트를 조립해요. HTTP chunk 하나를 이벤트 하나로 취급하지 않아요.

## 이벤트 계약 권장안 — 현재 API에 없음

| 이벤트 | 데이터 | 목적 |
|--------|--------|------|
| `turn_started` | `turn_id`, `attempt_id`, `trace_id` | 앱이 이후 이벤트의 소유권을 확인해요. |
| `user_message_committed` | 확정된 입력 텍스트, 입력 방식, `conversation_id`, `user_message_id` | 텍스트 입력 또는 STT 전사를 저장한 뒤 말풍선·문법 평가에 연결해요. 사용자 발화가 없는 Roleplay·주간 추천 시작에는 보내지 않아요. |
| `text_delta` | 전체 이벤트 순번, 텍스트 조각 | AI 텍스트를 임시로 먼저 표시해요. 주간 추천은 저장된 첫 질문을 표시해요. |
| `audio_segment` | 전체 이벤트 순번, 문장 번호, 텍스트, MIME 형식, Base64 오디오 | 완성된 문장 오디오를 순서대로 재생해요. |
| `audio_error` | 실패 문장 번호, 오류 코드 | 완성된 텍스트는 유지하고 음성만 다시 시도할 수 있게 해요. |
| `turn_completed` | `conversation_id`, `assistant_message_id`, 최종 텍스트, `audio_status` | 완성된 AI 텍스트의 DB 저장을 확인해요. 음성만 실패했다면 `audio_status=failed`예요. |
| `turn_error` | 오류 코드, 재시도 가능 여부, 보존된 `user_message_id` | AI 텍스트가 완성되지 못한 생성 시도를 실패로 종료해요. |

JSON 문자열의 줄바꿈을 escape하고 이벤트 한 개를 한 줄로 구분해요. Base64는 원시 바이트보다 약 33% 커지므로 1단계의 구현 편의와 전송량을 비교해요. 2단계에서는 바이너리 framing이나 별도 오디오 경로를 다시 정해야 해요.

- `turn_id`·`attempt_id`와 순번으로 중복·뒤늦은 이벤트를 거르고 재생 순서를 지켜요. `turn_completed`와 `turn_error` 중 정확히 하나만 terminal event로 보내요.
- 문장 수·바이트 수로 큐를 제한해요. 느린 수신자에 맞춰 생성 속도를 조절하거나 중단하며 메모리를 무제한 사용하지 않아요.
- 헤더 전 인증·입력·대화 슬롯·발화 한도 검증 실패는 기존 의미의 HTTP 상태와 JSON 오류 본문으로 반환해요. 앱은 상태 코드·`Content-Type`을 확인한 뒤 NDJSON decoder를 시작해요. 스트림 시작 뒤에는 상태 코드를 바꿀 수 없으므로 `turn_error`를 보내요. terminal event 없이 끊기면 앱은 상태 조회로 서버의 최종 결과를 확인해요.
- 전체 turn 제한, 첫 토큰·첫 오디오·idle timeout을 구분해요. heartbeat로 처리 제한을 무한히 늘리지 않아요.

### 저장·재시도 계약 권장안

- 새 요청에는 사용자별 고유 UUID `Idempotency-Key`를 보내요. 주간 추천 시작은 기존 `start_request_id`를 같은 논리적 `turn_id`로 사용하고, NDJSON 요청의 두 값은 일치시켜요. 현재 `X-Request-ID`는 로그 연결용이며 멱등 키가 아니에요.
- 인증 사용자 소유의 영속 turn 기록에 `turn_id`, 시작 입력 또는 대화·사용자 메시지 ID, 현재 `attempt_id`, `pending/completed/failed` 상태, 실패 사유, 완료된 assistant 메시지 ID, 오디오 상태를 기록해요. 취소와 연결 끊김도 실패 사유로 구분해요. 재시도마다 새 `attempt_id`를 만들고 이전 실패 기록을 보존해요.
- 텍스트 입력이 확정되거나 STT가 끝난 직후 사용자 메시지를 한 번 저장하고, 문법 평가는 같은 확정 텍스트로 백그라운드에서 시작해요. AI 생성 실패·연결 끊김에도 사용자 메시지를 삭제하지 않아요. 재시도는 저장된 텍스트를 재사용하므로 STT·사용자 발화 저장·발화 한도 계산을 반복하지 않아요.
- Free Chat 시작 중 실패하면 대화와 첫 사용자 메시지를 보존하고 같은 대화 안에서 재시도해요. 이 대화는 기존 슬롯을 사용해요. Roleplay 시작은 사용자 메시지가 없으므로 첫 AI 인사가 완성되지 않으면 빈 대화를 목록에 남기지 않고 준비 화면에서 재시도해요.
- AI 텍스트가 끝까지 생성되어 DB에 저장된 뒤에는 정상 assistant 메시지로 다뤄요. TTS만 실패하거나 이후 연결이 끊기면 같은 저장된 텍스트를 다시 합성하고 AI 답변을 새로 생성하지 않아요. AI 텍스트가 미완성이면 부분 assistant 메시지를 정상 대화 이력에 저장하지 않아요.
- `GET /api/conversations/turns/{turn_id}/`로 소유자의 현재 상태와 저장된 메시지 ID를 조회해요. 앱은 재연결 시 이 상태만 확인해요. 완료됐다면 대화 이력을 다시 읽고, 실패했다면 재시도 버튼을 표시해요. 자동 답변 재생성과 스트림 이어받기는 첫 버전 범위에 넣지 않아요.
- `POST /api/conversations/turns/{turn_id}/retry/stream/`는 실패한 turn의 기존 입력·사용자 메시지를 재사용해 새 생성 시도를 시작해요. 진행 중 중복 요청은 409로 막고, 이미 완료된 turn은 새 답변을 만들지 않고 상태 조회를 안내해요. `POST /api/conversations/messages/{assistant_message_id}/audio/stream/`는 저장된 assistant 텍스트의 TTS만 다시 실행해 문장별 오디오 이벤트를 보내고 AI 답변은 재생성하지 않아요.
- 앱은 AI 답변 생성 실패 시 임시 부분 텍스트와 남은 재생 큐를 지우고 사용자 메시지 아래 오류·재시도 버튼을 표시해요. 같은 대화의 다음 발화는 이 실패를 재시도해 해결할 때까지 막아 대화 순서를 지켜요. 이미 들은 일부 음성은 취소할 수 없으므로 재시도 시 새 답변이 생성될 수 있음을 안내해요. Roleplay 첫 인사 실패는 준비 화면에 재시도 버튼을 보여줘요.

## 문장 분리·품질

토큰 하나마다 TTS를 호출하지 않아요. 문장부호를 기본 경계로 삼되 `Dr.`, `U.S.`, 소수점·따옴표·한국어 문장부호를 고려해요. 문장부호 없는 긴 출력에는 최대 길이·대기 시간과 자연스러운 구절 경계를 적용하고, 종료 시 남은 꼬리 문장 처리도 정해요.

첫 문장은 자연스럽고 짧게 유도할 수 있어요. 의미 없는 추임새로 지연을 가리는 것은 평가에서 제외해요. 문장마다 voice·속도·억양이 바뀌거나 첫 문장 뒤 긴 침묵이 생기면 성공으로 보지 않아요.

## 저장·실패·취소

- 확정 전사와 문법 입력은 같은 값을 써요. 이미 생성된 텍스트·합성된 범위·실제 재생된 범위를 구분하고 부분 답변을 정상 완료로 저장하지 않아요.
- 일부 음성을 들려준 뒤 다른 provider로 처음부터 fallback하면 내용이 달라질 수 있어요. 미완성 AI 답변은 실패로 종료하고 사용자의 명시적 재시도를 기다려요.
- 앱 취소·화면 이탈·disconnect 때 reader·TTS worker·응답 중계와 앱 재생 큐를 함께 정리해요. AI 텍스트가 아직 미완성이면 turn을 실패로, 이미 저장됐다면 turn을 완료·오디오 중단으로 기록해요. task를 await하고 HTTP response를 닫아요. 앱은 이전 `turn_id`·`attempt_id`의 늦은 이벤트를 버려요.
- 요청 종료 시 닫히는 DB session을 background나 장기 스트림이 계속 쓰지 않도록 분리해요. 오디오 전송 동안 DB transaction을 유지하지 않아요.

## 변경 예상 영역

| 영역 | 변경 |
|------|------|
| `backend/domains/llm/provider.py`, `openrouter.py` | 기존 completion 유지 + 토큰 async iterator |
| `backend/domains/voice/` | 문장별 합성, 이후 오디오 iterator |
| `backend/domains/conversation/` | 동시 pipeline, turn 상태·재시도·상태 조회·오디오 재합성, 스트림 전용 POST 경로 |
| `backend/main.py`, `shared/http_clients.py`, `shared/background_tasks.py` | 워커별 풀·문법 task 종료는 구현됨. 향후 스트리밍 응답 닫기·연결 점유·취소 전파를 추가 검증 |
| `mobile/lib/core/network/` | 증분 요청·이벤트 decoder·취소 |
| `mobile/lib/features/conversation/` | 부분 텍스트·오디오 큐·실패/취소 UX |
| `deploy/nginx/` | buffering·gzip·프록시 timeout 검증 |
| `.agent/_contracts/`, DSL, architecture | 구현 전에 계약과 설명을 동기화하고 README에서 연결 |

현재 nginx snippets에는 `proxy_buffering off`가 있어요. 실제 경로의 gzip·CDN·호스팅 프록시도 확인해야 해요. Content-Type·cache 정책·idle timeout을 명시하고 단말에서 청크 도착 간격을 검증해요.

## 권장 개발 순서

1~3단계는 `dev/mobile-stream` worktree에서 구현했어요. 3단계의 현재 앱 호출 전환은 주간 추천 시작만 대상이에요. 추천 시작의 텍스트는 이미 저장되므로 TTS 실패·연결 중단 뒤에도 유지하고, turn의 오디오 상태를 실패로 기록해요. 수동 오디오 재시도 UI와 다른 대화의 사용자 발화 보존·AI 재시도 연결은 4~6단계에서 완료해요.

1. **계약과 저장 정책을 먼저 확정해요.** 작성된 [DRAFT 계약](../.agent/_contracts/VOICE_STREAMING.md)의 경로, 요청, 이벤트, 실패 상태, 슬롯·발화 한도, 재시도·오디오 재합성 규칙을 검토해요. 구현과 함께 [DSL](DSL.md)·아키텍처·README 진입점을 동기화해요.
2. **영속 turn 기록과 재시도 기반을 만들어요.** 사용자 발화 보존, 중복 요청 차단, 상태 조회, 실패한 답변의 입력 재사용, 빈 Roleplay 시작 정리의 토대를 구현해요. 기존 JSON 경로의 응답과 저장 동작은 유지해요.
3. **주간 추천 시작으로 전송과 재생 큐를 먼저 연결해요.** 이미 저장된 첫 질문을 문장별 TTS·NDJSON·Base64로 보내고 Flutter의 증분 decoder와 순서 있는 오디오 큐까지 연결해요. 이 경로는 LLM 토큰 스트림 없이 전송·재생 문제를 먼저 확인할 수 있어요.
4. **기존 대화 `/turn/stream/`에 전체 동시 pipeline을 적용해요.** LLM 토큰 reader, 문장 분리, 제한된 큐, 단일 TTS worker, 중단·취소 전파를 연결해 STT 이후 첫 문장부터 재생해요. 부분 생성 실패와 TTS만 실패한 경우를 분리해요.
5. **나머지 대화 흐름으로 확장해요.** Free Chat·Roleplay 시작과 텍스트 `/message/stream/`에 같은 pipeline을 적용해요. 새 대화 시작 실패와 기존 대화 실패의 저장·슬롯 처리를 각각 확인해요.
6. **모바일 실패 UX와 복구를 연결해요.** 확정 사용자 발화, 임시 AI 텍스트, 재시도 버튼, turn 상태 조회, 음성만 다시 듣기, 화면 이탈 시 취소를 구현해요. 재연결 뒤에는 상태만 조회하고 답변 생성은 자동 시작하지 않아요.
7. **모든 흐름을 검증한 뒤 앱 호출을 전환해요.** 실기기의 첫 재생·문장 사이 공백, 프록시 청크 전달, 긴 동시 스트림의 자원 사용과 실패율을 확인해요. 백엔드 스트림 경로를 먼저 배포한 뒤 앱을 새 경로로 옮겨요. 구버전 앱의 JSON 경로는 유지해요.

3~5단계는 개발 중 수직 검증 순서예요. 첫 사용자 배포 범위에는 위 다섯 대화 경로와 재시도·복구 동작을 모두 포함해요.

## 검증 기준

1. 기존 POST는 JSON, 새 `/stream/` POST는 NDJSON을 반환하며 기존 경로에 회귀가 없는지 확인해요.
2. 같은 녹음·이력·모델에서 첫 토큰·첫 문장·첫 TTS 바이트·첫 재생을 각각 기록해요. 단계가 겹치므로 시간을 단순 합산하지 않아요.
3. 최초 10회는 탐색용으로 사용하고 표본·시간대·동시 사용자를 늘려 p50/p95와 실패율을 비교해요.
4. 첫 음성 지연뿐 아니라 문장 사이 gap·underrun·억양·비용을 확인해요.
5. 빈 출력·문장부호 없는 출력·마지막 문장·다국어·분할 UTF-8·큰 이벤트·순서 역전·중복을 테스트해요.
6. 첫 토큰 전/부분 재생 후 실패, TTS 실패, disconnect·취소·재연결 시 저장·재생 상태를 검증해요.
7. 오래 열린 동시 스트림에서 풀 고갈·큐 메모리·HTTP response·DB session 누수를 확인해요.
8. iOS/Android 실기기·블루투스·백그라운드 전환을 검증해요. 실제 음성 시작은 외부 녹음 또는 오디오 계측으로 보완해요.

## 참고

- [OpenRouter TTS](https://openrouter.ai/docs/guides/overview/multimodal/tts): byte stream 지원. 선택 모델의 실제 청크 지연은 검증 필요.
- [HTTPX async streaming](https://www.python-httpx.org/async/): 스트림 수신·정리 수명.
- [Dio ResponseType.stream](https://pub.dev/documentation/dio/latest/dio/ResponseType.html): Flutter HTTP 스트림 수신.

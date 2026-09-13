# 음성 응답 스트리밍 설계 제안

> 버전: 0.2 · 갱신: 2026-09-13 · 상태: PROPOSED, 스트리밍 미구현 · HTTP 풀 v1 기반 반영

## 목표

사용자가 말을 끝낸 뒤 첫 응답 음성을 듣기까지의 시간을 줄여요. LLM이 첫 문장을 완성하면 그 문장을 TTS에 전달하고, 앱이 첫 문장을 재생하는 동안 나머지 문장을 생성·합성해요.

현재 계측과 실험 절차는 [음성 지연 문서](VOICE_LATENCY.md)를 참조해요. 이 제안은 현재 [DSL](DSL.md)의 JSON 응답 계약을 변경하지 않아요.

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

초기에는 **새 opt-in 스트림 endpoint + POST NDJSON 응답**을 제안해요. 현재 `/turn/` JSON API는 유지해요. 최종 endpoint 이름·버전과 free-chat/roleplay 시작 경로는 구현 전에 계약으로 확정해요.

Flutter Dio의 `ResponseType.stream`을 쓰고 현재 공통 JSON envelope parser 대신 별도 증분 decoder를 두어요. UTF-8 문자가 chunk 사이에서 나뉠 수 있으므로 증분 UTF-8 디코딩 후 줄/이벤트를 조립해요. HTTP chunk 하나를 이벤트 하나로 취급하지 않아요.

## 이벤트 계약 초안 — 현재 API에 없음

| 이벤트 | 데이터 | 목적 |
|--------|--------|------|
| `turn_started` | turn ID, trace ID | 후속 이벤트의 소유권 |
| `transcript_final` | 확정 전사, 사용자 message ID | 말풍선·문법 평가 연결 |
| `text_delta` | 텍스트 조각, 순번 | 텍스트 선표시 |
| `audio_segment` | 문장 번호, 텍스트, 형식, Base64 오디오 | 1단계 완성 오디오 큐 |
| `audio_error` | 실패 문장 번호, 오류 코드 | 텍스트 유지·음성 실패 안내 |
| `turn_completed` | 최종 텍스트, 메시지 ID, 저장 상태 | 정상 완료 |
| `turn_error` | 오류 코드, 재시도 가능 여부 | 중간 실패 종료 |

JSON 문자열의 줄바꿈을 escape하고 이벤트 한 개를 한 줄로 구분해요. Base64는 원시 바이트보다 약 33% 커지므로 1단계의 구현 편의와 전송량을 비교해요. 2단계에서는 바이너리 framing이나 별도 오디오 경로를 다시 정해야 해요.

- turn ID와 순번으로 중복·뒤늦은 이벤트를 거르고 재생 순서를 지켜요.
- 문장 수·바이트 수로 큐를 제한해요. 느린 수신자에 맞춰 생성 속도를 조절하거나 중단하며 메모리를 무제한 사용하지 않아요.
- 헤더 전 인증·검증 실패는 HTTP 상태로 반환해요. 스트림 시작 뒤에는 상태 코드를 바꿀 수 없으므로 오류 이벤트를 보내요. terminal event 없이 끊기면 정상 완료로 간주하지 않아요.
- 전체 turn 제한, 첫 토큰·첫 오디오·idle timeout을 구분해요. heartbeat로 처리 제한을 무한히 늘리지 않아요.

## 문장 분리·품질

토큰 하나마다 TTS를 호출하지 않아요. 문장부호를 기본 경계로 삼되 `Dr.`, `U.S.`, 소수점·따옴표·한국어 문장부호를 고려해요. 문장부호 없는 긴 출력에는 최대 길이·대기 시간과 자연스러운 구절 경계를 적용하고, 종료 시 남은 꼬리 문장 처리도 정해요.

첫 문장은 자연스럽고 짧게 유도할 수 있어요. 의미 없는 추임새로 지연을 가리는 것은 평가에서 제외해요. 문장마다 voice·속도·억양이 바뀌거나 첫 문장 뒤 긴 침묵이 생기면 성공으로 보지 않아요.

## 저장·실패·취소

- 확정 전사와 문법 입력은 같은 값을 쓰고 문법은 background에 유지해요.
- 현재 서비스는 전체 LLM 답변을 받은 뒤 assistant 메시지를 저장해요. 스트리밍에는 pending/completed/failed/cancelled 상태와 부분 결과 저장 정책이 필요해요. 이미 생성된 텍스트·합성된 범위·실제 재생된 범위를 구분하고 부분 답변을 정상 완료로 저장하지 않아요.
- 연결 중단 후 자동 재생성은 메시지·비용을 중복시킬 수 있어요. 안정적인 turn ID, 멱등성·재개 정책을 먼저 정해요. 현재 `X-Request-ID`는 진단 값이며 멱등 키가 아니에요.
- 일부 음성을 들려준 뒤 다른 provider로 처음부터 fallback하면 내용이 달라질 수 있어요. 중간 실패를 명시하고 새 turn과 재개를 구분해요.
- 앱 취소·화면 이탈·disconnect 때 reader·TTS worker·응답 중계와 앱 재생 큐를 함께 정리해요. task를 await하고 HTTP response를 닫아요.
- 요청 종료 시 닫히는 DB session을 background나 장기 스트림이 계속 쓰지 않도록 분리해요. 오디오 전송 동안 DB transaction을 유지하지 않아요.

## 변경 예상 영역

| 영역 | 변경 |
|------|------|
| `backend/domains/llm/provider.py`, `openrouter.py` | 기존 completion 유지 + 토큰 async iterator |
| `backend/domains/voice/` | 문장별 합성, 이후 오디오 iterator |
| `backend/domains/conversation/` | 동시 pipeline, turn 상태, 스트림 endpoint |
| `backend/main.py`, `shared/http_clients.py`, `shared/background_tasks.py` | 워커별 풀·문법 task 종료는 구현됨. 향후 스트리밍 응답 닫기·연결 점유·취소 전파를 추가 검증 |
| `mobile/lib/core/network/` | 증분 요청·이벤트 decoder·취소 |
| `mobile/lib/features/conversation/` | 부분 텍스트·오디오 큐·실패/취소 UX |
| `deploy/nginx/` | buffering·gzip·프록시 timeout 검증 |
| `.agent/_contracts/`, DSL, architecture | 구현 전에 계약과 설명을 동기화하고 README에서 연결 |

현재 nginx snippets에는 `proxy_buffering off`가 있어요. 실제 경로의 gzip·CDN·호스팅 프록시도 확인해야 해요. Content-Type·cache 정책·idle timeout을 명시하고 단말에서 청크 도착 간격을 검증해요.

## 검증 기준

1. 기존 JSON 경로의 회귀가 없고 새 경로는 opt-in인지 확인해요.
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

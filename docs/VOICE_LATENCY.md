# 음성 대화 지연 계측과 반복 실험

> 버전: 1.1 · 갱신: 2026-09-13 · 현재 브랜치 계측 구현과 향후 최적화 검토

## 결정과 범위

- 현재 `dev/mobile` 브랜치에 STT → LLM → TTS와 앱 재생의 경과 시간을 `print()`로 기록해요.
- API의 기존 JSON 본문과 대화 동작은 유지해요. 요청 식별 헤더로 서버·앱 로그를 연결해요.
- AsyncClient 연결 풀 v1을 적용했어요. 기존 print 계측으로 적용 후 시간을 수집하고, 확보한 적용 전 표본과 같은 조건으로 비교해요.
- [스트리밍 설계](VOICE_STREAMING.md)는 향후 구현을 위한 제안이며 활성 API 계약이 아니에요.
- 로그의 성공·실패 전파, 동시 요청 구분, 재생 시작과 완료 구분을 검증해요. 기존 음성·대화·인증 테스트를 회귀 검증에 사용해요.

## 계측 지표

서버는 Python `perf_counter()`, 앱은 Dart `Stopwatch`를 사용해요. 절대 시각을 서로 빼지 않아요. 신규 로그는 `[latency] ` 뒤에 JSON 한 줄을 출력하며 원문·인증 토큰·오디오 데이터는 포함하지 않아요.

| 위치 | stage | elapsed_ms의 의미 |
|------|-------|-------------------|
| 서버 | `auth` | Supabase 검증 + profile 조회/갱신 |
| 서버 | `stt` | provider 호출 시작 → 전사 결과 수신; 파일 검증은 제외 |
| 서버 | `llm` | provider 호출 시작 → 전체 답변 수신; 프롬프트 조립·DB 작업은 제외 |
| 서버 | `tts` | provider 호출 시작 → 전체 오디오 수신 |
| 서버 | `audio_encode` | 오디오 Base64 인코딩 + 응답 모델 구성 |
| 서버 | `server_total` | ASGI 요청 진입 → 최종 응답 body를 서버 전송 계층에 전달 완료 |
| 앱 | `recording_ready` | recorder.stop() 호출 → 녹음 파일 읽기·정리 완료 |
| 앱 | `http_response` | API 호출 → Dio의 응답 수신·JSON 변환 완료 |
| 앱 | `http_total` | API 호출 → 도메인 응답 파싱까지 완료 또는 실패 |
| 앱 | `audio_decode` | 재생용 Base64 디코딩 |
| 앱 | `playback_requested` | 로컬 측정 시작 → 플레이어 재생 요청 직전 |
| 앱 | `playback_started` | 재생 요청 → 플레이어 playing 이벤트; 첫 재생만 기록 |
| 앱 | `playback_error` | 로컬 측정 시작 → 재생 실패 |

- 서버 `trace_id`는 앱이 보낸 `X-Request-ID`와 같아요. 소문자 16진수 32자리만 허용하고, 누락·잘못된 값은 서버가 새로 만들어요. 응답 헤더에도 돌려줘요. 식별자는 인증이나 멱등성을 제공하지 않아요.
- 서버 `request_id`는 매 HTTP 요청마다 새 값이에요. 앱의 자동 인증 재시도가 같은 `trace_id`를 써도 서로 다른 시도로 구분할 수 있어요.
- 앱의 `since_start_ms`는 전체 로컬 경과 시간이에요. `playback_started`의 이 값을 최종 체감 지표로 사용해요. `elapsed_ms`는 플레이어 준비 시간만 나타내요.
- `origin=recording_stop`은 녹음 종료 함수 호출부터, `origin=http_request`는 텍스트 전송·파일 재시도 등의 HTTP 호출부터예요. 녹음 종료는 실제 발화 종료와 달라요. 말한 뒤 버튼을 누르기까지의 침묵은 포함되지 않아요.
- 도메인 응답 파싱 시에만 Dart Zone으로 trace를 전달하고, 오디오 객체에 로컬 필드로 보관해요. 재생 시점에는 이 필드를 사용하며 전역의 마지막 요청을 참조하지 않아요. 오디오 재시도는 새 trace를 쓰고, 동일 응답의 재생 반복은 첫 재생 표본을 추가하지 않아요.
- `status=error`는 실패나 취소를 포함해요. 서버 `server_total`에는 HTTP 상태도 있어요. TTS 실패는 기존 API 정책상 HTTP 200 + `audio_error`일 수 있으므로 `tts` 실패와 응답의 `audio_error`도 확인해요.
- LLM 로그에는 모델·입출력 문자 수와 제공되는 경우 입력/출력 토큰 수, STT/TTS에는 입력 크기나 출력 바이트 수를 남겨요. 실패 표본을 성공 표본과 섞어 평균 내지 않아요.
- `server_total`은 단말의 수신 완료 시간이 아니에요. 앞단 nginx가 버퍼링한 업로드 시간과 클라이언트 재생은 포함하지 않아요. 서버 시작 전 프록시 대기도 측정할 수 없어요.
- `http_response`와 `http_total`, `server_total`과 개별 stage는 서로 포함 관계예요. 전부 더하지 않아요. 앱 HTTP 시간에서 서버 시간을 뺀 차이에도 전송·프록시·앱 처리 등이 섞여 있으므로 순수 네트워크 지연이라고 부르지 않아요.
- 현재 API는 비스트리밍이므로 LLM 첫 토큰·첫 문장, TTS 첫 바이트 지연은 아직 측정하지 않아요. provider 시간에는 네트워크·연결 수립·업체 대기열·생성이 모두 포함돼요.
- `playing` 이벤트는 실제 스피커 출력의 근사치예요. 앱에서는 재생 완료를 기다리는 기존 `play()` 호출 전후를 첫 재생 지연으로 사용하지 않아요. 이벤트를 받지 못했거나 재생 오류가 난 경우 표본이 누락됐음을 기록하고 성공으로 간주하지 않아요.

대상은 `POST /api/conversations/start/free-chat/`, `/start/roleplay/`, `/{id}/turn/`, `/{id}/message/`예요. 문법 background task와 polling은 별도로 시간을 출력하지 않아요. 전체 응답을 기다리지 않는 background 작업의 완료 시간도 server_total에 넣지 않아요. 로그 출력은 단계당 한 번이며, `print()` 자체의 작은 오버헤드는 있어요.

## 로그 확인

저장소 루트에서 서버를 실행할 때 stdout을 저장해요. 비밀 값을 포함한 `.env` 전체를 출력하지 않아요.

```bash
cd backend
./.venv/bin/python -u -m uvicorn main:app --host 0.0.0.0 --port 8010 2>&1 | tee /tmp/convia-server.log
```

앱은 다른 터미널에서 실행해요. 같은 실험 내에서는 같은 빌드 모드·기기를 사용하고 실제 성능 비교에는 가능하면 실기기의 profile 빌드를 써요. 아래 JSON 파일에는 [모바일 실행 설정](../mobile/README.md)의 `API_BASE_URL`, Supabase·Google 공개 설정을 넣어요. 실기기에서는 API 주소에 개발 PC의 접근 가능한 IP를 사용해요. 서버 API 키는 넣지 않아요. 기존 `--dart-define` 실행 옵션을 그대로 쓰면서 `--profile`만 추가해도 돼요.

```bash
cd mobile
flutter run --profile --dart-define-from-file=/absolute/path/mobile-config.json 2>&1 | tee /tmp/convia-mobile.log
```

```bash
rg '\[latency\]' /tmp/convia-server.log /tmp/convia-mobile.log
```

출력 형식 예시이며 실제 측정값은 아니에요:

```text
[latency] {"source":"server","trace_id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","request_id":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","stage":"stt","status":"ok","elapsed_ms":820.0}
[latency] {"source":"mobile","trace_id":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","origin":"recording_stop","stage":"playback_started","status":"ok","elapsed_ms":85.0,"since_start_ms":2410.0}
```

## 10회 반복 실험

### A. 고정 녹음 파일로 서버 병목 비교

첫 실험은 알아듣기 쉬운 영어 발화가 담긴 짧은 WAV 파일 하나를 권장해요. 같은 파일·모델·계정 언어·프롬프트 조건으로 10회 순차 실행해요. iOS의 현재 녹음 형식은 16kHz mono WAV예요. 다른 파일을 쓰면 지원 형식과 content type을 맞춰요.

매번 **새 자유 대화 시작 API**를 호출하면 이전 답변이 다음 요청 이력에 추가되지 않아요. 같은 대화의 `/turn/`을 10회 호출하면 이력이 늘어 비교 조건이 달라져요. 시작 API 측정만으로 긴 대화 성능을 대표하지는 않아요. 이어 말하기 비교는 동일한 이력을 준비한 별도 대화들로 추가 실험해요.

아래 예시는 저장소 루트에서 실행해요. 파일 경로와 API 주소를 자신의 환경에 맞춰 바꿔요. 토큰은 실행 시 숨김 입력해요. **실제 STT/LLM/TTS 사용량과 테스트 대화 10개가 생성돼요.** 자동 삭제하지 않으며 나중에 앱에서 테스트 대화를 정리할 수 있어요.

```bash
backend/.venv/bin/python - <<'PY'
import csv
import getpass
import time
import uuid
from pathlib import Path
from statistics import median
import httpx

audio = Path('/absolute/path/recording.wav').read_bytes()
url = 'http://localhost:8010/api/conversations/start/free-chat/'
token = getpass.getpass('Supabase access token: ')
rows = []
with httpx.Client(timeout=180.0) as client:
    for run in range(1, 11):
        trace_id = uuid.uuid4().hex
        started = time.perf_counter()
        status, conversation_id = 'error', ''
        try:
            response = client.post(
                url,
                headers={'Authorization': f'Bearer {token}', 'X-Request-ID': trace_id},
                files={'audio_file': ('recording.wav', audio, 'audio/wav')},
                data={'include_audio_response': 'true'},
            )
            response.raise_for_status()
            payload = response.json()
            data = payload.get('data') or {}
            conversation_id = str(data.get('conversation_id', ''))
            status = 'ok' if payload.get('success') and data.get('audio') and not data.get('audio_error') else 'audio_or_api_error'
        except (httpx.HTTPError, ValueError) as error:
            status = type(error).__name__
        elapsed_ms = round((time.perf_counter() - started) * 1000, 1)
        row = dict(run=run, trace_id=trace_id, status=status, elapsed_ms=elapsed_ms, conversation_id=conversation_id)
        rows.append(row)
        print(row, flush=True)
        if run < 10:
            time.sleep(3)  # background 문법 요청과 과도하게 겹치지 않도록 간격 고정

with open('/tmp/convia-voice-runs.csv', 'w', newline='') as output:
    writer = csv.DictWriter(output, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
success = [row['elapsed_ms'] for row in rows if row['status'] == 'ok']
print({'successes': len(success), 'attempts': len(rows), 'median_ms': median(success) if success else None})
PY
```

180초는 실험 클라이언트의 제한이며 서버나 앱 설정을 바꾸지 않아요. 실제 앱은 현재 receive timeout이 30초이므로 서버 실험이 성공해도 앱에서는 timeout일 수 있어요. 성공·실패 수와 서버의 STT/TTS timeout도 함께 봐요. 3초 간격이 background 작업 완료를 보장하지는 않으며 동일 간격을 유지하고 영향을 기록해요.

첫 표본을 별도 표시하고 나머지 표본과 비교해요. 첫 요청이라고 제공업체 모델의 cold start가 보장되지는 않아요. 동일 파일 반복은 제공업체 캐시의 영향을 받을 수 있어요. 변경 전후 비교는 같은 조건으로 수행하고, 가능하면 두 조건을 번갈아 측정해 시간대 변동을 줄여요.

### B. 실기기에서 직접 말하기

서버 실험 뒤 앱에서 같은 문장을 직접 10회 말해보면 좋아요. 시작/이어 말하기를 구분하고, 녹음 길이·대화 이력 길이·기기·Wi-Fi/셀룰러·출력 장치(스피커/블루투스)·빌드 모드를 기록해요. 앱 `playback_started.since_start_ms`를 비교하고 UI 전환이나 첫 플레이어 초기화의 영향도 확인해요. 이 실험에는 녹음·단말 업로드·다운로드·플레이어 비용이 들어가요.

서버 호출 스크립트는 앱의 녹음·재생을 측정하지 못해요. 서버 실험 CSV와 직접 말하기 로그를 하나의 평균으로 합치지 않아요. **고정 파일 실험은 원인 비교용, 직접 말하기는 사용자 체감 검증용**이에요.

### 표본 해석

- 10회는 병목과 큰 개선 신호를 찾는 탐색 실험이에요. 원자료·중앙값·최댓값·성공/실패 수를 함께 보관해요.
- 이 표본으로 안정적인 p95/p99 또는 동시 사용자 처리 용량을 주장하지 않아요. 5% 확률의 지연이 독립적으로 발생한다고 가정하면 10회 모두 놓칠 확률은 `0.95 ** 10 ≈ 60%`예요.
- 후보 변경을 정한 다음 표본·시간대·실제 동시 요청 수를 늘려 검증해요. 수백 회도 환경 변동을 충분히 대표하는지 확인해야 해요.
- 파일 전사·답변 길이가 달라질 수 있으므로 `input_chars`, `output_chars`, 토큰 수, `output_bytes`도 확인해요. 짧은 답변 때문에 빨라진 것을 연결 재사용 효과라고 판단하지 않아요.

## AsyncClient 연결 풀 v1 — 적용 완료

기존에는 외부 API를 호출할 때마다 client를 생성·종료했어요. 이제 앱 워커마다 AI용·Supabase 인증용 client를 각각 만들고 여러 요청에서 재사용해요. 설정을 추가하지 않아도 기본값으로 적용되며 **실행 중인 서버를 재시작해야 해요.**

| 코드 | 적용 내용 |
|------|-----------|
| `backend/shared/http_clients.py`, `backend/main.py` | 워커 lifespan에서 두 client 생성·종료, dependency로 전달 |
| `backend/domains/llm/{factory,openrouter,ollama}.py` | 전달받은 client로 LLM 요청, provider에서 client를 닫지 않음 |
| `backend/domains/voice/{service,openrouter_provider,openai_provider}.py` | STT와 TTS가 같은 AI 풀 사용 |
| conversation·grammar·search·language_snacks 서비스와 router | 모든 factory 호출에 명시적으로 client 전달 |
| `backend/domains/auth/{dependencies,supabase,service}.py` | 원격 토큰 검증·Swagger 토큰 발급에 별도 auth 풀 사용 |
| `backend/shared/background_tasks.py`, conversation 서비스 | 문법 task 추적·종료 대기·취소 후 정리, 저장 시 별도 DB session 사용 |
| `backend/scripts/generate_language_snacks.py` | CLI 이벤트 루프에서 AI client를 소유하고 en/ko 실행 간 재사용 |

각 풀의 초기값은 최대 연결 100개·유휴 연결 20개·유휴 만료 30초예요. 연결은 필요할 때 생성하고 유휴 연결은 계속 영구 보관하지 않아요. 워커가 4개라면 AI 4개+auth 4개, 총 8개 풀이에요. 설정 항목은 [환경변수 문서](ENVIRONMENT.md), 수명과 소유권의 단일 기준은 [아키텍처](../.agent/architecture.md#외부-http-연결-풀-v1--구현-결정-2026-09-13)예요.

- OpenRouter LLM 30초, Ollama 60초, 음성·인증 설정의 connect/read/write/pool timeout을 유지해요. 이는 요청 전체의 절대 마감 시간이 아니에요. 자동 재시도나 HTTP/2는 추가하지 않았어요.
- 사용자 토큰과 provider 키는 요청별 헤더로 전달해요. 공유 client의 인증 헤더를 변경하지 않고 upstream 쿠키 저장을 거부해 사용자별 쿠키가 다음 요청으로 넘어가지 않게 해요.
- 같은 이벤트 루프 안에서 여러 요청이 client를 공유해요. 전역 singleton을 다른 루프·프로세스에 넘기지 않아요. 오래 대화해도 client에 대화 이력을 쌓지 않으며 이력은 기존 DB·프롬프트 경로로 관리돼요.
- 연결 수를 넘으면 pool timeout까지 기다려요. AI와 auth는 분리했지만 AI 안에서는 대화·음성·문법·검색·운영 스낵 생성이 경쟁해요. 현재 한도를 사용자 처리 용량으로 해석하지 않고 실제 동시 요청으로 검증해요.
- 종료 시 문법 task를 기본 5초 기다린 뒤 남은 작업을 취소하고 정리 완료를 await한 다음 HTTP client를 닫아요. 취소된 문법 피드백은 저장되지 않을 수 있어요. 재시작 후 자동 재개하는 영속 작업 큐는 없어요. 강제 종료(SIGKILL)에는 정리 완료가 보장되지 않아요.
- 테스트나 독립 스크립트에서 실제 provider를 사용할 때는 client를 직접 주입하고 async context로 닫아야 해요. FastAPI 테스트는 lifespan을 실행하거나 HTTP dependency를 명시적으로 대체해요.

```python
from config import get_settings
from domains.llm.factory import LLMProviderFactory
from shared.http_clients import create_http_client

async def generate(request):
    async with create_http_client(get_settings()) as client:
        provider = LLMProviderFactory.create_provider(http_client=client)
        return await provider.chat_completion(request)
```

위 예시는 독립 실행 한 번의 소유권 예시예요. 여러 번 호출하는 CLI라면 반복문 밖에서 한 번만 client를 만들어요. FastAPI의 각 요청 핸들러에 위 context를 복사하지 않아요.

HTTPX는 유휴 5초가 기본이지만 여기서는 발화 간격을 고려해 초기값 30초를 사용해요. upstream이 먼저 연결을 닫거나 간격이 이보다 길면 새 연결이 필요해요. 연결 재사용은 TLS/연결 수립 비용을 줄일 수 있으나 모델 추론 자체를 빠르게 만들지는 않아요. 실제 개선 폭은 위 실험으로 확인해야 해요.

참고: [HTTPX async 사용](https://www.python-httpx.org/async/), [연결 풀 제한](https://www.python-httpx.org/advanced/resource-limits/).

## 구현 검증 기록

연결 풀 v1 적용 후 백엔드 전체 테스트는 **175개 통과·3개 skip**이에요. 추가한 29개 테스트에서 localhost HTTP/1.1 요청 3회가 TCP 연결 1개를 재사용하는 것, 유휴 만료 후 새 연결, 풀 한도·pool timeout·후속 요청 복구, 인증 헤더·쿠키 분리, provider별 timeout·오류 유지, 실제 대화 경로의 client 주입과 별도 문법 DB session, CLI 정상/실패 종료를 확인했어요. 백엔드에는 별도 lint/typecheck 명령이 설정돼 있지 않으며 `git diff --check`를 통과했어요.

배포 후에는 같은 고정 녹음 파일로 서버 `stt`·`llm`·`tts`·`auth`와 앱 첫 재생 로그를 비교하고, 성공·실패 수와 pool timeout 여부를 함께 확인해요. 모델·답변 길이·실험 간격은 고정해요. 운영 동시 부하와 외부 API의 실제 지연 개선 폭은 아직 측정하지 않았어요.

아래는 앞선 print 계측 단계의 검증 기록이에요.

2026-09-13 기준 백엔드 전체 테스트는 146개 통과·3개 skip, Flutter 전체 테스트는 232개 통과했어요. 마지막 재생 이벤트 소유권·오류 로그 보완 후 관련 Flutter 테스트 19개를 다시 통과했고, `flutter analyze --no-pub`도 문제가 없었어요. 동시 요청의 trace 분리, 오류·취소 전파, 서비스 단계 로그, 응답과 첫 재생 trace 연결을 검증했어요.

실제 외부 API를 호출하는 10회 실험과 실기기 스피커 출력 측정은 아직 수행하지 않았어요. 이 변경은 측정 수단을 추가한 것이며, 응답 속도가 개선됐다는 측정 결과는 아니에요.

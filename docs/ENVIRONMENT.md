# 외부 HTTP 연결 풀 설정

> 버전: 1 · 갱신: 2026-09-13

백엔드 [Settings](../backend/config.py)는 저장소 루트 `.env`를 읽어요. 실행 프로세스의 환경변수가 우선하며 변경 후 서버를 재시작해요. [.env.example](../.env.example)과 [전체 환경변수 안내](../README.md#환경-변수)를 참조해요.

| 변수 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `HTTP_MAX_CONNECTIONS` | 아니오 | `100` | 워커 내 각 외부 HTTP 풀의 최대 연결 수. 1 이상 |
| `HTTP_MAX_KEEPALIVE_CONNECTIONS` | 아니오 | `20` | 각 풀의 최대 유휴 연결 수. 0 이상이고 MAX_CONNECTIONS 이하 |
| `HTTP_KEEPALIVE_EXPIRY_SECONDS` | 아니오 | `30` | 재사용할 유휴 연결의 만료 시간(초). 유한한 양수 |
| `BACKGROUND_SHUTDOWN_GRACE_SECONDS` | 아니오 | `5` | 종료 시 문법 task 완료 대기 시간(초). 이후 취소하고 정리 완료를 기다림. 유한한 0 이상 |

AI(LLM·STT·TTS·문법·검색·스낵)와 Supabase 인증은 워커마다 별도의 풀을 가져요. 기본 한도는 각각 100개라 워커 4개면 전체 상한은 최대 800개예요. 미리 연결을 열지는 않아요. 위 설정은 HTTP/1.1 연결 수이며 요청당 timeout(OpenRouter LLM 30초·Ollama 60초·음성/인증 개별 설정)을 바꾸지 않아요. 유휴 만료 전에 upstream이 연결을 닫을 수도 있어요. 실제 동시성에 맞춰 조절하고 변경 후 재시작해요. 내부 수명은 [아키텍처](../.agent/architecture.md#외부-http-연결-풀-v1--구현-결정-2026-09-13)를 참조해요.

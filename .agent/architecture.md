# 시스템 아키텍처

> 프로젝트: MoreThanHuman (Convia) · 버전: 0.1.2 · 최종 갱신: 2026-09-13

---

## 1. 스택

### Backend

| 기술 | 버전 | 역할 |
|------|------|------|
| Python | ≥ 3.12 | 런타임 |
| FastAPI | 0.109.0 | API 프레임워크 |
| SQLAlchemy | 2.0.25 | ORM |
| Pydantic | 2.5.3 | 데이터 검증 |
| pydantic-settings | 2.1.0 | 환경 설정 |
| uvicorn | 0.27.0 | ASGI 서버 |
| httpx | 0.26.0 | 외부 HTTP 클라이언트 |
| Supabase Auth | managed | 모바일 소셜 로그인과 세션 관리 |
| python-jose | ≥ 3.3.0 | 레거시 JWT tooling / JWT 유틸리티 |
| bcrypt | ≥ 4.0.0 | 비밀번호 해싱 |
| ddgs | ≥ 9.0.0 | 웹 검색 |
| psycopg2-binary | 2.9.9 | PostgreSQL 드라이버 |

### Database

| 기술 | 용도 |
|------|------|
| SQLite | 개발 기본값 |
| PostgreSQL | 프로덕션 |

### Client

| 기술 | 상태 |
|------|------|
| Flutter 3.44.2 / Dart 3.12.2 | `mobile/` iOS·Android 프로젝트 초기화 |
| Riverpod 3 | 앱 상태와 비동기 상태 관리 |
| go_router 17 | 선언형 라우팅과 인증 redirect |
| Dio 5 | FastAPI HTTP client와 interceptor |
| flutter_secure_storage 10 | 설치 단위 device ID와 온보딩 상태 보관 |
| supabase_flutter 2 | Supabase Auth 세션 관리 |
| google_sign_in 7 | Google SDK 기반 모바일 인증 |

현재 저장소는 FastAPI 백엔드 API와 Flutter 모바일 앱을 함께 관리해요.

---

## 2. 시스템 구조

**아키텍처 패턴**: FastAPI Modular Monolith + Flutter Mobile Client

```text
backend/
├── main.py                  # FastAPI 앱 초기화, 라우터 등록
├── config.py                # Pydantic BaseSettings 환경 설정
├── database.py              # SQLAlchemy 엔진·세션 팩토리
├── shared/                  # 공통 타입, 언어 컨텍스트, prompt policy, 예외, 유틸리티
└── domains/                 # 도메인별 수직 슬라이스
    ├── auth/                # Supabase token 검증, profiles 연결
    ├── conversation/        # 대화 관리
    ├── grammar/             # 문법 체크 및 통계
    ├── llm/                 # LLM 프로바이더 추상화
    ├── search/              # ddgs 검색 + query analysis + LLM source judge + LLM 요약
    ├── voice/               # STT/TTS provider 추상화와 OpenRouter/OpenAI Audio 연동
    └── web/                 # 서버 렌더링 HTML 라우트

mobile/
├── android/                 # Android runner
├── ios/                     # iOS runner
├── lib/
│   ├── main.dart            # ProviderScope 앱 진입점
│   ├── app/                 # 앱, router, theme
│   ├── core/                # config, Dio API, secure token storage, 공통 widget
│   └── features/            # feature-first 화면, 상태, 도메인 widget
│       ├── auth/            # Riverpod 인증 상태, 모바일 auth API
│       ├── conversation/    # 대화 API, 메시지 전송, grammar polling, UI
│       ├── home/            # 최근 대화 API 상태와 Home UI
│       ├── language/        # 언어쌍 모델, preference API, selector UI
│       ├── onboarding/      # 완료 상태와 pending 언어쌍 저장, 4장 onboarding UI
│       ├── roleplay_setup/  # 롤플레이 상황 선택 UI
│       └── topic_prep/      # Topic Input, 검색 준비 카드 API 상태와 UI
├── test/                    # Flutter 테스트
└── pubspec.yaml             # Dart/Flutter 의존성
```

Flutter API 요청은 `ApiClient → AuthTokenInterceptor → TokenRefreshInterceptor → Dio` 순서로 실행돼요. 응답은 공통 envelope parser를 거쳐 feature decoder로 전달해요. Supabase SDK가 access/refresh session을 관리하고, `AuthTokenInterceptor`는 현재 Supabase access token을 `Authorization: Bearer` 헤더로 주입해요. 여러 요청이 동시에 `401`을 받아도 Supabase refresh는 하나만 공유하며, 새 access token으로 각 요청을 한 번만 재시도해요.

Home의 `language_snacks`는 최근 대화와 독립된 학습 콘텐츠 흐름이에요. v2 feed는 profile.target_language와 content_language가 같은 published 최신 12개를 반환해요. Flutter는 학습 언어 변경 시 즉시 다시 조회하고, Home 재진입·앱 복귀 시 마지막 성공 조회가 5분 이상 지났으면 갱신해요. API 실패에는 언어·설명 언어별 secure storage 캐시만 사용하고 캐시가 없으면 해당 영역만 숨겨요. 이전 언어의 지연 응답은 버리며 5초 슬라이드 타이머는 네트워크를 호출하지 않아요.

스낵 v2(2026-09-12)는 세 유형의 `payload`와 지식 `identity`를 JSONB로 저장해요. identity는 NFC·공백 정규화, 객체 키·entry 순서 정렬 후 SHA-256을 계산해 UNIQUE로 보호하며 대소문자·sense는 보존해요. LLM은 같은 content_language의 모든 상태·유형 요약 이력을 보고 별도로 의미 중복을 판정해요. reserved를 먼저 저장하고 본문 구조·품질 검증 후 published로 전환하며 재시도 소진이나 운영 취소는 archived로 남겨 재생성하지 않아요. draft는 향후 편집용 상태로 현재 경로에서는 따로 저장하지 않아요.

주간 CLI는 API 이미지의 별도 작업 컨테이너에서 en/ko run을 순서대로 실행해요. 영속 `run_key`는 주간 슬롯+언어의 재실행을 멱등하게 만들고 예약을 우선 재개해요. scheduled_for 별도 컬럼 대신 run_key의 주간 날짜를 사용해요. metrics에는 후보 rounds, calls, charged_tokens, reported_tokens, published_by_type와 발생한 중복·불확실 수/오류 코드가 저장돼요. 후보 라운드·호출·토큰 상한은 run에 누적되며 본문 시도 횟수는 예약 metadata에 저장돼요. 실행 시간 상한은 언어별 시도에 적용해요. reserved/published/archived 개수로 예약·발행·실패를 추가 집계할 수 있어요.

운영 POST·PATCH와 CLI 쓰기는 같은 PostgreSQL session advisory lock을 획득해 직렬화해요. 전용 direct/session 연결에 잠금을 유지하고 LLM 대기 중 ORM 트랜잭션은 열어두지 않아요. 잠금 연결을 잃으면 추가 저장을 중지해요. SQLite 잠금은 단일 프로세스 개발용이에요. 전체 이력 크기를 넘으면 과거 항목을 생략하지 않고 중단하며 LLM 의미·품질 판정에는 오차가 남아요. API는 구버전 GET에 빈 목록, 구버전 POST에 410을 제공해요. 상세 외부 계약은 [DSL](../docs/DSL.md), 파괴적 migration·cron 설치·롤백은 [운영 가이드](../docs/OPERATIONS.md), 환경변수는 [환경 설정](../docs/ENVIRONMENT.md)이 기준이에요. [README](../README.md)는 실행·CLI 진입점으로 유지해요.

Flutter 앱 시작은 `Splash → Onboarding(최초 1회) → Google Login → Home` 순서예요. `go_router`가 onboarding 완료 상태와 Riverpod 인증 상태를 함께 관찰하며, 인증 복원 중에는 Splash를 유지하고 로그인 성공 또는 세션 만료 시 Home/Login으로 redirect해요. `AppCopy`는 system locale이 `ko`일 때 한국어, 그 밖에는 영어로 app chrome·접근성 label·클라이언트 오류를 표시하고 학습 언어 context를 바꾸지 않아요. Onboarding은 기기 locale로 `ko -> en`, `en -> ko` 기본값을 고르고, 중국어가 포함된 언어쌍은 화면에 표시하되 선택은 막아요. 사용자가 현재 선택 가능한 지원 언어쌍(`ko -> en`, `en -> ko`) 중 하나를 확정하면 pending language context를 secure storage에 저장해요. 인증이 생기면 `authControllerProvider`가 `PUT /api/auth/me/language-preferences`로 pending 값을 서버에 동기화하고 `/api/auth/me`로 profile language를 hydration한 뒤 Home을 표시해요. Home은 활성 언어쌍과 `/api/conversations/?limit=5&offset=0` 최근 대화 loaded/empty/error 상태를 표시해요. Account sheet의 언어쌍 설정은 profile default만 갱신하며 새 대화부터 적용되고 기존 conversation은 snapshot을 유지한다고 안내해요. Free Chat 선택 시 `Topic Input → Topic Prep`으로 이어져 `POST /api/search/topic-prep/`의 ready/low-quality/error 상태를 보여주고, 첫 답변 제출 후 `POST /api/conversations/start/free-chat/`로 Conversation 화면에 진입해요. Topic Input 정적 예시 검색어는 system locale이 아니라 native language로 고르고 그대로 검색 요청에 보내요. Roleplay 선택 시 `Roleplay Setup`에서 target language에 맞는 preset/custom 상황을 고르고 `role_character`로 `POST /api/conversations/start/roleplay/`를 호출해 같은 Conversation 화면에 진입해요. Topic Prep과 Roleplay 콘텐츠 선택은 target language를 따르고, retry guidance나 짧은 설명은 feedback language를 따르는 정책을 유지해요. Backend LLM prompt policy도 같은 원칙을 써서 target language가 conversation, roleplay, grammar, Topic Prep의 연습·교정 기준을 정하고 feedback language는 설명·retry 안내 언어만 정해요. 이 정책은 STT/TTS나 provider/model routing을 변경하지 않아요. Home 최근 대화 카드도 `/conversation/:conversationId`로 이동해 기존 메시지를 이어가요.

도메인은 기본적으로 아래 계층을 따라요:

```text
domains/{name}/
├── models.py       # SQLAlchemy 모델
├── schemas.py      # Pydantic 요청/응답 스키마
├── enums.py        # Enum 정의
├── repository.py   # 데이터 접근 계층
├── service.py      # 비즈니스 로직
└── router.py       # FastAPI 엔드포인트
```

도메인 특성상 모든 파일이 항상 필요한 것은 아니며, `search`처럼 저장 모델이 없는 도메인은 `service.py`와 `router.py` 중심으로 구성해요.

새 도메인은 `backend/domains/{domain_name}/`에 필요한 모델·스키마·repository·service·router를 추가하고 `backend/main.py`에 라우터를 등록해요. API·설정·실행법의 문서 동기화 대상은 [AGENTS.md §5.8](../AGENTS.md#5-핵심-규칙)을 따라요.

문서 정리(2026-09-13): README의 구조·개발 안내를 이 문서로 통합하고 환경변수·운영 절차를 별도 기준 문서로 연결했어요.

---

## 3. 데이터 플로우

### 음성 대화 지연 진단 v1

`shared/latency.py`의 ASGI middleware는 대화 시작·이어 말하기 POST에 요청별 ContextVar를 설정해 인증 전부터 최종 body 전송까지 측정해요. auth·voice·conversation 서비스의 span은 같은 trace로 `print()` JSON 한 줄씩 출력해요. Flutter는 recorder 종료 때 시작한 Stopwatch를 요청과 로컬 오디오 객체까지 전달해 첫 playing 이벤트를 기록해요. JSON 본문은 유지되며 provider는 아래 외부 HTTP 풀 v1을 재사용해요. [계측·실험·연결 풀 적용](../docs/VOICE_LATENCY.md)과 [향후 스트리밍 제안](../docs/VOICE_STREAMING.md)을 참조해요.

### 인증

```text
[Flutter 앱] → Google Sign-In SDK로 Google id_token 획득
             → Google access_token 획득
             → Supabase Auth signInWithIdToken(provider=google)
             → Supabase session/access_token 발급

[Flutter 앱] → 인증 API에서 401 수신
             → 진행 중인 Supabase refresh가 있으면 같은 결과 대기
             → Supabase SDK refreshSession
             → 새 Supabase access_token으로 Authorization 갱신
             → 원 요청 1회 재시도
             → refresh가 실패하거나 세션이 없으면 unauthenticated 전환

[FastAPI] → Authorization: Bearer <supabase_access_token>
          → Supabase Auth /user 검증
          → profiles upsert/select + language defaults
          → current_user.id를 ownership boundary로 사용
```

인증이 필요한 API는 `Authorization: Bearer <supabase_access_token>` 헤더를 사용해요. 모바일 v1은 Supabase Auth의 Google native sign-in 흐름을 기본 로그인 경로로 사용해요.
언어 선호는 profile 기본값(`native_language`, `target_language`, `feedback_language`)으로 저장하고, 기존 값이 없으면 `ko -> en`과 feedback `ko`로 보정해요.

### 대화

```text
[사용자] → POST /api/conversations/start/{free-chat|roleplay}/
         → ConversationRouter
         → ConversationService
         → profile language defaults를 conversation language snapshot으로 저장
         → roleplay는 role_character를 저장
         ├── LLMProvider → OpenRouter / Ollama
         ├── GrammarService 백그라운드 문법 체크(snapshot language)
         └── Response { conversation_id, response, message_id, language }

[Flutter 앱] → Topic Prep 첫 답변 또는 Roleplay Setup CTA
             → start conversation API
             → /conversation/{conversation_id}
             → GET /api/conversations/{conversation_id}/messages/?limit=50&offset=0

[Flutter 앱] → Conversation composer 전송
             → POST /api/conversations/{conversation_id}/message/
             → optimistic user bubble + TypingIndicator
             → AI 응답 표시 후 canonical messages refresh

[Flutter 앱] → Conversation composer 텍스트/음성 전송
             → POST /api/conversations/{conversation_id}/turn/
             → text 또는 audio_file 중 하나 전달
             → audio_file이면 VoiceService → OpenRouter/OpenAI STT provider → transcript 생성
             → ConversationService.continue_conversation(transcript 또는 text, conversation language snapshot)
             → include_audio_response=true이면 VoiceService → OpenRouter/OpenAI TTS provider
             → Response { transcript, response, audio?, audio_error? }

[Flutter 앱] → Free Chat 음성 시작
             → POST /api/conversations/start/free-chat/
             → first_message 또는 audio_file 중 하나 전달
             → audio_file이면 transcript를 first_message로 사용
```

### 문법 피드백

```text
[모바일 앱] → GET /api/grammar/message/{message_id}/
           → 현재 사용자 소유 message인지 검증
           → 2초 간격, 최대 30초 polling
           → 피드백이 없거나 접근 불가하면 404를 pending/timeout UX로 처리
           → GrammarFeedback 수신 또는 앱 timeout 처리

[선택적 실시간 경로] → GET /api/conversations/messages/{message_id}/grammar-feedback/stream
                    → SSE로 GrammarFeedback 또는 timeout/error 수신
```

### 검색

```text
[사용자] → POST /api/search/
         → hybrid query analysis
         → ddgs 검색
         → LLM source judge
         → SearchResult { query, enhanced_query, ready, summary?, sources, quality, timestamp }
```

### 웹 페이지

```text
[브라우저] → GET /, /conversations, /grammar/stats 등
           → WebRouter
           → Jinja2Templates로 HTML 응답
```

---

## 4. 외부 의존성

### 외부 HTTP 연결 풀 v1 — 구현 결정 (2026-09-13)

FastAPI lifespan에서 워커의 이벤트 루프별 AI용·Supabase 인증용 `httpx.AsyncClient`를 각각 만들고 dependency → service → provider로 명시적으로 전달해요. provider는 빌린 client를 닫지 않아요. 스낵 CLI도 자신의 이벤트 루프에서 같은 생성 함수를 사용해 실행 전체에 하나의 AI client를 소유해요. HTTP client 생성 시에는 실제 API를 호출하지 않아요.

초기 한도는 풀마다 최대 연결 100개·유휴 연결 20개·유휴 만료 30초이며 환경변수로 조절해요. OpenRouter LLM 30초, Ollama 60초, 음성·인증의 기존 timeout은 요청별로 유지해요. HTTP/2·자동 재시도·provider 변경은 추가하지 않아요. 요청별 인증 헤더를 사용하고 upstream 쿠키 저장을 차단해 사용자 상태가 공유되지 않도록 해요.

백그라운드 문법 task는 워커별 registry가 추적해요. 종료 시 최대 5초(설정 가능) 동안 기다린 뒤 남은 task를 cancel하고 await한 후 HTTP client를 닫아요. 문법 저장에는 요청용 DB session 대신 task가 소유한 별도 session을 사용해요. 종료 중 취소된 문법 피드백은 저장되지 않을 수 있으며 재시작 후 자동 재개하는 작업 큐는 이번 범위에 포함하지 않아요.

검증은 실제 localhost HTTP/1.1 연결 재사용, 동시 요청·인증 헤더/쿠키 분리, timeout·오류 유지, 종료 순서, CLI와 provider 주입 경로를 포함해요. 외부 유료 API 호출과 운영 배포는 수행하지 않아요.

| 서비스 | 용도 | 실패 시 |
|--------|------|---------|
| OpenRouter API | LLM 대화 생성 | 502 계열 외부 API 오류 |
| Ollama | 로컬 LLM 대안 | 502 계열 외부 API 오류 |
| OpenRouter Audio API | 기본 STT/TTS 음성 대화 입출력 | STT 실패 시 대화 저장 전 오류, TTS 실패 시 `audio_error` |
| OpenAI Audio API | OpenAI direct STT/TTS fallback | STT 실패 시 대화 저장 전 오류, TTS 실패 시 `audio_error` |
| DuckDuckGo(ddgs) | 검색 자료 수집 | 검색 실패 오류 |
| Supabase Auth | Google 로그인, 세션 refresh, token 검증 | 인증 오류 |
| Google Sign-In | 모바일 native Google 계정 선택 | 인증 오류 |

---

## 5. 보안 경계

- API 키와 서버 전용 secret은 환경변수로만 관리해요.
- 클라이언트에는 OpenRouter, OpenAI, Supabase service role key를 노출하지 않아요.
- Flutter 앱은 Google `id_token`과 Google `access_token`으로 Supabase 세션을 만들고, FastAPI에는 Supabase access token만 전달해요.
- Supabase가 refresh token 저장과 rotate를 관리해요.
- 대화와 메시지는 `user_id`로 소유자를 분리해요.
- 모바일 앱은 백엔드 API와 HTTPS로 통신하는 별도 클라이언트로 취급해요.
- refresh 네트워크·5xx 실패는 세션 만료로 즉시 단정하지 않고 Supabase 세션 복구를 우선해요.

# 시스템 아키텍처

> 프로젝트: MoreThanHuman (Convia) · 버전: 0.1.0 · 최종 갱신: 2026-07-20

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
│       ├── roleplay_setup/  # 롤플레이 상황·난이도 선택 UI
│       └── topic_prep/      # Topic Input, 검색 준비 카드 API 상태와 UI
├── test/                    # Flutter 테스트
└── pubspec.yaml             # Dart/Flutter 의존성
```

Flutter API 요청은 `ApiClient → AuthTokenInterceptor → TokenRefreshInterceptor → Dio` 순서로 실행돼요. 응답은 공통 envelope parser를 거쳐 feature decoder로 전달해요. Supabase SDK가 access/refresh session을 관리하고, `AuthTokenInterceptor`는 현재 Supabase access token을 `Authorization: Bearer` 헤더로 주입해요. 여러 요청이 동시에 `401`을 받아도 Supabase refresh는 하나만 공유하며, 새 access token으로 각 요청을 한 번만 재시도해요.

Flutter 앱 시작은 `Splash → Onboarding(최초 1회) → Google Login → Home` 순서예요. `go_router`가 onboarding 완료 상태와 Riverpod 인증 상태를 함께 관찰하며, 인증 복원 중에는 Splash를 유지하고 로그인 성공 또는 세션 만료 시 Home/Login으로 redirect해요. Onboarding은 기기 locale로 `ko -> en`, `en -> ko`, `zh -> ko` 기본값을 고르고 사용자가 지원 언어쌍(`ko -> en`, `en -> ko`, `zh -> en`, `zh -> ko`) 중 하나를 확정하면 pending language context를 secure storage에 저장해요. 인증이 생기면 `authControllerProvider`가 `PUT /api/auth/me/language-preferences`로 pending 값을 서버에 동기화하고 `/api/auth/me`로 profile language를 hydration한 뒤 Home을 표시해요. Home은 활성 언어쌍과 `/api/conversations/?limit=5&offset=0` 최근 대화 loaded/empty/error 상태를 표시해요. Account sheet의 언어쌍 설정은 profile default만 갱신하며 새 대화부터 적용되고 기존 conversation은 snapshot을 유지한다고 안내해요. Free Chat 선택 시 `Topic Input → Topic Prep`으로 이어져 `POST /api/search/topic-prep/`의 ready/low-quality/error 상태를 보여주고, 첫 답변 제출 후 `POST /api/conversations/start/free-chat/`로 Conversation 화면에 진입해요. Roleplay 선택 시 `Roleplay Setup`에서 target language에 맞는 preset/custom 상황과 난이도를 고르고 `POST /api/conversations/start/roleplay/`로 같은 Conversation 화면에 진입해요. Topic Prep과 Roleplay 콘텐츠 선택은 target language를 따르고, retry guidance나 짧은 설명은 feedback language를 따르는 정책을 유지해요. Backend LLM prompt policy도 같은 원칙을 써서 target language가 conversation, roleplay, grammar, Topic Prep의 연습·교정 기준을 정하고 feedback language는 설명·retry 안내 언어만 정해요. 이 정책은 STT/TTS나 provider/model routing을 변경하지 않아요. Home 최근 대화 카드도 `/conversation/:conversationId`로 이동해 기존 메시지를 이어가요.

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

---

## 3. 데이터 플로우

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

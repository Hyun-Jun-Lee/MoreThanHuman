# 시스템 아키텍처

> 프로젝트: MoreThanHuman (Convia) · 버전: 0.1.0 · 최종 갱신: 2026-05-26

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
| python-jose | ≥ 3.3.0 | JWT 인증 |
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
| Flutter | 향후 모바일 앱 클라이언트로 개발 예정 |

현재 저장소의 기준 범위는 FastAPI 백엔드 API예요. 사용자-facing 클라이언트는 향후 Flutter 모바일 앱에서 구현해요.

---

## 2. 시스템 구조

**아키텍처 패턴**: Modular Monolith (FastAPI)

```text
backend/
├── main.py                  # FastAPI 앱 초기화, 라우터 등록
├── config.py                # Pydantic BaseSettings 환경 설정
├── database.py              # SQLAlchemy 엔진·세션 팩토리
├── shared/                  # 공통 타입, 예외, 유틸리티
└── domains/                 # 도메인별 수직 슬라이스
    ├── auth/                # 회원가입, 로그인, JWT, Google OAuth
    ├── conversation/        # 대화 관리
    ├── grammar/             # 문법 체크 및 통계
    ├── llm/                 # LLM 프로바이더 추상화
    ├── search/              # ddgs 검색 + query analysis + LLM source judge + LLM 요약
    └── web/                 # 서버 렌더링 HTML 라우트
```

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
[사용자] → POST /api/auth/register 또는 /api/auth/login
         → device_id와 함께 AuthRouter 진입
         → AuthService
         → AuthRepository
         → access_token(JWT) + refresh_token 발급

[사용자] → POST /api/auth/refresh
         → refresh token 검증 + rotate
         → 새 access_token + 새 refresh_token 발급

[Flutter 앱] → Google Sign-In SDK로 Google id_token 획득
             → POST /api/auth/google/mobile { id_token, device_id }
             → 서버가 Google id_token 검증
             → access_token(JWT) + refresh_token 발급

[Swagger/웹 확인] → GET /api/auth/google/login?device_id=...
                 → OAuth state에 device_id 서명
                 → GET /api/auth/google/callback?code=...&state=...
                 → state 검증 후 token pair 발급
```

인증이 필요한 API는 `Authorization: Bearer <token>` 헤더를 사용해요. 모바일 v1은 Google OAuth에서 SDK 기반 id token 검증 흐름을 우선하고, 서버 callback JSON 응답 흐름은 Swagger/웹 확인용으로 유지해요.

### 대화

```text
[사용자] → POST /api/conversations/start/{free-chat|roleplay}/
         → ConversationRouter
         → ConversationService
         ├── LLMProvider → OpenRouter / Ollama
         ├── GrammarService 백그라운드 문법 체크
         └── Response { conversation_id, response, message_id }
```

### 문법 피드백

```text
[모바일 앱] → GET /api/grammar/message/{message_id}/
           → 피드백이 없으면 404를 pending으로 처리하고 짧은 간격으로 재시도
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
| DuckDuckGo(ddgs) | 검색 자료 수집 | 검색 실패 오류 |
| Google OAuth2 | 선택적 소셜 로그인 | 인증 오류 |

---

## 5. 보안 경계

- API 키와 JWT secret은 환경변수로만 관리해요.
- 클라이언트에는 OpenRouter, Google OAuth secret, JWT secret을 노출하지 않아요.
- Flutter 앱은 Google `id_token`만 서버에 전달하고 Google client secret을 보유하지 않아요.
- 비밀번호는 bcrypt로 해싱해 저장해요.
- refresh token은 원문 대신 해시를 저장하고, 기기(installation) 단위로 rotate/revoke 해요.
- 대화와 메시지는 `user_id`로 소유자를 분리해요.
- 모바일 앱은 백엔드 API와 HTTPS로 통신하는 별도 클라이언트로 취급해요.

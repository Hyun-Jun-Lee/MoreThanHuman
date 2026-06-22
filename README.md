# MoreThanHuman

AI 기반 영어 회화 학습 플랫폼의 FastAPI 백엔드와 Curitalk Flutter 모바일 앱을 함께 관리해요.

백엔드는 `backend/`, iOS·Android 모바일 앱은 `mobile/`에 있어요.

## 빠른 시작

### 1. 환경 설정

```bash
cp .env.example .env
```

`.env`에서 최소한 아래 값을 설정해요:

| 변수 | 설명 |
|------|------|
| `LLM_PROVIDER` | `openrouter` 또는 `ollama` |
| `OPENROUTER_API_KEY` | OpenRouter API 키 |
| `OPENROUTER_MODEL` | OpenRouter 모델명 |
| `OLLAMA_BASE_URL` | Ollama 서버 URL |
| `OLLAMA_MODEL` | Ollama 모델명 |
| `JWT_SECRET_KEY` | JWT 서명 secret |

### 2. 의존성 설치

권장 방식:

```bash
cd backend
uv sync
```

호환 방식:

```bash
pip install -r requirements.txt
```

`backend/pyproject.toml`이 최신 의존성 기준이에요.

### 3. 데이터베이스

개발 기본값은 SQLite예요.

```env
DATABASE_URL=sqlite:///./english_learning.db
```

프로덕션에서는 PostgreSQL을 사용해요.

```env
DATABASE_URL=postgresql://user:password@localhost:5432/english_learning
```

### 4. 서버 실행

```bash
cd backend
uv run python main.py
```

또는:

```bash
cd backend
uv run uvicorn main:app --reload --port 8010
```

서버 실행 후:

| URL | 설명 |
|-----|------|
| `http://localhost:8010/docs` | Swagger API 문서 |
| `http://localhost:8010/redoc` | ReDoc |
| `http://localhost:8010/health` | 헬스 체크 |

### 5. 모바일 앱 확인

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

실제 iOS·Android 실행에는 Xcode 또는 Android SDK 설정이 추가로 필요해요.

## 프로젝트 구조

```text
MoreThanHuman/
├── backend/
│   ├── main.py             # FastAPI 앱 초기화 및 라우터 등록
│   ├── config.py           # 환경 설정
│   ├── database.py         # SQLAlchemy DB 연결 및 세션 관리
│   ├── shared/             # 공통 타입, 예외, 유틸리티
│   └── domains/            # auth, conversation, grammar, llm, search, web
└── mobile/
    ├── android/            # Android runner
    ├── ios/                # iOS runner
    ├── lib/                # Flutter 애플리케이션 코드
    ├── test/               # Flutter 테스트
    └── pubspec.yaml        # Dart/Flutter 의존성
```

## API 공통 규칙

Base URL: `http://localhost:8010`

성공 응답:

```json
{
  "success": true,
  "message": "optional message",
  "data": {}
}
```

에러 응답:

```json
{
  "success": false,
  "error": "에러 메시지",
  "details": {}
}
```

인증이 필요한 API는 헤더를 사용해요:

```http
Authorization: Bearer <access_token>
```

## Auth API

### 토큰/세션 정책(모바일 기준)

- `access_token`: JWT (현재 24시간 TTL 유지)
- `refresh_token`: opaque 랜덤 문자열(15일 TTL), **refresh 시 rotate**
- `device_id`: “기기 ID”가 아니라 **설치(installation) ID**예요(Flutter에서 UUIDv4 생성 후 secure storage에 저장)
- 기기당 세션: `(user_id, device_id)` 조합 기준으로 활성 refresh token은 **1개만 허용**해요
- refresh 401 처리(권장): refresh 1회 재시도 후에도 실패하면 재로그인 유도

### `POST /api/auth/register`

이메일+비밀번호로 회원가입하고 JWT를 발급해요.

```json
{
  "email": "user@example.com",
  "password": "password",
  "name": "User",
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### `POST /api/auth/login`

이메일+비밀번호로 로그인해 JWT를 발급해요.

```json
{
  "email": "user@example.com",
  "password": "password",
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### `POST /api/auth/dev/token`

Swagger/local 테스트용 JWT를 발급해요. `ENV=dev`일 때만 사용할 수 있고, 운영 환경에서는 `403`을 반환해요.

요청 body는 모두 선택값이에요. 비워 보내면 Swagger 테스트용 기본 계정을 만들거나 재사용해요.

```json
{
  "email": "swagger-test@example.com",
  "name": "Swagger Test User",
  "device_id": "swagger-local"
}
```

Swagger 사용 순서:

1. `POST /api/auth/dev/token` 실행
2. 응답의 `data.access_token` 복사
3. Swagger 우측 상단 `Authorize`에 토큰 입력
4. `/api/search/`, `/api/search/topic-prep/` 같은 인증 API 호출

### `POST /api/auth/refresh`

refresh token으로 access token을 재발급해요. 성공 시 refresh token도 rotate돼요.

```json
{
  "refresh_token": "opaque_refresh_token",
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### `POST /api/auth/logout`

refresh token을 revoke(로그아웃)해요.

```json
{
  "refresh_token": "opaque_refresh_token",
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### `POST /api/auth/google/mobile`

Flutter Google Sign-In SDK에서 받은 `id_token`으로 로그인해 JWT를 발급해요. 서버는 `GOOGLE_CLIENT_ID`를 audience로 사용해 Google `id_token`을 검증해요.

```json
{
  "id_token": "google_id_token_from_flutter_sdk",
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

성공 시 `TokenResponse`를 반환해요. 같은 Google 계정으로 이미 생성된 사용자는 재사용하고, 같은 이메일의 비밀번호 계정이 이미 있으면 자동 연결하지 않고 `409`를 반환해요.

### `GET /api/auth/google/login?device_id=...`

Google OAuth2 로그인 URL을 반환해요. Swagger/웹 확인용 서버 callback OAuth 흐름이에요.

### `GET /api/auth/google/callback?code=...&state=...`

Google OAuth2 callback code로 JWT를 발급해요. Swagger/웹 확인용 서버 callback OAuth 흐름이에요.

### 모바일 Google OAuth 방향

Flutter 모바일 앱은 서버 callback JSON 응답보다 Google Sign-In SDK 기반 로그인을 우선해요. 앱이 Google SDK로 `id_token`을 받은 뒤, 서버의 모바일용 Google 로그인 API가 해당 토큰을 검증하고 자체 `access_token`/`refresh_token`을 발급하는 구조예요.

```text
Flutter App
→ Google Sign-In SDK로 로그인
→ Google id_token 획득
→ POST /api/auth/google/mobile
   { "id_token": "...", "device_id": "<installation UUID>" }
→ 서버가 Google id_token 검증
→ TokenResponse 반환
```

기존 `/api/auth/google/login`과 `/api/auth/google/callback` 흐름은 Swagger/웹 확인용으로 유지할 수 있지만, 모바일 앱의 기본 흐름은 SDK 기반 token verification 방식이에요.

### `GET /api/auth/me`

현재 사용자 프로필을 반환해요. 인증이 필요해요.

## Conversation API

모든 conversation API는 인증이 필요해요.

### `POST /api/conversations/start/free-chat/`

자유 대화를 시작해요.

```json
{
  "first_message": "Hello, I want to practice English.",
  "search_context": null,
  "topic": null,
  "conversation_direction": null,
  "selected_question": null
}
```

주제 준비 카드에서 시작하는 경우:

| 필드 | 설명 |
|------|------|
| `search_context` | 준비 카드의 검색 기반 요약 |
| `topic` | 사용자가 입력한 관심 주제 |
| `conversation_direction` | `CASUAL_CHAT`, `DEBATE`, `INTERVIEW_QA`, `EXPLANATION_PRACTICE` 중 하나 |
| `selected_question` | 사용자가 선택해 답변하는 AI 첫 질문 |

### `POST /api/conversations/start/roleplay/`

롤플레이 대화를 시작해요.

```json
{
  "role_character": "a barista at a coffee shop",
  "search_context": null
}
```

### `POST /api/conversations/{conversation_id}/message/`

진행 중인 대화에 메시지를 전송해요.

```json
{
  "message": "I want to order a latte."
}
```

### `GET /api/conversations/`

현재 사용자의 대화 목록을 조회해요. 최신으로 갱신된 대화가 먼저 와요(`updated_at desc`).

Query:

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| `limit` | `50` | 조회 개수 (`1`~`100`) |
| `offset` | `0` | 시작 위치 |

응답 예시:

```json
{
  "success": true,
  "data": {
    "results": [],
    "pagination": {
      "limit": 50,
      "offset": 0,
      "total_count": 123,
      "has_more": true,
      "next_offset": 50
    }
  }
}
```

### `GET /api/conversations/{conversation_id}/`

현재 사용자의 특정 대화를 조회해요.

### `GET /api/conversations/{conversation_id}/messages/`

대화 메시지 목록을 조회해요. 메시지는 시간순으로 반환돼서 최신 메시지가 아래로 쌓여요(`created_at asc`).

Query:

| 파라미터 | 기본값 | 설명 |
|---------|--------|------|
| `limit` | `50` | 조회 개수 (`1`~`100`) |
| `offset` | `0` | 시작 위치 |

응답 예시:

```json
{
  "success": true,
  "data": {
    "results": [],
    "pagination": {
      "limit": 50,
      "offset": 100,
      "total_count": 123,
      "has_more": false,
      "next_offset": 123
    }
  }
}
```

### `PUT /api/conversations/{conversation_id}/end/`

대화를 종료해요.

### `PUT /api/conversations/{conversation_id}/title/`

대화 제목을 수정해요.

```json
{
  "title": "Coffee Shop Roleplay"
}
```

### `DELETE /api/conversations/{conversation_id}/`

대화와 관련 메시지를 삭제해요.

### `GET /api/conversations/messages/{message_id}/grammar-feedback/stream`

문법 피드백을 SSE로 수신해요. 이 엔드포인트는 토큰을 쿼리 파라미터로 전달해요.

```text
/api/conversations/messages/{message_id}/grammar-feedback/stream?token=<access_token>
```

모바일 v1에서는 SSE보다 polling을 우선해요. 앱은 대화 응답의 `message_id`로 `GET /api/grammar/message/{message_id}/`를 반복 호출하고, `404`는 pending 또는 접근 불가 상태로 처리해요. SSE 엔드포인트는 실시간성이 필요해질 때 선택적으로 사용할 수 있어요.

## Grammar API

### `POST /api/grammar/check/`

텍스트 문법을 독립적으로 검사해요.

```json
{
  "text": "I want go home."
}
```

### `GET /api/grammar/message/{message_id}/`

특정 메시지의 문법 피드백을 조회해요. 모바일 v1의 primary polling endpoint예요.

- `200`: 현재 사용자 소유 메시지의 문법 피드백 생성 완료
- `404`: 피드백 생성 전 pending, 없는 message, 또는 타 사용자 message
- `403`: 인증 헤더 없음
- `401`: access token이 유효하지 않음

서버는 `message_id`가 현재 사용자 소유 대화에 속하는지 확인하고, 소유자가 아니면 ID 존재 여부를 노출하지 않도록 `404`를 반환해요. 앱은 `404`를 pending으로 재시도하다가 자체 timeout 이후 안내 상태로 전환하는 것을 권장해요.

### `GET /api/grammar/stats/`

문법 통계를 조회해요.

Query:

| 파라미터 | 설명 |
|---------|------|
| `time_range` | `"7d"`, `"30d"`, `"90d"`, `"all"` |

## Search API

### `POST /api/search/`

관심 주제를 검색하고, 검색 결과가 충분히 관련 있을 때만 LLM으로 요약해요. 인증이 필요해요.

```json
{
  "query": "how to order coffee in English"
}
```

응답 `data`:

```json
{
  "query": "how to order coffee in English",
  "enhanced_query": "how to order coffee in English",
  "ready": true,
  "summary": "Summary text",
  "sources": [
    {
      "title": "Source title",
      "url": "https://example.com",
      "snippet": "Source snippet"
    }
  ],
  "quality": {
    "is_sufficient": true,
    "source_count": 8,
    "relevant_source_count": 3,
    "dropped_source_count": 5,
    "relevance": true,
    "freshness": true,
    "specificity": true
  },
  "retry_guidance": null,
  "example_queries": [],
  "timestamp": "2026-05-25T00:00:00"
}
```

검색 품질이 낮으면 HTTP 오류가 아니라 `success=true` 안의 `ready=false`로 반환해요. 이때 `summary`는 `null`이고, 모바일 클라이언트는 `retry_guidance`와 `example_queries`로 주제 재입력을 유도해요.

```json
{
  "query": "요즘 이슈",
  "enhanced_query": "요즘 최신 뉴스 2026년 6월",
  "ready": false,
  "summary": null,
  "sources": [],
  "quality": {
    "is_sufficient": false,
    "source_count": 5,
    "relevant_source_count": 0,
    "dropped_source_count": 5,
    "relevance": false,
    "freshness": true,
    "specificity": false,
    "reason": "검색 결과가 주제와 충분히 관련되어 있지 않아요.",
    "retry_suggestion": "팀, 날짜, 사건명, 인물, 장소처럼 구체적인 핵심어를 더 넣어 다시 검색해보세요."
  },
  "retry_guidance": "팀, 날짜, 사건명, 인물, 장소처럼 구체적인 핵심어를 더 넣어 다시 검색해보세요.",
  "example_queries": [
    "2026년 6월 요즘 이슈 관련 최신 이슈"
  ],
  "timestamp": "2026-06-04T00:00:00"
}
```

### `POST /api/search/topic-prep/`

관심 주제를 검색해 대화 전 준비 카드를 생성해요. 인증이 필요해요. 이 엔드포인트는 conversation을 생성하지 않으며, 모바일 앱은 사용자가 첫 질문을 선택하고 답변한 뒤 `POST /api/conversations/start/free-chat/`로 대화를 시작해요.

요청:

```json
{
  "topic": "recent Dodgers game result"
}
```

검색 품질이 충분한 응답:

```json
{
  "success": true,
  "data": {
    "ready": true,
    "card": {
      "topic": "recent Dodgers game result",
      "summary": "Short search-grounded summary.",
      "directions": [
        {
          "direction": "DEBATE",
          "title": "Debate",
          "description": "Take a position and explain your reasons.",
          "first_questions": [
            "Was the manager's late-game decision right?",
            "Which team had the stronger argument after the result?",
            "What would critics say about the final inning?"
          ]
        }
      ],
      "sources": [],
      "quality": {
        "is_sufficient": true,
        "source_count": 3,
        "has_enough_sources": true,
        "relevance": true,
        "freshness": true,
        "specificity": true
      },
      "timestamp": "2026-05-28T00:00:00"
    },
    "quality": {
      "is_sufficient": true,
      "source_count": 3,
      "has_enough_sources": true,
      "relevance": true,
      "freshness": true,
      "specificity": true
    },
    "retry_guidance": null,
    "example_topics": []
  }
}
```

검색 품질이 낮은 응답:

```json
{
  "success": true,
  "data": {
    "ready": false,
    "card": null,
    "quality": {
      "is_sufficient": false,
      "source_count": 1,
      "has_enough_sources": false,
      "relevance": false,
      "freshness": false,
      "specificity": false,
      "reason": "대화 준비에 사용할 검색 출처가 충분하지 않아요.",
      "retry_suggestion": "더 구체적인 사건, 날짜, 팀, 인물, 장소를 넣어 다시 입력해보세요."
    },
    "retry_guidance": "더 구체적인 사건, 날짜, 팀, 인물, 장소를 넣어 다시 입력해보세요.",
    "example_topics": [
      "2026년 5월 Dodgers 경기 결과"
    ]
  }
}
```

## Health Check

### `GET /health`

```json
{
  "status": "healthy",
  "database": "connected",
  "version": "1.0.0"
}
```

## 환경 변수

| 변수 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `DATABASE_URL` | 아니오 | `sqlite:///./english_learning.db` | DB 연결 문자열 |
| `OPENROUTER_API_KEY` | 예 | 없음 | OpenRouter API 키 |
| `LLM_PROVIDER` | 아니오 | `openrouter` | 기본 LLM provider. `ollama`는 로컬 Ollama 서버를 의도적으로 사용할 때만 설정 |
| `OLLAMA_BASE_URL` | Ollama 사용 시 | 없음 | Ollama 서버 URL |
| `OPENROUTER_MODEL` | OpenRouter 사용 시 | 없음 | 대화용 OpenRouter 모델 |
| `OLLAMA_MODEL` | Ollama 사용 시 | 없음 | 대화용 Ollama 모델 |
| `GRAMMAR_MODEL_PROVIDER` | 아니오 | `LLM_PROVIDER` | 문법 체크 전용 provider. 기본 권장은 `openrouter` |
| `GRAMMAR_OPENROUTER_MODEL` | 아니오 | `OPENROUTER_MODEL` | 문법 체크 전용 OpenRouter 모델 |
| `GRAMMAR_OLLAMA_MODEL` | 아니오 | `OLLAMA_MODEL` | 문법 체크 전용 Ollama 모델 |
| `JWT_SECRET_KEY` | 예 | 없음 | JWT 서명 secret |
| `JWT_ALGORITHM` | 아니오 | `HS256` | JWT 알고리즘 |
| `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` | 아니오 | `1440` | access token 만료 시간 |
| `JWT_REFRESH_TOKEN_EXPIRE_DAYS` | 아니오 | `15` | refresh token 만료 기간(일) |
| `GOOGLE_CLIENT_ID` | Google OAuth 사용 시 | 없음 | Google OAuth client ID. 모바일 SDK `id_token` 검증의 audience로도 사용 |
| `GOOGLE_CLIENT_SECRET` | 서버 callback OAuth 사용 시 | 없음 | 서버 callback 기반 Google OAuth client secret |
| `GOOGLE_REDIRECT_URI` | 서버 callback OAuth 사용 시 | `http://localhost:8010/api/auth/google/callback` | 서버 callback 기반 Google OAuth callback |
| `ENV` | 아니오 | `prod` | 실행 환경. `dev`/`development`/`local`이면 개발 전용 API 활성화 |
| `DEBUG` | 아니오 | `false` | 디버그 모드 |
| `CORS_ORIGINS` | 아니오 | `[]` | CORS 허용 origin 목록 |
| `MAX_TOKENS` | 아니오 | `4000` | LLM 최대 토큰 |
| `TEMPERATURE` | 아니오 | `0.7` | LLM temperature |
| `SEARCH_SUMMARY_MAX_TOKENS` | 아니오 | `600` | 검색 요약 최대 토큰 |
| `SEARCH_QUERY_ANALYSIS_MAX_TOKENS` | 아니오 | `500` | 검색어 분석 LLM 최대 토큰 |
| `SEARCH_QUALITY_JUDGE_MAX_TOKENS` | 아니오 | `500` | 검색 품질 판정 LLM 최대 토큰 |
| `SEARCH_REGION` | 아니오 | `kr-kr` | ddgs 검색 지역 |
| `SEARCH_SAFESEARCH` | 아니오 | `moderate` | ddgs safe search 옵션 |
| `SEARCH_RECENT_TIMELIMIT` | 아니오 | `m` | 최신성 의도 쿼리에 적용할 ddgs 기간 옵션 |
| `SEARCH_BACKEND` | 아니오 | `auto` | ddgs 검색 backend |
| `SEARCH_MAX_RESULTS` | 아니오 | `12` | 필터링 전 수집할 검색 결과 수 |
| `SEARCH_MIN_RELEVANT_RESULTS` | 아니오 | `2` | LLM judge가 accept해야 하는 최소 출처 수 |
| `MAX_HISTORY_TURNS` | 아니오 | `10` | 대화 기록 최대 턴 |

## 개발 가이드

### 새 도메인 추가

1. `backend/domains/{domain_name}/` 폴더를 만들어요.
2. 필요에 따라 `models.py`, `schemas.py`, `enums.py`를 추가해요.
3. `repository.py`에 데이터 접근을 분리해요.
4. `service.py`에 비즈니스 로직을 둬요.
5. `router.py`에 API 엔드포인트를 정의해요.
6. `backend/main.py`에 라우터를 등록해요.

### 문서 동기화

API, 환경변수, 도메인 계약이 바뀌면 같은 작업 단위에서 아래 파일을 함께 갱신해요.

| 변경 | 동기화 대상 |
|------|-------------|
| API 엔드포인트 | `README.md`, `docs/DSL.md`, `backend/domains/*/router.py` |
| 환경변수 | `.env.example`, `README.md`, `backend/config.py` |

## 주요 기능

- 이메일/비밀번호 회원가입 및 로그인
- Google OAuth2 로그인
- JWT 기반 인증
- AI 기반 영어 회화 연습
- 자유 대화와 롤플레이 대화
- 사용자별 대화 히스토리 관리
- 문법 체크 및 polling/SSE 기반 비동기 피드백
- 문법 통계
- OpenRouter/Ollama LLM provider 추상화
- ddgs 검색 + query analysis + LLM source judge + LLM 요약

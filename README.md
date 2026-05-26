# MoreThanHuman Backend API

AI 기반 영어 회화 학습 플랫폼 Convia의 FastAPI 백엔드예요.

현재 저장소의 기준 범위는 백엔드 API예요. 사용자-facing 클라이언트는 향후 Flutter 기반 모바일 앱으로 별도 개발할 예정이에요.

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

## 프로젝트 구조

```text
backend/
├── main.py                 # FastAPI 앱 초기화 및 라우터 등록
├── config.py               # 환경 설정
├── database.py             # SQLAlchemy DB 연결 및 세션 관리
├── shared/                 # 공통 타입, 예외, 유틸리티
└── domains/
    ├── auth/               # 회원가입, 로그인, JWT, Google OAuth
    ├── conversation/       # 대화 관리
    ├── grammar/            # 문법 체크 및 통계
    ├── llm/                # OpenRouter/Ollama 추상화
    ├── search/             # DuckDuckGo 검색 + LLM 요약
    └── web/                # 서버 렌더링 HTML 라우트
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

### `GET /api/auth/google/login?device_id=...`

Google OAuth2 로그인 URL을 반환해요.

### `GET /api/auth/google/callback?code=...&state=...`

Google OAuth2 callback code로 JWT를 발급해요.

### `GET /api/auth/me`

현재 사용자 프로필을 반환해요. 인증이 필요해요.

## Conversation API

모든 conversation API는 인증이 필요해요.

### `POST /api/conversations/start/free-chat/`

자유 대화를 시작해요.

```json
{
  "first_message": "Hello, I want to practice English.",
  "search_context": null
}
```

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

## Grammar API

### `POST /api/grammar/check/`

텍스트 문법을 독립적으로 검사해요.

```json
{
  "text": "I want go home."
}
```

### `GET /api/grammar/message/{message_id}/`

특정 메시지의 문법 피드백을 조회해요.

### `GET /api/grammar/stats/`

문법 통계를 조회해요.

Query:

| 파라미터 | 설명 |
|---------|------|
| `time_range` | `"7d"`, `"30d"`, `"90d"`, `"all"` |

## Search API

### `POST /api/search/`

DuckDuckGo 검색 결과를 LLM으로 요약해요.

```json
{
  "query": "how to order coffee in English"
}
```

응답 `data`:

```json
{
  "query": "how to order coffee in English",
  "summary": "Summary text",
  "sources": [
    {
      "title": "Source title",
      "url": "https://example.com",
      "snippet": "Source snippet"
    }
  ],
  "timestamp": "2026-05-25T00:00:00"
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
| `OPENROUTER_API_KEY` | OpenRouter 사용 시 | 없음 | OpenRouter API 키 |
| `LLM_PROVIDER` | 예 | 없음 | `openrouter` 또는 `ollama` |
| `OLLAMA_BASE_URL` | Ollama 사용 시 | 없음 | Ollama 서버 URL |
| `OPENROUTER_MODEL` | OpenRouter 사용 시 | 없음 | 대화용 OpenRouter 모델 |
| `OLLAMA_MODEL` | Ollama 사용 시 | 없음 | 대화용 Ollama 모델 |
| `GRAMMAR_MODEL_PROVIDER` | 아니오 | `LLM_PROVIDER` | 문법 체크 전용 provider |
| `GRAMMAR_OPENROUTER_MODEL` | 아니오 | `OPENROUTER_MODEL` | 문법 체크 전용 OpenRouter 모델 |
| `GRAMMAR_OLLAMA_MODEL` | 아니오 | `OLLAMA_MODEL` | 문법 체크 전용 Ollama 모델 |
| `JWT_SECRET_KEY` | 예 | 없음 | JWT 서명 secret |
| `JWT_ALGORITHM` | 아니오 | `HS256` | JWT 알고리즘 |
| `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` | 아니오 | `1440` | access token 만료 시간 |
| `JWT_REFRESH_TOKEN_EXPIRE_DAYS` | 아니오 | `15` | refresh token 만료 기간(일) |
| `GOOGLE_CLIENT_ID` | Google OAuth 사용 시 | 없음 | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth 사용 시 | 없음 | Google OAuth client secret |
| `GOOGLE_REDIRECT_URI` | 아니오 | `http://localhost:8010/api/auth/google/callback` | Google OAuth callback |
| `DEBUG` | 아니오 | `false` | 디버그 모드 |
| `CORS_ORIGINS` | 아니오 | `[]` | CORS 허용 origin 목록 |
| `MAX_TOKENS` | 아니오 | `4000` | LLM 최대 토큰 |
| `TEMPERATURE` | 아니오 | `0.7` | LLM temperature |
| `SEARCH_SUMMARY_MAX_TOKENS` | 아니오 | `600` | 검색 요약 최대 토큰 |
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
- 문법 체크 및 SSE 기반 비동기 피드백
- 문법 통계
- OpenRouter/Ollama LLM provider 추상화
- DuckDuckGo 검색 + LLM 요약

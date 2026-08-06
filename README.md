# MoreThanHuman

AI 기반 다국어 회화 학습 플랫폼의 FastAPI 백엔드와 Curitalk Flutter 모바일 앱을 함께 관리해요.

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
| `OPENAI_API_KEY` | OpenAI direct STT/TTS를 사용할 때 필요한 API 키 |
| `OLLAMA_BASE_URL` | Ollama 서버 URL |
| `OLLAMA_MODEL` | Ollama 모델명 |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase Auth 토큰 검증에 사용하는 publishable key |

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

스키마 변경은 Alembic이 관리해요.

```bash
cd backend
uv run alembic upgrade head
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

### 세션 정책(모바일 기준)

- Supabase Auth가 Google 로그인, access token, refresh를 관리해요.
- Flutter 앱은 Google Sign-In SDK로 `id_token`과 Google `access_token`을 받은 뒤 `supabase.auth.signInWithIdToken(provider: google)`로 Supabase 세션을 만들어요.
- FastAPI는 `Authorization: Bearer <supabase_access_token>`만 검증하고 자체 access/refresh token pair를 발급하지 않아요.
- `401`이 발생하면 Flutter의 Supabase SDK가 세션을 refresh하고 Dio가 원 요청을 한 번만 재시도해요.
- 앱 소유 프로필 데이터는 `profiles.id = Supabase auth.users.id` 기준으로 저장해요.

### Swagger 사용 순서

1. 모바일 앱 또는 Supabase Auth tooling에서 로그인된 사용자의 Supabase `access_token`을 복사해요.
2. Swagger 우측 상단 `Authorize`에 `Bearer <supabase_access_token>` 형식으로 입력해요.
3. `/api/search/`, `/api/search/topic-prep/`, `/api/conversations/` 같은 인증 API를 호출해요.
4. 만료되었거나 다른 Supabase project의 token이면 FastAPI가 `401`을 반환해요.

```text
Flutter App
→ Google Sign-In SDK로 로그인
→ Google id_token + access_token 획득
→ Supabase signInWithIdToken
→ Supabase access_token 획득
→ FastAPI API 호출 시 Authorization 헤더 사용
```

### `GET /api/auth/me`

Supabase access token으로 검증된 현재 사용자 프로필을 반환해요. 프로필이 없으면 Supabase claim을 기준으로 `profiles` row를 생성하거나 갱신해요. 인증이 필요해요.

응답의 `language`는 새 대화에 사용할 기본 언어쌍이에요. 현재 지원하는 쌍은 `ko -> en`, `en -> ko`, `zh -> en`, `zh -> ko`이며, 기존 값이 없으면 `ko -> en`과 feedback `ko`로 보정해요.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "learner@example.com",
  "name": "Learner",
  "is_active": true,
  "oauth_provider": "google",
  "avatar_url": null,
  "language": {
    "native_language": "ko",
    "target_language": "en",
    "feedback_language": "ko"
  },
  "created_at": "2026-07-20T00:00:00Z",
  "updated_at": "2026-07-20T00:00:00Z"
}
```

### `GET /api/auth/me/language-preferences`

현재 사용자 프로필의 언어 선호를 반환해요. 인증이 필요해요.

### `PUT /api/auth/me/language-preferences`

현재 사용자 프로필의 언어 선호를 변경해요. `native_language`, `target_language`, `feedback_language` 외 필드는 허용하지 않아요. 변경값은 이후 새 conversation에만 적용되고, 이미 생성된 conversation은 생성 시점의 snapshot을 계속 사용해요.
모바일 Account sheet는 이 정책을 저장 전에 안내하고, 저장 후 `/api/auth/me`를 다시 불러와 Home의 활성 언어쌍 표시를 갱신해요.

```json
{
  "native_language": "en",
  "target_language": "ko",
  "feedback_language": "en"
}
```

## Conversation API

모든 conversation API는 인증이 필요해요.
새 conversation을 시작하면 현재 프로필의 언어 선호가 conversation snapshot으로 저장되고, start/get/list conversation 응답의 `language`에 포함돼요. 이어 말하기와 문법 polling은 저장된 snapshot을 사용하므로 이후 프로필 선호를 바꿔도 기존 대화 언어는 바뀌지 않아요.
LLM prompt policy도 같은 snapshot을 사용해요. `target_language`는 자유 대화, 롤플레이, 문법 피드백, Topic Prep의 연습·교정 기준을 정하고, `feedback_language`는 설명과 low-quality retry guidance 언어만 정해요. 이 정책은 provider/model routing이나 STT/TTS 언어 설정을 바꾸지 않아요.

### `POST /api/conversations/start/free-chat/`

자유 대화를 시작해요. JSON 텍스트 요청과 multipart 음성 요청을 모두 지원해요.

```json
{
  "first_message": "Hello, I want to talk about travel.",
  "search_context": null,
  "topic": null,
  "conversation_direction": null,
  "selected_question": null
}
```

음성으로 시작하는 경우:

```http
POST /api/conversations/start/free-chat/
Content-Type: multipart/form-data

audio_file=<recording.webm>
include_audio_response=true
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

진행 중인 대화에 텍스트 메시지를 전송해요. 기존 텍스트 전용 API이며, 새 채팅 composer는 아래 `/turn/` API를 사용하면 텍스트와 음성을 한 경로로 처리할 수 있어요.

```json
{
  "message": "I want to order a latte."
}
```

### `POST /api/conversations/{conversation_id}/turn/`

진행 중인 대화에 텍스트 또는 음성 파일을 전송해요. `text`와 `audio_file` 중 정확히 하나만 보내야 해요.

텍스트 이어 말하기:

```http
POST /api/conversations/{conversation_id}/turn/
Content-Type: application/json

{
  "text": "I want to order a latte.",
  "include_audio_response": true
}
```

음성 이어 말하기:

```http
POST /api/conversations/{conversation_id}/turn/
Content-Type: multipart/form-data

audio_file=<recording.webm>
include_audio_response=true
```

응답은 공통 envelope 안에 사용자 입력으로 확정된 `transcript`, AI 텍스트 `response`, 선택적 TTS `audio`, TTS 실패 시 `audio_error`를 포함해요.

```json
{
  "success": true,
  "data": {
    "message_id": "550e8400-e29b-41d4-a716-446655440000",
    "response": "Sure. What size would you like?",
    "grammar_feedback": null,
    "turn_count": 2,
    "input_mode": "audio",
    "transcript": "I want to order a latte.",
    "audio": {
      "content_type": "audio/mpeg",
      "base64": "...",
      "format": "mp3"
    },
    "audio_error": null
  }
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
| `OPENAI_API_KEY` | OpenAI direct 음성 기능 사용 시 | 없음 | OpenAI STT/TTS API 키. Flutter 앱에는 노출하지 않음 |
| `LLM_PROVIDER` | 아니오 | `openrouter` | 기본 LLM provider. `ollama`는 로컬 Ollama 서버를 의도적으로 사용할 때만 설정 |
| `OLLAMA_BASE_URL` | Ollama 사용 시 | 없음 | Ollama 서버 URL |
| `OPENROUTER_MODEL` | OpenRouter 사용 시 | 없음 | 대화용 OpenRouter 모델 |
| `OLLAMA_MODEL` | Ollama 사용 시 | 없음 | 대화용 Ollama 모델 |
| `GRAMMAR_MODEL_PROVIDER` | 아니오 | `LLM_PROVIDER` | 문법 체크 전용 provider. 기본 권장은 `openrouter` |
| `GRAMMAR_OPENROUTER_MODEL` | 아니오 | `OPENROUTER_MODEL` | 문법 체크 전용 OpenRouter 모델 |
| `GRAMMAR_OLLAMA_MODEL` | 아니오 | `OLLAMA_MODEL` | 문법 체크 전용 Ollama 모델 |
| `SUPABASE_URL` | 예 | 없음 | Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | 예 | 없음 | Supabase Auth `/user` 검증에 사용하는 publishable key |
| `SUPABASE_AUTH_VERIFY_MODE` | 아니오 | `remote` | FastAPI bearer token 검증 방식. 현재는 Supabase `/auth/v1/user` 검증 |
| `SUPABASE_AUTH_TIMEOUT_SECONDS` | 아니오 | `5` | Supabase Auth 검증 요청 timeout |
| `AUTO_CREATE_TABLES` | 아니오 | `false` | Alembic 대신 SQLAlchemy `create_all`을 실행할지 여부. 로컬 임시 실행 외에는 `false` 권장 |
| `JWT_SECRET_KEY` | 레거시 도구 사용 시 | 없음 | 기존 로컬 JWT tooling을 임시 유지할 때만 사용 |
| `ENV` | 아니오 | `prod` | 실행 환경. `dev`/`development`/`local`이면 개발 전용 API 활성화 |
| `DEBUG` | 아니오 | `false` | 디버그 모드 |
| `CORS_ORIGINS` | 아니오 | `[]` | CORS 허용 origin 목록 |
| `MAX_TOKENS` | 아니오 | `4000` | LLM 최대 토큰 |
| `TEMPERATURE` | 아니오 | `0.7` | LLM temperature |
| `STT_PROVIDER` | 아니오 | `openrouter` | STT provider. `openrouter` 또는 `openai` |
| `STT_MODEL` | 아니오 | `openai/gpt-4o-mini-transcribe` | 음성 파일을 텍스트로 변환할 STT 모델. OpenAI direct 사용 시 `gpt-4o-mini-transcribe`처럼 provider prefix 없이 설정 |
| `TTS_PROVIDER` | 아니오 | `openrouter` | TTS provider. `openrouter` 또는 `openai` |
| `TTS_MODEL` | 아니오 | `microsoft/mai-voice-2-flash` | AI 응답을 음성으로 변환할 TTS 모델. OpenAI direct 사용 시 `gpt-4o-mini-tts`처럼 provider prefix 없이 설정 |
| `TTS_VOICE` | 아니오 | `en-US-Harper:MAI-Voice-2-Flash` | TTS 음성 preset. provider/model별 지원 voice가 다름 |
| `TTS_RESPONSE_FORMAT` | 아니오 | `mp3` | TTS 응답 오디오 포맷. OpenRouter 기본 권장은 `mp3` 또는 `pcm` |
| `TTS_MAX_INPUT_CHARS` | 아니오 | `4000` | TTS로 보낼 최대 텍스트 길이 |
| `TTS_MAX_OUTPUT_MB` | 아니오 | `5` | base64 인코딩 전 TTS 응답 오디오 최대 크기 |
| `VOICE_MAX_UPLOAD_MB` | 아니오 | `10` | STT 업로드 음성 파일 최대 크기 |
| `VOICE_PROVIDER_TIMEOUT_SECONDS` | 아니오 | `60` | STT/TTS provider 요청 timeout |
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

- Supabase Auth 기반 Google 로그인
- Supabase access token 기반 FastAPI 보호 API
- `profiles` 기반 앱 사용자 프로필 관리
- AI 기반 다국어 회화 연습
- `ko -> en`, `en -> ko`, `zh -> en`, `zh -> ko` 언어쌍 선호와 conversation snapshot
- 목표 언어별 prompt policy 기반 대화·문법·Topic Prep 학습 기준
- 자유 대화와 롤플레이 대화
- 사용자별 대화 히스토리 관리
- 문법 체크 및 polling/SSE 기반 비동기 피드백
- 문법 통계
- OpenRouter/Ollama LLM provider 추상화
- ddgs 검색 + query analysis + LLM source judge + LLM 요약

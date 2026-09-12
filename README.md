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
│   └── domains/            # auth, conversation, grammar, language_snacks, llm, search, web
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

테스트 계정이 Supabase email/password 로그인을 사용할 수 있으면 Swagger에서 `POST /api/auth/swagger/token`으로 `access_token`을 발급받을 수 있어요. 이 helper는 `ENV=dev`에서는 기본 활성화되고, 그 외 환경에서는 `SWAGGER_TOKEN_ISSUER_ENABLED=true`와 `SWAGGER_TOKEN_ISSUER_SECRET`이 모두 설정되어야 해요. 운영에서 열 때는 nginx docs basic auth와 별개로 요청 body의 `secret`도 맞아야 합니다.

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
  "app_locale": "ko",
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

### `PUT /api/auth/me/app-locale`

프로필에 저장되는 앱 표시 언어를 `ko` 또는 `en`으로 변경해요. 이 값은 기기 시스템 언어보다 우선하지만, 학습 언어쌍과 기존 대화의 언어 snapshot에는 영향을 주지 않아요.

```json
{ "app_locale": "ko" }
```

## Language Snack API

> v2 · 2026-09-12: JSONB 세 유형, 학습 언어별 조회, 주간 생성 작업 추가

Home은 profile의 `target_language`와 같은 `content_language`의 발행 카드만 조회해요. 영어 콘텐츠의 설명은 한국어, 한국어 콘텐츠의 설명은 영어예요. 앱 표시 언어와는 별개이며 현재 런타임 번역은 하지 않아요.

| 메서드·경로 | 인증 | 동작 |
|---|---|---|
| GET `/api/v2/language-snacks/?limit=12` | Supabase Bearer | published만 최신순, 기본 12개·최대 30개 |
| POST `/api/v2/language-snacks/` | X-Operations-Key | 지식 중복 검사·LLM 검증 후 201 자동 발행 |
| PATCH `/api/v2/language-snacks/{id}/status/` | X-Operations-Key | `{"status":"archived"}`로 발행 취소 |
| GET `/api/language-snacks/` | Supabase Bearer | 구버전 앱 호환용 빈 목록 |
| POST `/api/language-snacks/` | X-Operations-Key | 410, v2로 전환 필요 |

운영 키는 서버의 `LANGUAGE_SNACKS_OPERATIONS_KEY`와 비교해요. 미설정·불일치는 403이며 Flutter에 포함하지 않아요. 중복은 409, 구조·품질·불확실한 중복 판단은 422, 생성 잠금·LLM·예산 문제는 503이에요. POST도 LLM 사용량이 발생해요. 세 유형의 전체 계약은 [DSL](docs/DSL.md#5-language-snack-모듈)에 있어요.

```bash
curl -X POST http://localhost:8010/api/v2/language-snacks/ \
  -H 'Content-Type: application/json' \
  -H 'X-Operations-Key: <server-only-operations-key>' \
  -d '{
    "content_type":"regional_variant",
    "schema_version":1,
    "content_language":"en",
    "explanation_language":"ko",
    "identity":{
      "relation":"regional_equivalent",
      "entries":[
        {"language":"en","variety":"GB","expression":"crisps","sense":"potato_snack"},
        {"language":"en","variety":"US","expression":"chips","sense":"potato_snack"}
      ]
    },
    "knowledge_summary":"British crisps and American chips refer to thin fried potato snacks.",
    "payload":{
      "meaning":"둘 다 얇게 썰어 튀긴 감자칩을 뜻해요.",
      "items":[{"label":"영국","expression":"crisps"},{"label":"미국","expression":"chips"}]
    }
  }'
```

### 주간 생성 운영

월요일 05:00 Asia/Seoul에 영어·한국어 각각 유형별 3개, 총 18개를 목표로 생성해요. 실패·중복·예산 초과 시 목표보다 적게 발행할 수 있어요. 모든 상태의 기존 지식 요약을 LLM에 전달하고 동일 identity 해시의 UNIQUE 제약과 의미 중복 검사를 함께 적용해요. 의미상 중복이나 내용 오류가 완전히 사라진다는 보장은 없어요.

1. 기존 스낵 쓰기·cron을 중지하고 필요한 백업을 확보해요. API 이미지를 빌드해 재시작하면 기존 compose command가 Alembic을 실행해요. **revision `20260912_0001`은 기존 스낵을 모두 삭제하고 테이블을 교체해요.** 다른 도메인 데이터는 보존해요.
2. `LANGUAGE_SNACKS_LOCK_DATABASE_URL`은 API와 **같은 DB**의 direct 또는 session pooling URL로 설정해요. `DATABASE_URL` 자체가 direct/session 연결이면 생략할 수 있어요. transaction pooling URL로 session advisory lock을 사용하면 안 돼요. API와 job에 같은 설정을 사용해요.
3. 배포 후 아래 후보 미리보기·초기 생성을 수동 확인해요. **dry-run도 LLM을 호출하지만 DB에는 저장하지 않아요.** 실제 발행 표본에서 세 유형·두 언어의 정확성을 확인해요.
4. [cron 예시](deploy/cron/language-snacks.cron.example)의 저장소·로그 경로, Docker PATH, cron 데몬 시간대를 확인한 뒤 서버 사용자 crontab에 등록해요. 예시는 UTC 일요일 20시이며 KST 데몬에서는 월요일 05시를 사용해요. 이 저장소 변경만으로 cron이 설치되지는 않아요.

```bash
docker compose up -d --build --force-recreate --no-deps api
/bin/sh deploy/scripts/generate-language-snacks.sh --language en --dry-run
/bin/sh deploy/scripts/generate-language-snacks.sh --run-key initial-v2
```

작업은 API 이미지의 별도 `snack-generator` 컨테이너에서 실행하며 migration과 웹 서버를 실행하지 않아요. `CURITALK_ENV_FILE`을 사용하는 서버는 cron에도 같은 절대 경로를 지정해야 해요.

- 실행 키를 생략하면 가장 최근 월요일 05시 슬롯의 `weekly:YYYY-MM-DD:{en|ko}`를 사용해요. 같은 키·언어·수량 재실행은 같은 run을 재개하고 성공한 run에는 추가 생성하지 않아요. 수동 키에도 언어 suffix가 자동으로 붙어요.
- `--language en|ko|all`, `--per-type 1..6`을 지원해요. 같은 실행 키에서 목표 수량을 바꾸면 409에 해당하는 오류로 종료해요. 지난 주 누락분을 다음 주에 자동 누적하지 않아요.
- 예약을 먼저 재개하고 후보 라운드는 run당 최대 3회, 본문 생성은 예약당 최대 2회예요. API 일시 오류는 호출당 한 번 재시도해요. 호출·보수적 토큰 예산은 재실행에도 누적하고 시간 제한은 언어별 실행 시도에 적용해요. 예산을 다 쓴 run은 같은 설정에서 계속 재시도해도 진행하지 않아요.
- stdout JSON에서 언어별 상태·발행 수·중복/불확실 판정 수·호출/토큰 사용량·오류 코드를 확인해요. `partial`/`failed`는 exit 1, 실행 중 잠금 충돌은 `skipped`예요. 로그 회전과 실패 알림은 서버 운영 도구에서 설정해요.
- `history_budget_exceeded`는 이력을 자르지 않고 중단해요. 모델 컨텍스트·비용을 검토해 상한을 조정하거나 후속 검색 기반 설계를 적용해요.
- 잘못된 발행은 PATCH로 보관해요. archived identity는 재생성하지 않으며 오프라인 캐시를 즉시 회수하지는 못해요. 수동 POST의 검증 실패도 identity를 보관하므로 같은 지식을 다시 등록할 수 없어요.
- 롤백은 생성 작업을 중지하고 API를 정지한 뒤 **새 이미지로** `alembic downgrade 20260906_0002`를 실행하고 v1 이미지를 복원해요. downgrade도 모든 v2 스낵·생성 이력을 삭제하며 예전 스낵은 복원하지 않아요. 필요하면 사전 백업을 별도로 복원해요.

구버전 앱은 정상 온라인 조회 후 스낵이 숨겨지고, 새 앱은 언어별 v2 캐시를 사용해요. 구버전 앱의 이미 저장된 오프라인 카드는 원격 삭제할 수 없어요.

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
  "selected_question": null,
  "custom_focus": null,
  "include_audio_response": true
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
| `conversation_direction` | `CASUAL_CHAT`, `DEBATE`, `EXPLANATION_PRACTICE` 중 하나 |
| `selected_question` | 사용자가 선택해 답변하는 AI 첫 질문 |
| `custom_focus` | 직접 입력한 대화 방향. 고정 direction 대신 전달 가능 |

### `POST /api/conversations/start/roleplay/`

롤플레이 대화를 시작해요.

```json
{
  "role_character": "a barista at a coffee shop",
  "search_context": null,
  "include_audio_response": true
}
```

`role_character`는 AI가 맡을 역할이나 연습할 상황 설명을 담아요.

`include_audio_response=true`이면 시작 직후 AI 첫 응답도 `audio` 또는 `audio_error`를 포함한 멀티모달 응답으로 반환돼요. 모바일 v1은 AI 응답 자동 재생을 위해 free chat 시작, roleplay 시작, `/turn/` 이어가기 요청에 이 값을 항상 포함해요.

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

현재 사용자 소유 대화와 관련 메시지·문법 피드백을 복구 없이 삭제해요. 다른 사용자의 대화 ID는 `404`로 처리해 존재 여부를 노출하지 않아요.

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
| `SWAGGER_TOKEN_ISSUER_ENABLED` | 아니오 | `false` | `ENV`가 dev가 아닐 때 Swagger token helper를 명시적으로 활성화 |
| `SWAGGER_TOKEN_ISSUER_SECRET` | 운영 helper 활성화 시 | 없음 | dev 외 환경에서 `/api/auth/swagger/token` 요청 body의 `secret`과 비교할 shared secret |
| `LANGUAGE_SNACKS_OPERATIONS_KEY` | 운영 API 사용 시 | 없음 | v2 POST/PATCH의 X-Operations-Key와 비교. Flutter에 포함 금지. CLI는 DB 직접 접근 |
| `LANGUAGE_SNACKS_PROVIDER` | 아니오 | LLM_PROVIDER | 스낵 생성·중복/품질 검사 provider |
| `LANGUAGE_SNACKS_MODEL` | 아니오 | 해당 provider 기본 모델 | 스낵 전용 모델 override |
| `LANGUAGE_SNACKS_LOCK_DATABASE_URL` | transaction pooling 사용 시 | DATABASE_URL | 같은 DB의 direct/session 연결. API와 job에서 동일하게 사용 |
| `LANGUAGE_SNACKS_PER_TYPE` | 아니오 | 3 | 언어별 유형별 목표 수량, 1..6 |
| `LANGUAGE_SNACKS_MAX_CALLS` | 아니오 | 100 | 언어별 run의 누적 LLM 호출 상한 |
| `LANGUAGE_SNACKS_MAX_TOKENS` | 아니오 | 250000 | 입력 UTF-8 바이트+출력 최대 토큰을 누적한 보수적 예산, 금액 상한이 아님 |
| `LANGUAGE_SNACKS_HISTORY_BYTES` | 아니오 | 40000 | 전체 지식 이력 UTF-8 바이트 상한 |
| `LANGUAGE_SNACKS_RUN_SECONDS` | 아니오 | 600 | 언어별 실행 시도 시간 상한(초), 각 LLM 요청은 최대 65초 |
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
| `SEARCH_QUALITY_JUDGE_MAX_TOKENS` | 아니오 | `1000` | 검색 품질 판정 LLM 최대 토큰 |
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

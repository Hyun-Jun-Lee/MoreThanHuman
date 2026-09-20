# MoreThanHuman Backend DSL

> 최종 갱신: 2026-09-13 · 범위: FastAPI 백엔드 API + Flutter 모바일 연동

사용자 클라이언트는 `mobile/`의 Flutter 기반 모바일 앱으로 개발해요. 이 문서는 모바일 앱이 연동할 백엔드 도메인, 데이터 모델, API 계약을 정의해요.

### 대화 진단 헤더 v1 (2026-09-13)

`POST /api/conversations/start/free-chat/`, `/start/roleplay/`, `/{id}/turn/`, `/{id}/message/`에 `X-Request-ID`를 선택적으로 전달할 수 있어요. 값은 소문자 16진수 32자리예요. 누락·형식 불일치 시 서버가 새 값을 만들며 같은 응답 헤더로 반환해요. 로그 연결용이며 인증·멱등성을 제공하지 않아요. JSON 본문·오류 정책은 유지돼요. ASGI 밖에서 처리되는 예외/프록시 응답에는 헤더가 없을 수 있어요. 지표와 실험 절차는 [음성 지연 문서](VOICE_LATENCY.md), 미구현 제안은 [스트리밍 설계](VOICE_STREAMING.md)에 있어요.

## 1. 시스템

```dsl
system MoreThanHuman {
  product: "AI 기반 다국어 회화 학습 플랫폼"
  backend: FastAPI
  architecture: ModularMonolith
  database: SQLiteDevelopment | PostgreSQLProduction
  packageManager: uv
  client: FlutterMobileApp

  modules: [
    Auth,
    Conversation,
    Grammar,
    LanguageSnack,
    Search,
    LLM
  ]
}
```

## 2. 데이터베이스

```dsl
database Schema {
  table profiles {
    id: UUID PRIMARY KEY
    email: STRING UNIQUE NOT NULL
    name: STRING NOT NULL
    is_active: BOOLEAN
    oauth_provider: STRING?
    avatar_url: STRING?
    native_language: "ko" | "en" | "zh" = "ko"
    target_language: "ko" | "en" | "zh" = "en"
    feedback_language: "ko" | "en" | "zh" = "ko"
    created_at: DATETIME
    updated_at: DATETIME
  }

  table conversations {
    id: UUID PRIMARY KEY
    user_id: UUID FOREIGN KEY -> profiles(id)
    title: STRING?
    conversation_type: "FREE_CHAT" | "ROLE_PLAYING"
    role_character: STRING?
    native_language: "ko" | "en" | "zh" = "ko"
    target_language: "ko" | "en" | "zh" = "en"
    feedback_language: "ko" | "en" | "zh" = "ko"
    message_count: INTEGER
    status: "ACTIVE" | "COMPLETED"
    created_at: DATETIME
    updated_at: DATETIME
  }

  table messages {
    id: UUID PRIMARY KEY
    conversation_id: UUID FOREIGN KEY -> conversations(id)
    role: "user" | "assistant" | "system"
    content: TEXT
    created_at: DATETIME
  }

  table grammar_feedback {
    id: UUID PRIMARY KEY
    message_id: UUID FOREIGN KEY -> messages(id)
    original_text: TEXT
    corrected_text: TEXT
    has_errors: BOOLEAN
    errors: JSON
    created_at: DATETIME
  }

  table language_snacks {
    id: UUID PRIMARY KEY
    content_type: regional_variant | usage_contrast | homonym
    schema_version: INTEGER
    content_language: en | ko
    explanation_language: en | ko
    identity: JSONB NOT NULL
    identity_version: INTEGER
    knowledge_key: STRING(64) UNIQUE NOT NULL
    knowledge_summary: TEXT NOT NULL
    payload: JSONB?
    status: reserved | draft | published | archived
    origin: manual | scheduled
    generation_run_id: UUID? FOREIGN KEY -> language_snack_generation_runs(id)
    generation_metadata: JSONB NOT NULL
    published_at: DATETIME?
    created_at: DATETIME
    updated_at: DATETIME
    INDEX (content_language, status, published_at, id)
  }

  table language_snack_generation_runs {
    id: UUID PRIMARY KEY
    run_key: STRING(160) UNIQUE NOT NULL
    content_language: en | ko
    status: running | succeeded | partial | failed
    target_per_type: INTEGER
    metrics: JSONB NOT NULL
    started_at: DATETIME
    finished_at: DATETIME?
  }
}
```

## 3. 공통 API 응답

```dsl
type SuccessResponse<T> {
  success: true
  message?: String
  data: T
}

type ErrorResponse {
  success: false
  error: String
  details: Dict
}

type LearningLanguageContext {
  native_language: "ko" | "en" | "zh"
  target_language: "ko" | "en" | "zh"
  feedback_language: "ko" | "en" | "zh"
}

supported LearningLanguagePairs = [
  "ko->en",
  "en->ko",
  "zh->en",
  "zh->ko"
]
```

인증이 필요한 API는 `Authorization: Bearer <access_token>` 헤더를 사용해요.

## 4. Auth 모듈

```dsl
module Auth {
  router AuthRouter {
    POST /api/auth/swagger/token        -> issueSwaggerToken
    GET  /api/auth/me                    -> getCurrentUser
    GET  /api/auth/me/language-preferences
                                            -> getLanguagePreferences
    PUT  /api/auth/me/language-preferences
                                            -> updateLanguagePreferences
    PUT  /api/auth/me/app-locale            -> updateAppLocale
  }

  type UserProfile {
    id: UUID
    email: String
    name: String
    is_active: Boolean
    oauth_provider?: String
    avatar_url?: String
    app_locale?: "ko" | "en"
    language: LearningLanguageContext
  }

  type LanguagePreferencesRequest extends LearningLanguageContext
  type LanguagePreferencesResponse extends LearningLanguageContext
  type AppLocaleRequest { app_locale: "ko" | "en" }
}
```

모바일 앱은 Supabase Auth로 Google 로그인을 완료한 뒤 Supabase `access_token`을 FastAPI 보호 API의 `Authorization: Bearer` 헤더에 전달해요. `GET /api/auth/me`는 Supabase token을 검증하고, `profiles` row를 생성 또는 갱신한 뒤 기존 envelope 형식으로 `UserProfile`을 반환해요.
`POST /api/auth/swagger/token`은 Swagger 수동 테스트를 위한 Supabase email/password token helper예요. `ENV=dev`에서는 사용할 수 있고, dev 외 환경에서는 `SWAGGER_TOKEN_ISSUER_ENABLED=true`와 `SWAGGER_TOKEN_ISSUER_SECRET`을 설정한 뒤 요청 body의 `secret`이 일치해야 해요. 발급된 `access_token`을 Swagger `Authorize`에 `Bearer <access_token>` 형식으로 넣어요.
언어 선호는 프로필 기본값이며 새 대화 시작 시 `conversations` row에 snapshot으로 저장돼요. 기존 값이 없으면 `ko -> en`, feedback `ko`로 보정해요.
`PUT /api/auth/me/language-preferences`는 profile default만 갱신해요. 모바일 Account UX는 변경값이 새 대화부터 적용되고 기존 conversation은 생성 시점 snapshot을 유지한다고 안내해야 해요.
`PUT /api/auth/me/app-locale`는 앱 chrome 표시 언어만 저장해요. 값이 없는 기존 profile은 기기 system locale을 따르며 학습 언어쌍과 기존 conversation snapshot은 바꾸지 않아요.

## 5. Language Snack 모듈

> v2.2 · 2026-09-19: 학습 언어별 무작위 feed와 사용자별 운영 바구니 리셋 기록을 제공해요.

```dsl
module LanguageSnack {
  GET   /api/v2/language-snacks/?limit=12&order=latest -> SuccessResponse<List<LanguageSnack>>
  GET   /api/v2/language-snacks/basket-reset/ -> SuccessResponse<BasketResetState> [Bearer]
  POST  /api/v2/language-snacks/basket-reset/ { user_id: UUID, content_language: "en" | "ko" }
        -> SuccessResponse<BasketResetState> [X-Operations-Key]
  POST  /api/v2/language-snacks/ -> SuccessResponse<LanguageSnack> [201]
  PATCH /api/v2/language-snacks/{id}/status/ { status: "archived" }
        -> SuccessResponse<{ id: UUID, status: "archived" }>
  GET   /api/language-snacks/ -> SuccessResponse<[]> [legacy]
  POST  /api/language-snacks/ -> 410 [legacy]

  type LanguageSnackCreate {
    content_type: "regional_variant" | "usage_contrast" | "homonym"
    schema_version: 1 = 1
    content_language: "en" | "ko"
    explanation_language: "en" | "ko"
    identity: KnowledgeIdentity
    knowledge_summary: String(1..240)
    payload: RegionalPayload | UsagePayload | HomonymPayload
  }

  type KnowledgeIdentity {
    relation: "regional_equivalent" | "usage_difference" | "same_sound"
    entries: exactly 2 * {
      language: "en" | "ko"
      expression: String(1..80)
      sense: String(1..160)
      variety?: String(1..80)
    }
    contrast?: String(1..160)
    pronunciation?: String(1..80)
    pronunciation_standard?: String(1..80)
  }

  type RegionalPayload {
    meaning: String(1..160)
    items: exactly 2 * { label: String(1..48), expression: String(1..80) }
  }
  type UsagePayload {
    items: exactly 2 * {
      expression: String(1..80), usage: String(1..160)
      example: String(1..240), example_translation?: String(1..240)
    }
  }
  type HomonymPayload {
    items: exactly 2 * {
      expression: String(1..80), meaning: String(1..160)
      example: String(1..240), example_translation?: String(1..240)
    }
  }

  type LanguageSnack {
    id: UUID
    content_type: "regional_variant" | "usage_contrast" | "homonym"
    schema_version: 1
    content_language: "en" | "ko"
    explanation_language: "en" | "ko"
    payload: RegionalPayload | UsagePayload | HomonymPayload
    published_at: DateTime
    created_at: DateTime
    updated_at: DateTime
  }
}
```

GET은 Supabase Bearer 인증 후 profile.target_language와 content_language가 같은 published 카드만 반환해요. `order=latest`(기본)는 `published_at DESC, id DESC`, `order=random`은 해당 언어의 전체 발행 목록에서 중복 없이 무작위 추출해요. limit은 1..30, 기본 12이며 다른 order 값은 422예요. 클라이언트 언어 query로 프로필을 우회하지 않아요. identity·knowledge_key·생성 메타데이터는 공개 응답에서 제외해요.

Home 토마토 UI v2(2026-09-18)는 `order=random&limit=12`로 하루 묶음을 구성해요. 토마토 3개에 각각 4개 콘텐츠를 연결하고, 전체 열람 후에는 기기 현지 자정까지 소진 상태를 유지해요. API 자체는 날짜별 결과를 고정하지 않으며 앱이 사용자·언어·기기 로컬 날짜별 스냅샷을 저장해요. API 단일 응답의 서로 다른 ID 추출에는 seed가 필요하지 않아요. 12개 미만일 때의 반복·캐시·진행 복원 정책은 [클라이언트 계약](../.agent/_contracts/LANGUAGE_SNACKS.md#토마토-상호작용-v1-2026-09-18-구현-결정)을 따라요.

POST/PATCH는 서버 `LANGUAGE_SNACKS_OPERATIONS_KEY`와 일치하는 `X-Operations-Key`가 필요해요. 일반 Bearer는 운영 권한을 대신하지 않아요. 키 미설정·불일치 403, 중복 지식 409, 입력/품질 오류와 불확실 판정 422, LLM 장애·잠금 충돌·예산 초과 503, 없는 항목 보관 404예요.

content_type과 relation은 위 나열 순서대로 대응해요. 모든 entry.language는 content_language와 같아야 하며 regional은 각 variety, usage는 contrast, homonym은 pronunciation과 pronunciation_standard가 필수예요. 영어 동음은 미국 영어, 한국어는 현대 표준어 기준으로 생성·검증하고 발음이 다른 동형이의어는 제외해요. payload의 두 expression은 identity의 expression과 순서 무관하게 같아야 해요. 필수 문자열은 양끝 공백을 제거하며 공백만 있는 값·미지정 필드·미지원 버전은 거부해요.

현재 explanation_language는 content_language의 반대 지원 언어로 고정돼요(`en -> ko`, `ko -> en`). expression·example은 학습 언어, label·meaning·usage·example_translation은 설명 언어예요. 이는 앱 표시 언어나 언어쌍 ID가 아닌 콘텐츠 메타데이터예요.

운영 POST와 주간 생성은 같은 중복 검사와 PostgreSQL 전용 세션 잠금을 사용해요. 전체 payload가 아닌 정규화 identity를 SHA-256으로 해시하고 UNIQUE로 보호해요. 의미 중복 검사는 같은 언어의 모든 유형·상태 이력을 LLM에 전달해 new만 허용해요. 생성 후보를 reserved로 먼저 저장하고 본문·품질 검증 후 published로 전환해요. draft는 후속 편집용으로 예약된 상태이며 현재 자동 발행 경로에서 별도로 저장하지 않아요. archived도 중복 이력에 남고 즉시 오프라인 캐시 회수는 하지 않아요. LLM의 의미·품질 판단은 오류가 남을 수 있어요.

구버전 GET은 인증된 빈 목록, 구버전 POST는 운영 키 확인 후 410을 반환해요. 새 앱은 미지원 type/schema_version을 건너뛰고 알려진 유형의 손상된 응답에는 마지막 성공 캐시를 사용해요.

### 바구니 리셋

`BasketResetState`는 `{content_language: "en"|"ko", reset_id: UUID|null, reset_at: DateTime|null}`예요. GET은 Bearer 사용자의 현재 학습 언어만 조회하며 기록이 없으면 ID·시간이 null이에요. 응답은 `Cache-Control: no-store`예요. POST는 `X-Operations-Key`로 지정 사용자의 지정 언어에 새 UUID를 저장하고 200을 반환해요. 키 미설정·불일치 403, 없는 사용자 404, 잘못된 UUID·언어·추가 필드 422예요. UUID는 호출마다 바뀌며 사용자·언어별 최신 기록 하나만 보관해요.

리셋 API는 LLM 호출·콘텐츠 삭제·일일 카드 재추첨을 하지 않아요. 앱은 시작·Home 진입·복귀 시 GET하고 새 ID를 발견하면 기존 당일 묶음의 소비 횟수를 0으로 초기화해요. 팝업·애니메이션 중에는 종료 후 적용하며 적용한 ID를 로컬에 함께 저장해 재시작·다음 날짜에도 같은 리셋을 중복 적용하지 않아요. 오프라인이면 기존 진행을 유지하고 다음 복귀에 재시도해요. 각 기기의 소비 횟수 자체를 동기화하는 API는 아니에요. 운영 방법은 [테스트용 바구니 리셋](OPERATIONS.md#테스트용-바구니-리셋)을 참고해요.

### 운영 생성 예시

운영 키를 실제 값으로 치환해 호출해요. 이 API는 LLM 사용량이 발생하고 검증 통과 시 즉시 발행해요. 배포·예약·재실행 절차는 [운영 가이드](OPERATIONS.md#언어-스낵-운영)에 있어요.

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

## 6. Conversation 모듈

```dsl
module Conversation {
  router ConversationRouter {
    POST   /api/conversations/start/free-chat/       -> startFreeChat
    POST   /api/conversations/start/roleplay/        -> startRoleplay
    POST   /api/conversations/{id}/message/          -> sendMessage
    POST   /api/conversations/{id}/turn/             -> sendMultimodalTurn
    GET    /api/conversations/                       -> listConversations
    GET    /api/conversations/{id}/                  -> getConversation
    GET    /api/conversations/{id}/messages/         -> listMessages
    PUT    /api/conversations/{id}/end/              -> endConversation
    PUT    /api/conversations/{id}/title/            -> updateTitle
    DELETE /api/conversations/{id}/                  -> deleteConversation
    GET    /api/conversations/messages/{id}/grammar-feedback/stream
                                                        -> streamGrammarFeedback
  }

  type StartFreeChatRequest {
    first_message: String | File(audio_file)
    search_context?: String
    topic?: String
    conversation_direction?: "CASUAL_CHAT" | "DEBATE" | "INTERVIEW_QA" | "EXPLANATION_PRACTICE"
    selected_question?: String
    custom_focus?: String
    include_audio_response?: Boolean = false
  }

  type StartRoleplayRequest {
    role_character: String
    search_context?: String
    include_audio_response?: Boolean = false
  }

  `role_character`는 클라이언트가 선택한 preset/custom 상황 또는 AI가 맡을 역할이에요.
  클라이언트 preset과 서버 roleplay prompt examples는 conversation snapshot의 `target_language`를 기준으로 연습 상황을 고르고, `feedback_language`는 도움말·설명 언어로만 사용해요.
  Conversation prompt policy도 snapshot의 `target_language`를 따라요. 한국어 target은 조사, 어미, 높임/격식, 띄어쓰기, 자연스러운 어순과 구어 뉘앙스를 우선하고, 영어 target은 tense, articles, prepositions, question formation, sentence completeness, natural spoken phrasing을 우선해요.

  type SendMessageRequest {
    message: String
  }

  type SendTurnRequest {
    text: String | File(audio_file)
    include_audio_response?: Boolean = false
  }

  type Pagination {
    limit: Integer
    offset: Integer
    total_count: Integer
    has_more: Boolean
    next_offset: Integer
  }

  type PaginatedConversations {
    results: List<Conversation>
    pagination: Pagination
  }

  type PaginatedMessages {
    results: List<Message>
    pagination: Pagination
  }

  type Conversation {
    id: UUID
    title?: String
    conversation_type: "FREE_CHAT" | "ROLE_PLAYING"
    role_character?: String
    language: LearningLanguageContext
    message_count: Integer
    status: "ACTIVE" | "COMPLETED"
    created_at: DateTime
    updated_at: DateTime
  }

  type Message {
    id: UUID
    conversation_id: UUID
    role: "user" | "assistant" | "system"
    content: String
    created_at: DateTime
    grammar_feedback?: GrammarFeedback
  }

  type ConversationResponse {
    conversation_id: UUID
    message_id: UUID
    conversation_type: String
    role_character?: String
    language: LearningLanguageContext
    response: String
    grammar_feedback?: GrammarFeedback
  }

  type MessageResponse {
    message_id: UUID
    response: String
    grammar_feedback?: GrammarFeedback
    turn_count: Integer
  }

  type VoiceAudioResponse {
    content_type: String
    base64: String
    format: String
  }

  type VoiceAudioError {
    message: String
    provider?: String
  }

  type MultimodalConversationResponse extends ConversationResponse {
    input_mode: "text" | "audio"
    transcript?: String
    audio?: VoiceAudioResponse
    audio_error?: VoiceAudioError
  }

  type MultimodalMessageResponse extends MessageResponse {
    input_mode: "text" | "audio"
    transcript?: String
    audio?: VoiceAudioResponse
    audio_error?: VoiceAudioError
  }
}
```

멀티모달 대화 API는 아래 다섯 가지 요청 형태를 기본 계약으로 사용해요.

```dsl
TextStart      = POST /api/conversations/start/free-chat/  { first_message, include_audio_response }
AudioStart     = POST /api/conversations/start/free-chat/  multipart { audio_file, include_audio_response }
RoleplayStart  = POST /api/conversations/start/roleplay/   { role_character, include_audio_response }
TextContinue   = POST /api/conversations/{id}/turn/        { text, include_audio_response }
AudioContinue  = POST /api/conversations/{id}/turn/        multipart { audio_file, include_audio_response }
```

`first_message`/`text`와 `audio_file`은 같은 요청에서 동시에 보낼 수 없어요. `audio_file` 요청은 백엔드가 STT로 `transcript`를 만든 뒤 기존 conversation flow에 전달해요. `include_audio_response=true`이면 free chat 시작, roleplay 시작, 대화 이어가기 응답의 AI 텍스트를 TTS로 변환해 `audio`에 담고, 대화 저장 이후 TTS만 실패하면 `audio_error`를 반환해 중복 메시지 재시도를 방지해요. 모바일 v1은 AI 응답을 항상 음성으로 들려주기 위해 시작/이어가기 요청 모두에서 `include_audio_response=true`를 전송해요.

모바일 v1은 문법 피드백 수신에 SSE보다 polling을 우선해요. 앱은 `ConversationResponse.message_id` 또는 `MessageResponse.message_id`를 받은 뒤 `GET /api/grammar/message/{message_id}/`를 반복 호출하고, `404`를 pending 또는 접근 불가 상태로 처리해요. SSE 스트림은 실시간성이 더 중요해질 때 선택적으로 사용해요.

`GET /api/conversations/`는 `updated_at desc`로 정렬된 `PaginatedConversations`를 반환해요.

`GET /api/conversations/{id}/messages/`는 `created_at asc`로 정렬된 `PaginatedMessages`를 반환해요.

두 목록 API의 query는 `limit=50`(1..100), `offset=0`(0 이상)이 기본값이에요.

`PUT /api/conversations/{id}/title/`은 `{"title":"Coffee Shop Roleplay"}`로 제목을 변경해요. `DELETE /api/conversations/{id}/`는 현재 사용자 소유 대화·메시지·문법 피드백을 복구 없이 삭제하고, 다른 사용자의 ID는 404로 처리해요.

SSE는 `/api/conversations/messages/{id}/grammar-feedback/stream?token=<access_token>`으로 인증해요. URL에 토큰이 포함되므로 로그·공유에 주의하고 모바일에서는 기존 polling 경로를 우선 사용해요.

## 7. Grammar 모듈

```dsl
module Grammar {
  router GrammarRouter {
    POST /api/grammar/check/         -> checkGrammar
    GET  /api/grammar/message/{id}/  -> getFeedbackByMessage
    GET  /api/grammar/stats/         -> getStats
  }

  type GrammarFeedback {
    id: UUID
    message_id: UUID
    original_text: String
    corrected_text: String
    has_errors: Boolean
    errors: List<GrammarError>
    created_at: DateTime
  }

  type GrammarError {
    original: String
    corrected: String
    explanation: String
  }

  type GrammarStats {
    total_messages: Integer
    messages_with_errors: Integer
    error_rate: Float
    common_errors: List<Dict>
    improvement_trend: List<Dict>
  }
}
```

`GET /api/grammar/message/{id}/`는 현재 사용자 소유 대화에 속한 message만 조회해요. `200`은 완료된 `GrammarFeedback`, `404`는 피드백 생성 전 pending·없는 message·타 사용자 message를 의미해요. 타 사용자 message도 `404`로 숨겨 ID 존재 여부를 노출하지 않아요. 인증 헤더가 없으면 현재 `HTTPBearer` 동작에 따라 `403`, 유효하지 않은 token은 `401`로 처리해요.

독립 검사 요청 `POST /api/grammar/check/`는 `{"text":"I want go home."}` 형태예요. 통계 조회의 선택 query `time_range`는 `7d`, `30d`, `90d`, `all` 등의 기간을 사용해요.

## 8. Search 모듈

```dsl
module Search {
  router SearchRouter {
    POST /api/search/                              -> search
    POST /api/search/topic-prep/                   -> prepareTopic
    POST /api/search/topic-prep/custom-questions/  -> prepareCustomFocusQuestions
    POST /api/search/topic-prep/directions/        -> regenerateTopicPrepDirections
  }

  service SearchService {
    async function search(query: String) -> SearchResult
    async function prepareTopic(topic: String) -> TopicPrepResult
    async function prepareSearchResults(query: String) -> PreparedSearchResult
    async function analyzeQuery(query: String) -> QueryAnalysis
    async function searchDuckDuckGo(query: String, analysis?: QueryAnalysis) -> List<SearchResultItem>
    async function summarizeResults(query: String, sources: List<SearchResultItem>, analysis: QueryAnalysis) -> String
  }

  type SearchRequest {
    query: String
  }

  type SearchResult {
    query: String
    enhanced_query: String
    language: LearningLanguageContext
    ready: Boolean
    summary?: String
    sources: List<SearchResultItem>
    quality: SearchQuality
    retry_guidance?: String
    example_queries: List<String>
    timestamp: DateTime
  }

  type SearchResultItem {
    title: String
    url: String
    snippet: String
  }

  type SearchQuality {
    is_sufficient: Boolean
    source_count: Integer
    relevant_source_count: Integer
    dropped_source_count: Integer
    relevance: Boolean
    freshness: Boolean
    specificity: Boolean
    reason?: String
    retry_suggestion?: String
  }

  type QueryAnalysis {
    original_query: String
    canonical_topic: String
    required_phrases: List<String>
    required_tokens: List<String>
    context_terms: List<String>
    recency_intent: Boolean
    exclude_terms: List<String>
    enhanced_query: String
  }

  type TopicPrepRequest {
    topic: String
  }

  type CustomFocusQuestionsRequest {
    topic: String
    custom_focus: String
  }

  type CustomFocusQuestionsResult {
    ready: Boolean
    custom_focus: String
    first_questions: List<String>
    retry_guidance?: String
  }

  type TopicPrepDirectionsRequest {
    topic: String
    previous_directions: List<String>
  }

  type TopicPrepDirectionsResult {
    directions: List<TopicPrepDirection>
  }

  type TopicPrepResult {
    ready: Boolean
    language: LearningLanguageContext
    card?: TopicPrepCard
    quality: TopicPrepQuality
    retry_guidance?: String
    example_topics: List<String>
  }

  Topic Prep summary와 direction title/description은 입력 topic 언어를 우선하고, 모호하면 `native_language`로 fallback해요. first question과 실제 conversation은 계속 `target_language` 연습에 맞춰 생성돼요.
  Topic Prep prompt policy도 conversation과 같은 target-language practice priorities를 사용해요.
  Low-quality 상태의 `retry_guidance`와 `example_topics`는 사용자가 이해할 수 있도록 `feedback_language`로 표시하되, 예시 유형은 target language 연습 목적을 반영해요.

  type TopicPrepCard {
    topic: String
    language: LearningLanguageContext
    summary: String
    directions: List<TopicPrepDirection>
    sources: List<SearchResultItem>
    quality: TopicPrepQuality
    timestamp: DateTime
  }

  type TopicPrepDirection {
    direction: "CASUAL_CHAT" | "DEBATE" | "EXPLANATION_PRACTICE"
    title: String
    description: String
    first_questions: List<String>
  }

  type TopicPrepQuality {
    is_sufficient: Boolean
    source_count: Integer
    has_enough_sources: Boolean
    relevance: Boolean
    freshness: Boolean
    specificity: Boolean
    reason?: String
    retry_suggestion?: String
  }
}
```

ready Topic Prep card는 정확히 세 recommendation을 제공해요. `custom_focus`는 고정 direction enum에 추가하지 않고 free-chat handoff에 별도로 전달해요. directions 재생성은 현재 화면의 summary/source를 유지한 채 새로운 recommendation 세 개와 target-language first question만 반환해요.

## 9. LLM 모듈

```dsl
module LLM {
  interface LLMProvider {
    async function chatCompletion(request: LLMRequest) -> LLMResponse
  }

  provider OpenRouterProvider
  provider OllamaProvider

  factory LLMProviderFactory {
    function createProvider(provider?: String) -> LLMProvider
  }

  type LLMRequest {
    messages: List<LLMMessage>
    model: String
    max_tokens: Integer
    temperature: Float
  }

  type LLMMessage {
    role: "system" | "user" | "assistant"
    content: String
  }

  type LLMResponse {
    content: String
  }
}
```

## 10. 환경변수 계약

환경변수의 필수 여부·기본값·설명은 [환경변수 문서](ENVIRONMENT.md)에서 관리해요. 시작용 예시는 [.env.example](../.env.example), 구현 기준은 [Settings](../backend/config.py)예요. 실행·CLI는 [README](../README.md), 배포·복구는 [운영 가이드](OPERATIONS.md)를 참고해요.

## 11. 보안 규칙

- 모든 사용자 데이터 접근은 인증 사용자 기준으로 제한해요.
- conversation/message 조회와 삭제는 `user_id` ownership을 검증해요.
- API key와 서버 전용 secret은 서버 환경변수로만 관리해요.
- Flutter 앱은 OpenRouter/OpenAI secret이나 Supabase service role key를 직접 보유하지 않아요.
- Flutter 앱은 Google Sign-In SDK로 받은 `id_token`과 Google `access_token`으로 Supabase 세션을 생성하고, FastAPI에는 Supabase `access_token`만 전달해요.
- 외부 LLM/검색 실패는 `ExternalAPIException` 계열로 감싸 응답해요.

## 12. Health Check

`GET /health`는 인증 없이 다음 응답을 반환해요. 현재 database 값은 고정 문자열이며 실제 DB 연결 검사가 아니에요.

```json
{"status":"healthy","database":"connected","version":"1.0.0"}
```

## 문서 변경 기록

- 2026-09-13: README의 상세 API 안내를 통합하고 환경변수 상세는 ENVIRONMENT.md로 분리했어요. API 동작 자체는 변경하지 않았어요.

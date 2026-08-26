# MoreThanHuman Backend DSL

> 최종 갱신: 2026-07-20 · 범위: FastAPI 백엔드 API + Flutter 모바일 연동

사용자 클라이언트는 `mobile/`의 Flutter 기반 모바일 앱으로 개발해요. 이 문서는 모바일 앱이 연동할 백엔드 도메인, 데이터 모델, API 계약을 정의해요.

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
    roleplay_difficulty: "EASY" | "NORMAL" | "CHALLENGE"?
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
  }

  type UserProfile {
    id: UUID
    email: String
    name: String
    is_active: Boolean
    oauth_provider?: String
    avatar_url?: String
    language: LearningLanguageContext
  }

  type LanguagePreferencesRequest extends LearningLanguageContext
  type LanguagePreferencesResponse extends LearningLanguageContext
}
```

모바일 앱은 Supabase Auth로 Google 로그인을 완료한 뒤 Supabase `access_token`을 FastAPI 보호 API의 `Authorization: Bearer` 헤더에 전달해요. `GET /api/auth/me`는 Supabase token을 검증하고, `profiles` row를 생성 또는 갱신한 뒤 기존 envelope 형식으로 `UserProfile`을 반환해요.
`POST /api/auth/swagger/token`은 Swagger 수동 테스트를 위한 Supabase email/password token helper예요. `ENV=dev`에서는 사용할 수 있고, dev 외 환경에서는 `SWAGGER_TOKEN_ISSUER_ENABLED=true`와 `SWAGGER_TOKEN_ISSUER_SECRET`을 설정한 뒤 요청 body의 `secret`이 일치해야 해요. 발급된 `access_token`을 Swagger `Authorize`에 `Bearer <access_token>` 형식으로 넣어요.
언어 선호는 프로필 기본값이며 새 대화 시작 시 `conversations` row에 snapshot으로 저장돼요. 기존 값이 없으면 `ko -> en`, feedback `ko`로 보정해요.
`PUT /api/auth/me/language-preferences`는 profile default만 갱신해요. 모바일 Account UX는 변경값이 새 대화부터 적용되고 기존 conversation은 생성 시점 snapshot을 유지한다고 안내해야 해요.

## 5. Conversation 모듈

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
    include_audio_response?: Boolean = false
  }

  type StartRoleplayRequest {
    role_character: String
    roleplay_difficulty?: "EASY" | "NORMAL" | "CHALLENGE" = "NORMAL"
    search_context?: String
    include_audio_response?: Boolean = false
  }

  `role_character`는 클라이언트가 선택한 preset/custom 상황 또는 AI가 맡을 역할이에요.
  `roleplay_difficulty`는 난이도와 진행 스타일을 나타내며, 서버가 roleplay prompt 생성 시점에 `role_character`와 조합해요.
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
    roleplay_difficulty?: "EASY" | "NORMAL" | "CHALLENGE"
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
    roleplay_difficulty?: "EASY" | "NORMAL" | "CHALLENGE"
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
RoleplayStart  = POST /api/conversations/start/roleplay/   { role_character, roleplay_difficulty, include_audio_response }
TextContinue   = POST /api/conversations/{id}/turn/        { text, include_audio_response }
AudioContinue  = POST /api/conversations/{id}/turn/        multipart { audio_file, include_audio_response }
```

`first_message`/`text`와 `audio_file`은 같은 요청에서 동시에 보낼 수 없어요. `audio_file` 요청은 백엔드가 STT로 `transcript`를 만든 뒤 기존 conversation flow에 전달해요. `include_audio_response=true`이면 free chat 시작, roleplay 시작, 대화 이어가기 응답의 AI 텍스트를 TTS로 변환해 `audio`에 담고, 대화 저장 이후 TTS만 실패하면 `audio_error`를 반환해 중복 메시지 재시도를 방지해요. 모바일 v1은 AI 응답을 항상 음성으로 들려주기 위해 시작/이어가기 요청 모두에서 `include_audio_response=true`를 전송해요.

모바일 v1은 문법 피드백 수신에 SSE보다 polling을 우선해요. 앱은 `ConversationResponse.message_id` 또는 `MessageResponse.message_id`를 받은 뒤 `GET /api/grammar/message/{message_id}/`를 반복 호출하고, `404`를 pending 또는 접근 불가 상태로 처리해요. SSE 스트림은 실시간성이 더 중요해질 때 선택적으로 사용해요.

`GET /api/conversations/`는 `updated_at desc`로 정렬된 `PaginatedConversations`를 반환해요.

`GET /api/conversations/{id}/messages/`는 `created_at asc`로 정렬된 `PaginatedMessages`를 반환해요.

## 6. Grammar 모듈

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

## 7. Search 모듈

```dsl
module Search {
  router SearchRouter {
    POST /api/search/             -> search
    POST /api/search/topic-prep/  -> prepareTopic
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

  type TopicPrepResult {
    ready: Boolean
    language: LearningLanguageContext
    card?: TopicPrepCard
    quality: TopicPrepQuality
    retry_guidance?: String
    example_topics: List<String>
  }

  Topic Prep의 ready card 질문과 fallback direction은 `target_language` 연습에 맞춰 생성돼요.
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
    direction: "CASUAL_CHAT" | "DEBATE" | "INTERVIEW_QA" | "EXPLANATION_PRACTICE"
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

## 8. LLM 모듈

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

## 9. 환경변수 계약

```dsl
env {
  DATABASE_URL?: String
  OPENROUTER_API_KEY: String
  OPENAI_API_KEY?: String
  LLM_PROVIDER?: "openrouter" | "ollama" = "openrouter"
  OLLAMA_BASE_URL?: String
  OPENROUTER_MODEL?: String
  OLLAMA_MODEL?: String

  GRAMMAR_MODEL_PROVIDER?: "openrouter" | "ollama" = "openrouter"
  GRAMMAR_OPENROUTER_MODEL?: String
  GRAMMAR_OLLAMA_MODEL?: String

  STT_PROVIDER?: "openrouter" | "openai" = "openrouter"
  STT_MODEL?: String = "openai/gpt-4o-mini-transcribe"
  TTS_PROVIDER?: "openrouter" | "openai" = "openrouter"
  TTS_MODEL?: String = "microsoft/mai-voice-2-flash"
  TTS_VOICE?: String = "en-US-Harper:MAI-Voice-2-Flash"
  TTS_RESPONSE_FORMAT?: "mp3" | "opus" | "aac" | "flac" | "wav" | "pcm" = "mp3"
  TTS_MAX_INPUT_CHARS?: Integer = 4000
  TTS_MAX_OUTPUT_MB?: Integer = 5
  VOICE_MAX_UPLOAD_MB?: Integer = 10
  VOICE_PROVIDER_TIMEOUT_SECONDS?: Float = 60

  SUPABASE_URL: String
  SUPABASE_PUBLISHABLE_KEY: String
  SUPABASE_AUTH_VERIFY_MODE?: "remote" = "remote"
  SUPABASE_AUTH_TIMEOUT_SECONDS?: Float = 5
  AUTO_CREATE_TABLES?: Boolean = false

  JWT_SECRET_KEY?: String

  DEBUG?: Boolean
  CORS_ORIGINS?: List<String>
  MAX_TOKENS?: Integer
  TEMPERATURE?: Float
  SEARCH_SUMMARY_MAX_TOKENS?: Integer
  SEARCH_QUERY_ANALYSIS_MAX_TOKENS?: Integer
  SEARCH_QUALITY_JUDGE_MAX_TOKENS?: Integer
  SEARCH_REGION?: String
  SEARCH_SAFESEARCH?: String
  SEARCH_RECENT_TIMELIMIT?: String
  SEARCH_BACKEND?: String
  SEARCH_MAX_RESULTS?: Integer
  SEARCH_MIN_RELEVANT_RESULTS?: Integer
  MAX_HISTORY_TURNS?: Integer
}
```

## 10. 보안 규칙

- 모든 사용자 데이터 접근은 인증 사용자 기준으로 제한해요.
- conversation/message 조회와 삭제는 `user_id` ownership을 검증해요.
- API key와 서버 전용 secret은 서버 환경변수로만 관리해요.
- Flutter 앱은 OpenRouter/OpenAI secret이나 Supabase service role key를 직접 보유하지 않아요.
- Flutter 앱은 Google Sign-In SDK로 받은 `id_token`과 Google `access_token`으로 Supabase 세션을 생성하고, FastAPI에는 Supabase `access_token`만 전달해요.
- 외부 LLM/검색 실패는 `ExternalAPIException` 계열로 감싸 응답해요.

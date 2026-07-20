# MoreThanHuman Backend DSL

> 최종 갱신: 2026-06-22 · 범위: FastAPI 백엔드 API + Flutter 모바일 연동

사용자 클라이언트는 `mobile/`의 Flutter 기반 모바일 앱으로 개발해요. 이 문서는 모바일 앱이 연동할 백엔드 도메인, 데이터 모델, API 계약을 정의해요.

## 1. 시스템

```dsl
system MoreThanHuman {
  product: "AI 기반 영어 회화 학습 플랫폼"
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
    created_at: DATETIME
    updated_at: DATETIME
  }

  table conversations {
    id: UUID PRIMARY KEY
    user_id: UUID FOREIGN KEY -> profiles(id)
    title: STRING?
    conversation_type: "FREE_CHAT" | "ROLE_PLAYING"
    role_character: STRING?
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
```

인증이 필요한 API는 `Authorization: Bearer <access_token>` 헤더를 사용해요.

## 4. Auth 모듈

```dsl
module Auth {
  router AuthRouter {
    GET  /api/auth/me                    -> getCurrentUser
  }

  type UserProfile {
    id: UUID
    email: String
    name: String
    is_active: Boolean
    oauth_provider?: String
    avatar_url?: String
  }
}
```

모바일 앱은 Supabase Auth로 Google 로그인을 완료한 뒤 Supabase `access_token`을 FastAPI 보호 API의 `Authorization: Bearer` 헤더에 전달해요. `GET /api/auth/me`는 Supabase token을 검증하고, `profiles` row를 생성 또는 갱신한 뒤 기존 envelope 형식으로 `UserProfile`을 반환해요.

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
    search_context?: String
  }

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

멀티모달 대화 API는 아래 네 가지 요청 형태를 기본 계약으로 사용해요.

```dsl
TextStart      = POST /api/conversations/start/free-chat/  { first_message }
AudioStart     = POST /api/conversations/start/free-chat/  multipart { audio_file }
TextContinue   = POST /api/conversations/{id}/turn/        { text }
AudioContinue  = POST /api/conversations/{id}/turn/        multipart { audio_file }
```

`first_message`/`text`와 `audio_file`은 같은 요청에서 동시에 보낼 수 없어요. `audio_file` 요청은 백엔드가 STT로 `transcript`를 만든 뒤 기존 conversation flow에 전달해요. `include_audio_response=true`이면 AI 응답 텍스트를 TTS로 변환해 `audio`에 담고, 대화 저장 이후 TTS만 실패하면 `audio_error`를 반환해 중복 메시지 재시도를 방지해요.

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
    card?: TopicPrepCard
    quality: TopicPrepQuality
    retry_guidance?: String
    example_topics: List<String>
  }

  type TopicPrepCard {
    topic: String
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

  STT_PROVIDER?: "openai" = "openai"
  STT_MODEL?: String = "gpt-4o-mini-transcribe"
  TTS_PROVIDER?: "openai" = "openai"
  TTS_MODEL?: String = "gpt-4o-mini-tts"
  TTS_VOICE?: String = "alloy"
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

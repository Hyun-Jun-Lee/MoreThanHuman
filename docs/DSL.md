# MoreThanHuman Backend DSL

> 최종 갱신: 2026-05-26 · 범위: FastAPI 백엔드 API

향후 사용자 클라이언트는 Flutter 기반 모바일 앱으로 개발해요. 이 문서는 모바일 앱이 연동할 백엔드 도메인, 데이터 모델, API 계약을 정의해요.

## 1. 시스템

```dsl
system MoreThanHuman {
  product: "AI 기반 영어 회화 학습 플랫폼"
  backend: FastAPI
  architecture: ModularMonolith
  database: SQLiteDevelopment | PostgreSQLProduction
  packageManager: uv
  futureClient: FlutterMobileApp

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
  table users {
    id: UUID PRIMARY KEY
    email: STRING UNIQUE NOT NULL
    hashed_password: STRING?
    name: STRING NOT NULL
    is_active: BOOLEAN
    oauth_provider: STRING?
    oauth_provider_id: STRING?
    created_at: DATETIME
    updated_at: DATETIME
  }

  table refresh_tokens {
    id: UUID PRIMARY KEY
    user_id: UUID FOREIGN KEY -> users(id)
    device_id: STRING NOT NULL
    token_hash: STRING NOT NULL
    expires_at: DATETIME
    revoked_at: DATETIME?
    created_at: DATETIME
    last_used_at: DATETIME?
  }

  table conversations {
    id: UUID PRIMARY KEY
    user_id: UUID FOREIGN KEY -> users(id)
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
    POST /api/auth/register              -> register
    POST /api/auth/login                 -> login
    POST /api/auth/dev/token             -> issueDevToken
    POST /api/auth/refresh               -> refresh
    POST /api/auth/logout                -> logout
    POST /api/auth/google/mobile         -> loginWithGoogleIdToken
    GET  /api/auth/google/login?device_id=...          -> googleLogin
    GET  /api/auth/google/callback?code=...&state=...  -> googleCallback
    GET  /api/auth/me                    -> getCurrentUser
  }

  type RegisterRequest {
    email: String
    password: String
    name: String
    device_id: String
  }

  type LoginRequest {
    email: String
    password: String
    device_id: String
  }

  type DevTokenRequest {
    email?: String = "swagger-test@example.com"
    name?: String = "Swagger Test User"
    device_id?: String = "swagger-local"
  }

  type RefreshRequest {
    refresh_token: String
    device_id: String
  }

  type LogoutRequest {
    refresh_token: String
    device_id: String
  }

  type GoogleMobileLoginRequest {
    id_token: String
    device_id: String
  }

  type TokenResponse {
    access_token: String
    refresh_token: String
    token_type: "bearer"
  }

  type UserProfile {
    id: UUID
    email: String
    name: String
    is_active: Boolean
    oauth_provider?: String
  }
}
```

`POST /api/auth/google/mobile`은 Flutter 앱이 Google Sign-In SDK에서 받은 `id_token`과 설치 단위 `device_id`를 서버에 전달하는 모바일 기본 로그인 API예요. 서버는 `GOOGLE_CLIENT_ID`를 audience로 Google 토큰을 검증한 뒤 `TokenResponse`를 반환해요. 같은 Google 계정은 기존 사용자를 재사용하고, 같은 이메일의 비밀번호 계정이 있으면 자동 연결하지 않고 `409`를 반환해요. 기존 `/api/auth/google/login`과 `/api/auth/google/callback`은 서버 callback OAuth 흐름으로 유지해요.

## 5. Conversation 모듈

```dsl
module Conversation {
  router ConversationRouter {
    POST   /api/conversations/start/free-chat/       -> startFreeChat
    POST   /api/conversations/start/roleplay/        -> startRoleplay
    POST   /api/conversations/{id}/message/          -> sendMessage
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
    first_message: String
    search_context?: String
    topic?: String
    conversation_direction?: "CASUAL_CHAT" | "DEBATE" | "INTERVIEW_QA" | "EXPLANATION_PRACTICE"
    selected_question?: String
  }

  type StartRoleplayRequest {
    role_character: String
    search_context?: String
  }

  type SendMessageRequest {
    message: String
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
}
```

모바일 v1은 문법 피드백 수신에 SSE보다 polling을 우선해요. 앱은 `ConversationResponse.message_id` 또는 `MessageResponse.message_id`를 받은 뒤 `GET /api/grammar/message/{message_id}/`를 반복 호출하고, `404`를 pending 상태로 처리해요. SSE 스트림은 실시간성이 더 중요해질 때 선택적으로 사용해요.

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
  LLM_PROVIDER?: "openrouter" | "ollama" = "openrouter"
  OLLAMA_BASE_URL?: String
  OPENROUTER_MODEL?: String
  OLLAMA_MODEL?: String

  GRAMMAR_MODEL_PROVIDER?: "openrouter" | "ollama" = "openrouter"
  GRAMMAR_OPENROUTER_MODEL?: String
  GRAMMAR_OLLAMA_MODEL?: String

  JWT_SECRET_KEY: String
  JWT_ALGORITHM?: String
  JWT_ACCESS_TOKEN_EXPIRE_MINUTES?: Integer

  GOOGLE_CLIENT_ID?: String
  GOOGLE_CLIENT_SECRET?: String
  GOOGLE_REDIRECT_URI?: String

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
- API key, OAuth secret, JWT secret은 서버 환경변수로만 관리해요.
- Flutter 앱은 백엔드 secret을 직접 보유하지 않아요.
- Flutter 앱은 Google Sign-In SDK로 받은 `id_token`만 서버에 전달하고, 서버가 Google 토큰을 검증한 뒤 자체 token pair를 발급해요.
- 외부 LLM/검색 실패는 `ExternalAPIException` 계열로 감싸 응답해요.

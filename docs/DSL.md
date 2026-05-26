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
    POST /api/auth/refresh               -> refresh
    POST /api/auth/logout                -> logout
    GET  /api/auth/google/login          -> googleLogin  # device_id 쿼리 포함, state로 콜백까지 전달
    GET  /api/auth/google/callback       -> googleCallback
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

  type RefreshRequest {
    refresh_token: String
    device_id: String
  }

  type LogoutRequest {
    refresh_token: String
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
  }

  type StartRoleplayRequest {
    role_character: String
    search_context?: String
  }

  type SendMessageRequest {
    message: String
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
    POST /api/search/ -> search
  }

  service SearchService {
    async function search(query: String) -> SearchResult
    async function searchDuckDuckGo(query: String) -> List<SearchResultItem>
    async function summarizeResults(query: String, sources: List<SearchResultItem>) -> String
  }

  type SearchRequest {
    query: String
  }

  type SearchResult {
    query: String
    summary: String
    sources: List<SearchResultItem>
    timestamp: DateTime
  }

  type SearchResultItem {
    title: String
    url: String
    snippet: String
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
  OPENROUTER_API_KEY?: String
  LLM_PROVIDER: "openrouter" | "ollama"
  OLLAMA_BASE_URL?: String
  OPENROUTER_MODEL?: String
  OLLAMA_MODEL?: String

  GRAMMAR_MODEL_PROVIDER?: "openrouter" | "ollama"
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
  MAX_HISTORY_TURNS?: Integer
}
```

## 10. 보안 규칙

- 모든 사용자 데이터 접근은 인증 사용자 기준으로 제한해요.
- conversation/message 조회와 삭제는 `user_id` ownership을 검증해요.
- API key, OAuth secret, JWT secret은 서버 환경변수로만 관리해요.
- Flutter 앱은 백엔드 secret을 직접 보유하지 않아요.
- 외부 LLM/검색 실패는 `ExternalAPIException` 계열로 감싸 응답해요.

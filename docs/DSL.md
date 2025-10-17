영어 회화 학습 웹 서비스 DSL
1. 시스템 아키텍처
dslsystem Architecture {
    version: "1.0.0"
    backend: FastAPI
    database: PostgreSQL
    frontend: Svelte
    structure: Modular Monolithic

    modules: [
        User,
        Conversation,
        Grammar,
        Search,
        Voice,
        Dashboard,
        Web
    ]
}
2. 데이터베이스 스키마
dsldatabase Schema {
    
    table users {
        id: UUID PRIMARY KEY
        email: TEXT UNIQUE
        password_hash: TEXT
        name: TEXT
        created_at: DATETIME
        updated_at: DATETIME
    }
    
    table conversations {
        id: UUID PRIMARY KEY
        user_id: UUID FOREIGN KEY -> users(id)
        topic: TEXT  // "UFC", "baseball", "travel"
        context_data: JSON  // Tavily 검색 결과
        tavily_used: BOOLEAN
        message_count: INTEGER
        status: TEXT  // "ACTIVE" | "COMPLETED"
        created_at: DATETIME
        updated_at: DATETIME
    }
    
    table messages {
        id: UUID PRIMARY KEY
        conversation_id: UUID FOREIGN KEY -> conversations(id)
        role: TEXT  // "user" | "assistant" | "system"
        content: TEXT
        audio_url: TEXT  // 음성 파일 경로 (선택사항)
        created_at: DATETIME
    }
    
    table grammar_feedback {
        id: UUID PRIMARY KEY
        message_id: UUID FOREIGN KEY -> messages(id)
        original_text: TEXT
        corrected_text: TEXT
        has_errors: BOOLEAN
        errors: JSON  // List of error objects
        created_at: DATETIME
    }
    
    table search_cache {
        id: UUID PRIMARY KEY
        query: TEXT UNIQUE
        results: JSON  // Tavily 검색 결과
        created_at: DATETIME
        expires_at: DATETIME  // 24시간 후
    }
    
    table api_usage {
        id: UUID PRIMARY KEY
        user_id: UUID FOREIGN KEY -> users(id)
        service_type: TEXT  // "TAVILY" | "OPENROUTER"
        endpoint: TEXT
        tokens_used: INTEGER
        cost: FLOAT
        created_at: DATETIME
    }
}
3. 모듈별 정의
3.1 User 모듈
dslmodule User {
    
    // Repository Layer
    repository UserRepository {
        await function save(user: User) -> Result<UUID, Error>
        await function findById(id: UUID) -> Result<User, Error>
        await function findByEmail(email: String) -> Result<User, Error>
        await function updatePassword(id: UUID, passwordHash: String) -> Result<Void, Error>
        await function deleteById(id: UUID) -> Result<Void, Error>
    }
    
    // Service Layer
    service UserService {
        await function register(email: String, password: String, name: String) -> Result<User, Error>
        await function login(email: String, password: String) -> Result<AuthToken, Error>
        await function getUser(id: UUID) -> Result<User, Error>
        await function updateProfile(id: UUID, name?: String) -> Result<Void, Error>
        await function changePassword(id: UUID, oldPassword: String, newPassword: String) -> Result<Void, Error>
        function hashPassword(password: String) -> String
        function verifyPassword(password: String, hash: String) -> Boolean
        function generateToken(userId: UUID) -> String
    }
    
    // API Router
    router UserRouter {
        POST   /api/auth/register/     -> register
        POST   /api/auth/login/        -> login
        GET    /api/users/me/          -> getCurrentUser
        PUT    /api/users/me/          -> updateProfile
        POST   /api/users/me/password/ -> changePassword
    }
    
    // Types
    type User {
        id: UUID
        email: String
        passwordHash: String
        name: String
        createdAt: DateTime
        updatedAt: DateTime
    }
    
    type AuthToken {
        accessToken: String
        tokenType: String
        expiresIn: Integer
    }
}
3.2 Conversation 모듈
dslmodule Conversation {
    
    // Repository Layer
    repository ConversationRepository {
        await function save(conversation: Conversation) -> Result<UUID, Error>
        await function findById(id: UUID) -> Result<Conversation, Error>
        await function findByUserId(userId: UUID, limit?: Integer, offset?: Integer) -> List<Conversation>
        await function updateStatus(id: UUID, status: ConversationStatus) -> Result<Void, Error>
        await function updateMessageCount(id: UUID, count: Integer) -> Result<Void, Error>
        await function deleteById(id: UUID) -> Result<Void, Error>
        
        await function saveMessage(message: Message) -> Result<UUID, Error>
        await function findMessageById(id: UUID) -> Result<Message, Error>
        await function getMessages(conversationId: UUID, limit?: Integer, offset?: Integer) -> List<Message>
        await function getRecentMessages(conversationId: UUID, turnCount: Integer) -> List<Message>
        await function deleteMessage(id: UUID) -> Result<Void, Error>
    }
    
    // Service Layer
    service ConversationService {
        await function startConversation(
            userId: UUID,
            topic: String,
            firstMessage: String
        ) -> Result<ConversationResponse, Error>
        
        await function continueConversation(
            conversationId: UUID,
            userMessage: String
        ) -> Result<MessageResponse, Error>
        
        await function getConversation(id: UUID) -> Result<Conversation, Error>
        await function getConversations(userId: UUID, limit?: Integer, offset?: Integer) -> List<Conversation>
        await function getMessages(conversationId: UUID, limit?: Integer, offset?: Integer) -> List<Message>
        await function endConversation(id: UUID) -> Result<Void, Error>
        
        // LLM 호출
        await function generateResponse(
            systemPrompt: String,
            contextData: JSON,
            messageHistory: List<Message>,
            userInput: String
        ) -> Result<String, Error>
        
        // Helper 함수
        function buildSystemPrompt(topic: String, contextData: JSON) -> String
        function prepareMessageHistory(messages: List<Message>, turnLimit: Integer) -> List<Dict>
    }
    
    // API Router
    router ConversationRouter {
        POST   /api/conversations/start/           -> startConversation
        POST   /api/conversations/{id}/message/    -> continueConversation
        GET    /api/conversations/                 -> getConversations
        GET    /api/conversations/{id}/            -> getConversation
        GET    /api/conversations/{id}/messages/   -> getMessages
        PUT    /api/conversations/{id}/end/        -> endConversation
        DELETE /api/conversations/{id}/            -> deleteConversation
    }
    
    // Web Pages
    page ConversationListPage {
        route: "/conversations"
        template: "conversation_list.html"
        
        components {
            ConversationTable {
                endpoint: "/api/conversations"
                
                columns: [topic, messageCount, status, createdAt]
                actions: [view, continue, delete]
                
                onRowClick: navigateToDetail
            }
            
            NewConversationButton {
                action: navigateToTopicSelection
            }
        }
    }
    
    page TopicSelectionPage {
        route: "/conversations/new"
        template: "topic_selection.html"
        
        components {
            TopicCards {
                topics: [
                    {id: "ufc", name: "UFC", icon: "🥊", description: "MMA 경기 토론"},
                    {id: "baseball", name: "Baseball", icon: "⚾", description: "야구 경기 토론"},
                    {id: "travel", name: "Travel", icon: "✈️", description: "여행 경험 공유"}
                ]
                
                onSelect: startConversationWithTopic
            }
        }
    }
    
    page ChatPage {
        route: "/conversations/{id}"
        template: "chat.html"
        
        components {
            ChatHeader {
                display: [topic, messageCount]
                actions: [endConversation]
            }
            
            MessageList {
                endpoint: "/api/conversations/{id}/messages"
                realtime: false
                
                display: [role, content, grammarFeedback, timestamp]
                voicePlayback: true
            }
            
            ChatInput {
                components: [
                    VoiceInputButton,
                    TextInput,
                    SendButton
                ]
                
                onSubmit: sendMessage
            }
            
            LoadingIndicator {
                show: whenWaitingForResponse
            }
        }
    }
    
    // Types
    type Conversation {
        id: UUID
        userId: UUID
        topic: String
        contextData: JSON
        tavilyUsed: Boolean
        messageCount: Integer
        status: ConversationStatus
        createdAt: DateTime
        updatedAt: DateTime
    }
    
    type Message {
        id: UUID
        conversationId: UUID
        role: MessageRole
        content: String
        audioUrl: String?
        createdAt: DateTime
    }
    
    type ConversationStatus = "ACTIVE" | "COMPLETED"
    
    type MessageRole = "user" | "assistant" | "system"
    
    type ConversationResponse {
        conversationId: UUID
        response: String
        grammarFeedback: GrammarFeedback
        tavilyUsed: Boolean
        contextInfo: SearchContextInfo?
    }
    
    type MessageResponse {
        messageId: UUID
        response: String
        grammarFeedback: GrammarFeedback
        turnCount: Integer
    }
}
3.3 Grammar 모듈
dslmodule Grammar {
    
    // Repository Layer
    repository GrammarRepository {
        await function save(feedback: GrammarFeedback) -> Result<UUID, Error>
        await function findById(id: UUID) -> Result<GrammarFeedback, Error>
        await function findByMessageId(messageId: UUID) -> Result<GrammarFeedback, Error>
        await function getUserStats(userId: UUID, timeRange?: TimeRange) -> GrammarStats
    }
    
    // Service Layer
    service GrammarService {
        await function checkGrammar(text: String) -> Result<GrammarFeedback, Error>
        await function saveFeedback(messageId: UUID, feedback: GrammarFeedback) -> Result<UUID, Error>
        await function getFeedback(messageId: UUID) -> Result<GrammarFeedback, Error>
        await function getUserStats(userId: UUID, timeRange?: TimeRange) -> GrammarStats
        
        // LLM 호출
        await function analyzeGrammar(text: String) -> Result<GrammarAnalysis, Error>
        
        // Helper 함수
        function buildGrammarPrompt(text: String) -> String
        function parseGrammarResponse(response: String) -> GrammarFeedback
    }
    
    // API Router
    router GrammarRouter {
        POST   /api/grammar/check/              -> checkGrammar
        GET    /api/grammar/message/{id}/       -> getFeedbackByMessage
        GET    /api/grammar/stats/              -> getUserStats
    }
    
    // Web Pages
    page GrammarStatsPage {
        route: "/grammar/stats"
        template: "grammar_stats.html"
        
        components {
            StatsOverview {
                endpoint: "/api/grammar/stats"
                
                display: [
                    totalErrors,
                    commonErrors,
                    improvementTrend,
                    errorsByType
                ]
            }
            
            ErrorBreakdown {
                chart: "pie"
                data: errorTypeDistribution
            }
            
            ImprovementChart {
                chart: "line"
                data: errorsOverTime
            }
        }
    }
    
    // Types
    type GrammarFeedback {
        id: UUID
        messageId: UUID
        originalText: String
        correctedText: String
        hasErrors: Boolean
        errors: List<GrammarError>
        createdAt: DateTime
    }
    
    type GrammarError {
        type: ErrorType
        original: String
        corrected: String
        explanation: String
        position: {
            start: Integer
            end: Integer
        }
    }
    
    type ErrorType = "grammar" | "word_choice" | "expression" | "spelling" | "punctuation"
    
    type GrammarAnalysis {
        hasErrors: Boolean
        errors: List<GrammarError>
        correctedSentence: String
        overallQuality: Float  // 0-1 scale
    }
    
    type GrammarStats {
        totalMessages: Integer
        messagesWithErrors: Integer
        errorRate: Float
        commonErrors: List<{
            type: ErrorType
            count: Integer
            examples: List<String>
        }>
        improvementTrend: List<{
            date: Date
            errorRate: Float
        }>
    }
}
3.4 Search 모듈
dslmodule Search {
    
    // Repository Layer
    repository SearchRepository {
        await function saveCache(cache: SearchCache) -> Result<UUID, Error>
        await function findByQuery(query: String) -> Result<SearchCache, Error>
        await function findValidCache(query: String) -> Result<SearchCache, Error>
        await function deleteExpired() -> Result<Integer, Error>
        await function getMonthlyUsage(userId?: UUID) -> Integer
    }
    
    // Service Layer
    service SearchService {
        await function search(
            query: String,
            userId?: UUID,
            forceRefresh?: Boolean
        ) -> Result<SearchResult, Error>
        
        await function getOrCache(query: String, userId?: UUID) -> Result<SearchResult, Error>
        await function checkUsageLimit(userId?: UUID) -> Result<UsageStatus, Error>
        
        // Tavily API 호출
        await function callTavilyAPI(query: String) -> Result<TavilyResponse, Error>
        
        // Helper 함수
        function buildSearchQuery(topic: String) -> String
        function formatSearchResults(results: TavilyResponse) -> SearchResult
        function isValidCache(cache: SearchCache) -> Boolean
    }
    
    // API Router
    router SearchRouter {
        POST   /api/search/              -> search
        GET    /api/search/usage/        -> getUsageStatus
        DELETE /api/search/cache/clear/  -> clearExpiredCache
    }
    
    // Types
    type SearchCache {
        id: UUID
        query: String
        results: JSON
        createdAt: DateTime
        expiresAt: DateTime
    }
    
    type SearchResult {
        query: String
        results: List<SearchResultItem>
        fromCache: Boolean
        timestamp: DateTime
    }
    
    type SearchResultItem {
        title: String
        url: String
        snippet: String
        publishedDate: DateTime?
        score: Float
    }
    
    type TavilyResponse {
        query: String
        results: List<TavilyResult>
    }
    
    type TavilyResult {
        title: String
        url: String
        content: String
        score: Float
        published_date: String?
    }
    
    type UsageStatus {
        used: Integer
        limit: Integer
        remaining: Integer
        resetDate: Date
    }
    
    type SearchContextInfo {
        title: String
        summary: String
        sources: List<String>
    }
}
3.5 Voice 모듈
dslmodule Voice {
    
    // Service Layer
    service VoiceService {
        // 음성 파일 저장/관리
        await function saveAudioFile(
            userId: UUID,
            audioData: Bytes,
            format: AudioFormat
        ) -> Result<String, Error>
        
        await function getAudioFile(audioUrl: String) -> Result<Bytes, Error>
        await function deleteAudioFile(audioUrl: String) -> Result<Void, Error>
        
        // Helper 함수
        function generateAudioPath(userId: UUID, messageId: UUID) -> String
        function validateAudioFormat(format: AudioFormat) -> Boolean
    }
    
    // API Router
    router VoiceRouter {
        POST   /api/voice/upload/         -> uploadAudio
        GET    /api/voice/{filename}/     -> getAudio
        DELETE /api/voice/{filename}/     -> deleteAudio
    }
    
    // Types
    type AudioFormat = "webm" | "wav" | "mp3" | "ogg"
    
    type AudioMetadata {
        duration: Float
        size: Integer
        format: AudioFormat
        sampleRate: Integer
    }
}
3.6 Dashboard 모듈
dslmodule Dashboard {
    
    // Repository Layer
    repository DashboardRepository {
        await function getSystemOverview(userId: UUID) -> SystemOverview
        await function getConversationStats(userId: UUID, timeRange?: TimeRange) -> ConversationStats
        await function getGrammarProgress(userId: UUID, timeRange?: TimeRange) -> GrammarProgress
        await function getUsageStats(userId: UUID) -> UsageStats
    }
    
    // Service Layer
    service DashboardService {
        await function getSystemOverview(userId: UUID) -> SystemOverview
        await function getConversationStats(userId: UUID, timeRange?: TimeRange) -> ConversationStats
        await function getGrammarProgress(userId: UUID, timeRange?: TimeRange) -> GrammarProgress
        await function getUsageStats(userId: UUID) -> UsageStats
        await function getActivityFeed(userId: UUID, limit?: Integer) -> List<Activity>
    }
    
    // API Router
    router DashboardRouter {
        GET /api/dashboard/overview/          -> getSystemOverview
        GET /api/dashboard/conversations/     -> getConversationStats
        GET /api/dashboard/grammar/           -> getGrammarProgress
        GET /api/dashboard/usage/             -> getUsageStats
        GET /api/dashboard/activities/        -> getActivityFeed
    }
    
    // Web Pages
    page DashboardPage {
        route: "/dashboard"
        template: "dashboard.html"
        
        components {
            OverviewPanel {
                endpoint: "/api/dashboard/overview"
                
                cards: [
                    {
                        title: "총 대화",
                        value: "totalConversations",
                        icon: "message-square",
                        trend: "conversationGrowth"
                    },
                    {
                        title: "학습 시간",
                        value: "totalStudyTime",
                        icon: "clock",
                        trend: "timeGrowth"
                    },
                    {
                        title: "문법 정확도",
                        value: "grammarAccuracy",
                        icon: "check-circle",
                        trend: "accuracyGrowth"
                    },
                    {
                        title: "이번 달 대화",
                        value: "monthlyConversations",
                        icon: "calendar",
                        trend: "monthlyGrowth"
                    }
                ]
            }
            
            ActivityFeed {
                endpoint: "/api/dashboard/activities"
                limit: 10
                
                display: [
                    timestamp,
                    activityType,
                    description
                ]
            }
            
            ConversationChart {
                endpoint: "/api/dashboard/conversations"
                
                chart: "line"
                title: "대화 추이"
                timeRange: "30d"
            }
            
            GrammarProgressChart {
                endpoint: "/api/dashboard/grammar"
                
                chart: "bar"
                title: "문법 개선도"
                timeRange: "30d"
            }
            
            QuickActions {
                buttons: [
                    {
                        text: "새 대화 시작",
                        action: "navigateTo('/conversations/new')",
                        icon: "plus-circle"
                    },
                    {
                        text: "문법 통계",
                        action: "navigateTo('/grammar/stats')",
                        icon: "bar-chart"
                    },
                    {
                        text: "대화 히스토리",
                        action: "navigateTo('/conversations')",
                        icon: "history"
                    }
                ]
            }
        }
    }
    
    // Types
    type SystemOverview {
        totalConversations: Integer
        conversationGrowth: Float
        totalStudyTime: Duration
        timeGrowth: Float
        grammarAccuracy: Float
        accuracyGrowth: Float
        monthlyConversations: Integer
        monthlyGrowth: Float
        lastUpdated: DateTime
    }
    
    type ConversationStats {
        totalConversations: Integer
        averageLength: Float  // 평균 턴 수
        topicBreakdown: List<{
            topic: String
            count: Integer
            percentage: Float
        }>
        conversationsOverTime: List<{
            date: Date
            count: Integer
        }>
    }
    
    type GrammarProgress {
        overallAccuracy: Float
        accuracyOverTime: List<{
            date: Date
            accuracy: Float
        }>
        errorReduction: Float
        mostImprovedAreas: List<{
            errorType: ErrorType
            improvement: Float
        }>
    }
    
    type UsageStats {
        tavilyUsage: {
            used: Integer
            limit: Integer
            percentage: Float
        }
        openrouterUsage: {
            tokensUsed: Integer
            estimatedCost: Float
        }
        storageUsage: {
            audioFiles: Integer
            totalSize: Integer
        }
    }
    
    type Activity {
        id: UUID
        timestamp: DateTime
        activityType: ActivityType
        description: String
        metadata: JSON
    }
    
    type ActivityType = "CONVERSATION_STARTED" | "CONVERSATION_COMPLETED" | "GRAMMAR_IMPROVED" | "MILESTONE_REACHED"
    
    type TimeRange = "7d" | "30d" | "90d" | "all"
}
3.7 Web 모듈
dslmodule Web {
    
    // Template Convention Rules
    template_rules {
        base_template: "templates/base.html"
        
        inheritance_required: true
        convention: |
            1. 모든 도메인 템플릿은 반드시 base.html을 상속해야 함
            2. {% extends "base.html" %} 필수 선언
            3. 독립적인 HTML 구조 금지
            
        blocks: {
            title: "페이지 제목"
            meta: "메타 태그"
            content: "메인 콘텐츠 영역"
            extra_css: "추가 CSS 파일"
            extra_js: "추가 JavaScript 파일"
        }
        
        template_search_paths: [
            "templates/",
            "domains/{module}/templates/"
        ]
        
        helpers: {
            formatDate: "날짜 포맷팅"
            formatDuration: "시간 포맷팅"
            showAlert: "알림 메시지 표시"
            showModal: "모달 창 표시"
        }
    }
    
    // Main Application Router
    router MainRouter {
        // Public Pages
        GET /                              -> LandingPage
        GET /login                         -> LoginPage
        GET /register                      -> RegisterPage
        
        // Protected Pages
        GET /dashboard                     -> DashboardPage
        GET /conversations                 -> ConversationListPage
        GET /conversations/new             -> TopicSelectionPage
        GET /conversations/{id}            -> ChatPage
        GET /grammar/stats                 -> GrammarStatsPage
        GET /profile                       -> ProfilePage
        
        // Static Files
        GET /static/*                      -> StaticFiles
    }
    
    // Landing Page
    page LandingPage {
        route: "/"
        template: "landing.html"
        
        components {
            Hero {
                title: "AI와 함께하는 영어 회화 학습"
                description: "최신 뉴스와 정보를 바탕으로 실용적인 영어 회화를 연습하세요"
                ctaButton: "시작하기"
            }
            
            Features {
                items: [
                    {
                        icon: "🎯",
                        title: "맞춤형 주제",
                        description: "스포츠, 여행 등 관심 있는 주제로 대화"
                    },
                    {
                        icon: "🔊",
                        title: "음성 지원",
                        description: "말하기와 듣기 연습을 동시에"
                    },
                    {
                        icon: "✍️",
                        title: "실시간 피드백",
                        description: "문법 오류를 즉시 교정"
                    },
                    {
                        icon: "📊",
                        title: "학습 통계",
                        description: "진행 상황을 한눈에 확인"
                    }
                ]
            }
        }
    }
    
    // Login Page
    page LoginPage {
        route: "/login"
        template: "login.html"
        
        components {
            LoginForm {
                endpoint: "/api/auth/login"
                
                fields: [
                    {name: "email", type: "email", required: true},
                    {name: "password", type: "password", required: true}
                ]
                
                onSuccess: redirectToDashboard
                onError: showErrorMessage
            }
            
            RegisterLink {
                text: "계정이 없으신가요? 회원가입"
                href: "/register"
            }
        }
    }
    
    // Register Page
    page RegisterPage {
        route: "/register"
        template: "register.html"
        
        components {
            RegisterForm {
                endpoint: "/api/auth/register"
                
                fields: [
                    {name: "name", type: "text", required: true},
                    {name: "email", type: "email", required: true},
                    {name: "password", type: "password", required: true},
                    {name: "confirmPassword", type: "password", required: true}
                ]
                
                validation: {
                    passwordMatch: true
                    passwordMinLength: 8
                }
                
                onSuccess: redirectToLogin
                onError: showErrorMessage
            }
        }
    }
    
    // Profile Page
    page ProfilePage {
        route: "/profile"
        template: "profile.html"
        
        components {
            ProfileInfo {
                endpoint: "/api/users/me"
                
                display: [name, email, createdAt]
                actions: [editProfile, changePassword]
            }
            
            UsageInfo {
                endpoint: "/api/dashboard/usage"
                
                display: [tavilyUsage, openrouterUsage, storageUsage]
            }
        }
    }
    
    // Common Components
    component VoiceInputButton {
        props: [onTranscript: Function, onError: Function]
        
        features: [
            startRecording,
            stopRecording,
            visualFeedback
        ]
        
        apis: [
            WebSpeechAPI_SpeechRecognition
        ]
    }
    
    component MessageBubble {
        props: [
            message: Message,
            grammarFeedback: GrammarFeedback?,
            showVoiceButton: Boolean
        ]
        
        display: [
            role,
            content,
            grammarErrors,
            timestamp,
            voicePlayback
        ]
    }
    
    component GrammarErrorDisplay {
        props: [feedback: GrammarFeedback]
        
        display: [
            originalText,
            correctedText,
            errorHighlights,
            explanations
        ]
        
        style: {
            error: "underline red wavy"
            correct: "text green"
        }
    }
}
4. FastAPI 애플리케이션 구조
dslapplication FastAPIApp {
    
    main: "main.py"
    
    dependencies: [
        "fastapi",
        "sqlalchemy",
        "psycopg2-binary",
        "pydantic",
        "python-jose[cryptography]",
        "passlib[bcrypt]",
        "jinja2",
        "httpx",
        "pytest",
        "pytest-asyncio"
    ]
    
    structure {
        /
        ├── main.py                    // FastAPI 앱 초기화
        ├── database.py               // PostgreSQL 연결
        ├── config.py                 // 환경 변수 관리
        ├── shared/                   // 공통 유틸리티
        │   ├── __init__.py
        │   ├── database.py          // 공통 DB 연결
        │   ├── auth.py              // JWT 인증
        │   ├── exceptions.py        // 커스텀 예외
        │   ├── utils.py             // 공통 유틸리티
        │   └── types.py             // 공통 타입 정의
        ├── domains/                  // 도메인별 수직 구조
        │   ├── user/
        │   │   ├── __init__.py
        │   │   ├── models.py
        │   │   ├── repository.py
        │   │   ├── service.py
        │   │   ├── router.py
        │   │   └── tests/
        │   ├── conversation/
        │   │   └── (동일 구조)
        │   ├── grammar/
        │   │   └── (동일 구조)
        │   ├── search/
        │   │   └── (동일 구조)
        │   ├── voice/
        │   │   └── (동일 구조)
        │   ├── dashboard/
        │   │   └── (동일 구조)
        │   └── web/
        │       ├── __init__.py
        │       ├── router.py
        │       ├── templates/
        │       │   ├── base.html
        │       │   ├── landing.html
        │       │   ├── dashboard.html
        │       │   ├── chat.html
        │       │   └── ...
        │       └── tests/
        ├── static/
        │   ├── css/
        │   ├── js/
        │   └── audio/
        ├── tests/
        │   ├── __init__.py
        │   ├── conftest.py
        │   └── test_main.py
        └── pytest.ini
    }
    
    startup {
        loadConfig()
        initializeDatabase()
        registerDomainRouters()
        setupStaticFiles()
        setupTemplating()
        setupCORS()
    }
}
5. 테스트 전략
dsltesting TestStrategy {
    
    // Repository Layer - 실제 DB 연동 테스트
    repository_tests {
        setup: 테스트용 PostgreSQL DB
        
        coverage {
            - CRUD 기본 동작
            - 트랜잭션 처리
            - 에러 케이스
            - 동시성 처리
        }
    }
    
    // Service Layer - 비즈니스 로직 테스트
    service_tests {
        focus: Repository를 호출하지 않는 순수 로직
        
        examples {
            - 데이터 변환 로직
            - 유효성 검증
            - 계산 로직
            - 포맷팅
        }
    }
    
    // Router Layer - API 엔드포인트 테스트
    router_tests {
        tool: FastAPI TestClient
        
        coverage {
            - HTTP 요청/응답
            - 인증/인가
            - 에러 핸들링
            - 응답 포맷
        }
    }
    
    // Integration Tests
    integration_tests {
        scope: 전체 워크플로우
        
        scenarios {
            - 회원가입 → 로그인 → 대화 시작 → 메시지 전송
            - 검색 캐싱 동작 확인
            - 문법 체크 전체 플로우
        }
    }
    
    // 테스트 설정
    conftest.py {
        fixtures {
            @pytest.fixture
            def test_db():
                # 테스트용 PostgreSQL DB
                
            @pytest.fixture
            def test_client():
                # FastAPI 테스트 클라이언트
                
            @pytest.fixture
            def authenticated_client():
                # 인증된 테스트 클라이언트
                
            @pytest.fixture
            def sample_user():
                # 테스트용 사용자
                
            @pytest.fixture
            def sample_conversation():
                # 테스트용 대화
        }
    }
    
    pytest.ini {
        [tool:pytest]
        testpaths = ["domains", "tests"]
        python_files = ["test_*.py"]
        python_classes = ["Test*"]
        python_functions = ["test_*"]
        addopts = [
            "--verbose",
            "--tb=short",
            "--cov=domains",
            "--cov-report=html",
            "--cov-report=term-missing"
        ]
        markers = [
            "unit: marks tests as unit tests",
            "integration: marks tests as integration tests",
            "slow: marks tests as slow running"
        ]
    }
    
    // 테스트 실행 명령
    commands {
        "pytest"                          // 모든 테스트 실행
        "pytest domains/conversation/tests" // 특정 도메인 테스트
        "pytest -m unit"                  // 유닛 테스트만
        "pytest -m integration"           // 통합 테스트만
        "pytest --cov"                    // 커버리지 포함
        "pytest -x"                       // 첫 번째 실패에서 중단
        "pytest -v"                       // 상세 출력
    }
}
6. 주요 워크플로우
dslworkflow UserRegistration {
    1. POST /api/auth/register (이메일, 비밀번호, 이름)
    2. UserService.register()
       - 비밀번호 해싱
       - 사용자 생성
       - DB 저장
    3. 성공 → 로그인 페이지로 리다이렉트
}

workflow ConversationFlow {
    1. 사용자가 주제 선택 (예: "UFC")
    2. POST /api/conversations/start
    3. SearchService.getOrCache() → Tavily 검색 (캐시 우선)
    4. ConversationService.startConversation()
       - Conversation 생성
       - 시스템 프롬프트 구성 (주제 + 검색 결과)
       - LLM API 호출 (첫 번째 응답 생성)
       - GrammarService.checkGrammar() (사용자 입력 문법 체크)
    5. 응답 + 문법 피드백 반환
    
    6. 사용자가 메시지 입력
    7. POST /api/conversations/{id}/message
    8. ConversationService.continueConversation()
       - 최근 10턴 조회
       - 메시지 히스토리 구성
       - LLM API 호출
       - GrammarService.checkGrammar()
    9. 응답 + 문법 피드백 반환
    
    10. 대화 종료 시 status를 "COMPLETED"로 변경
}

workflow VoiceInteraction {
    1. 사용자가 마이크 버튼 클릭
    2. Web Speech API 시작 (브라우저)
    3. 음성 → 텍스트 변환 (실시간)
    4. 텍스트가 채팅 입력창에 표시
    5. 전송 버튼 클릭 → 일반 메시지 플로우
    
    6. AI 응답 수신 후
    7. Web Speech API의 SpeechSynthesis 사용
    8. 텍스트 → 음성 자동 재생
    9. 재생 컨트롤 제공 (일시정지, 재개, 속도 조절)
}

workflow GrammarCheck {
    1. 사용자 메시지 전송 시
    2. 백엔드에서 병렬 처리:
       a) ConversationService.generateResponse()
       b) GrammarService.checkGrammar()
    3. GrammarService.analyzeGrammar()
       - 문법 체크용 프롬프트 구성
       - LLM API 호출
       - JSON 응답 파싱
    4. GrammarFeedback 생성 및 저장
    5. 프론트엔드로 응답 전송
    6. 사용자 메시지 아래 문법 피드백 표시
}

workflow SearchCaching {
    1. 대화 시작 시 주제 확인 (예: "UFC")
    2. SearchService.getOrCache("UFC recent")
    3. 캐시 확인:
       - 24시간 이내 캐시 존재 → 반환 (Tavily 호출 X)
       - 캐시 없음 → Tavily API 호출
    4. 월간 사용량 체크:
       - 1,000회 미만 → 검색 실행
       - 1,000회 이상 → 오래된 캐시 사용 또는 에러
    5. 새 검색 결과를 캐시에 저장 (24시간 TTL)
}

workflow DashboardView {
    1. GET /dashboard → DashboardPage
    2. 여러 API 병렬 호출:
       - GET /api/dashboard/overview
       - GET /api/dashboard/conversations
       - GET /api/dashboard/grammar
       - GET /api/dashboard/usage
    3. 각 컴포넌트별 데이터 렌더링:
       - 통계 카드 (총 대화, 학습 시간, 문법 정확도)
       - 대화 추이 차트
       - 문법 개선도 차트
       - 활동 피드
    4. Quick Actions 버튼 제공
}
7. 타입 관리 정책
dsltypes TypeManagementPolicy {
    
    // 공통 타입 (shared/types.py)
    shared_types {
        - BaseResponse: API 응답 기본 모델
        - TimestampMixin: 생성/수정 시간 믹스인
        - UUIDMixin: UUID 필드 믹스인
        - Result<T>: 성공/실패 결과 타입
    }
    
    // 도메인별 타입 관리
    domain_types {
        user: "domains/user/models.py" {
            - User, AuthToken
        }
        
        conversation: "domains/conversation/models.py" {
            - Conversation, Message
            - ConversationStatus, MessageRole
            - ConversationResponse, MessageResponse
        }
        
        grammar: "domains/grammar/models.py" {
            - GrammarFeedback, GrammarError
            - ErrorType, GrammarAnalysis, GrammarStats
        }
        
        search: "domains/search/models.py" {
            - SearchCache, SearchResult
            - TavilyResponse, UsageStatus
        }
    }
    
    // API 정책
    api_policy {
        pagination: false  // 프론트엔드에서 처리
        loadMore: true     // "더 불러오기" 방식
        realtime: false    // 실시간 업데이트 불필요

        // 표준 응답 형식
        response_format {
            success: {
                structure: {
                    success: true,
                    data: Any,
                    message: String?
                }
                example: |
                    {
                        "success": true,
                        "data": {
                            "conversation_id": "uuid",
                            "response": "Great! Let's talk about..."
                        },
                        "message": "대화가 시작되었습니다"
                    }
            }

            error: {
                structure: {
                    success: false,
                    error: String,
                    details: Any?
                }
                example: |
                    {
                        "success": false,
                        "error": "대화를 찾을 수 없습니다",
                        "details": {
                            "conversation_id": "invalid-uuid"
                        }
                    }
            }

            list: {
                structure: {
                    success: true,
                    data: {
                        items: List<Any>,
                        total: Integer,
                        count: Integer
                    }
                }
                example: |
                    {
                        "success": true,
                        "data": {
                            "conversations": [...],
                            "total": 15,
                            "count": 10
                        }
                    }
            }
        }

        // 에러 처리 정책
        error_handling {
            validation_errors: {
                http_status: 400,
                response: "success: false, error: validation message"
            }

            authentication_errors: {
                http_status: 401,
                response: "success: false, error: authentication required"
            }

            not_found_errors: {
                http_status: 404,
                response: "success: false, error: resource not found"
            }

            rate_limit_errors: {
                http_status: 429,
                response: "success: false, error: rate limit exceeded"
            }

            server_errors: {
                http_status: 500,
                response: "success: false, error: internal server error"
            }

            external_api_errors: {
                http_status: 502,
                response: "success: false, error: external service error"
            }
        }

        // 쿼리 파라미터 정책
        query_parameters {
            filtering: {
                format: "?field=value&field2=value2"
                example: "?topic=UFC&status=ACTIVE"
            }

            sorting: {
                format: "?sort_by=field&order=asc|desc"
                example: "?sort_by=created_at&order=desc"
                default: "created_at DESC"
            }

            pagination: {
                format: "?limit=n&offset=m"
                example: "?limit=20&offset=40"
                default: "limit=50, offset=0"
            }
        }
    }
}
8. 개발 가이드 @ 순수 함수 위주로 함수형 프로그래밍을 선호함.
dsldevelopment DomainDevelopmentGuide {
    
    // 새 도메인 추가 체크리스트
    newDomain {
        1. domains/{domain_name}/ 폴더 생성
        2. __init__.py 파일 생성
        3. models.py - Pydantic 모델 정의
        4. repository.py - 데이터 접근 계층
        5. service.py - 비즈니스 로직
        6. router.py - API 엔드포인트
        7. tests/ - 도메인별 테스트
        8. main.py에 라우터 등록
        9. 데이터베이스 마이그레이션 생성
    }
    
    // 각 레이어별 책임
    layers {
        models.py {
            responsibility: "데이터 구조 정의, 유효성 검증"
            contains: [
                "Pydantic 모델",
                "타입 정의",
                "유효성 검증 로직",
                "직렬화/역직렬화"
            ]
        }
        
        repository.py {
            responsibility: "데이터 접근, CRUD 연산"
            contains: [
                "SQLAlchemy 쿼리",
                "데이터 변환",
                "트랜잭션 관리"
            ]
        }
        
        service.py {
            responsibility: "비즈니스 로직, 도메인 규칙"
            contains: [
                "비즈니스 규칙",
                "도메인 로직",
                "외부 서비스 연동 (Tavily, OpenRouter)"
            ]
        }
        
        router.py {
            responsibility: "HTTP 요청/응답, API 계약"
            contains: [
                "FastAPI 엔드포인트",
                "요청/응답 모델",
                "HTTP 상태 코드",
                "인증/인가"
            ]
        }
    }
    
    // 모듈 독립성
    modularDevelopment {
        principle: "각 도메인은 독립적으로 개발 및 테스트 가능"
        
        guidelines: [
            "shared/ 모듈만 의존",
            "다른 도메인 직접 참조 금지",
            "서비스 계층에서 도메인 간 연동",
            "각 도메인별 완전한 테스트 커버리지"
        ]
    }
    
    // 보안 고려사항
    security {
        authentication: {
            method: "JWT (JSON Web Token)"
            implementation: "python-jose"
            tokenExpiry: "24시간"
        }
        
        password: {
            hashing: "bcrypt"
            implementation: "passlib"
            minLength: 8
        }
        
        apiKeys: {
            storage: "환경 변수 (.env)"
            access: "백엔드에서만 사용"
            exposure: "프론트엔드에 노출 금지"
        }
        
        cors: {
            allowedOrigins: ["http://localhost:5173"]  // Svelte 개발 서버
            allowedMethods: ["GET", "POST", "PUT", "DELETE"]
            allowCredentials: true
        }
    }
}

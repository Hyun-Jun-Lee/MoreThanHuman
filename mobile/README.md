# Curitalk Mobile

관심사 기반 AI 영어 회화 앱 Curitalk의 Flutter iOS·Android 클라이언트예요.

## 확인

```bash
flutter pub get
flutter analyze
flutter test
```

## 플랫폼 설정

- Android application ID: `com.morethanhuman.curitalk`
- iOS bundle ID: `com.morethanhuman.curitalk`
- Android minimum SDK: 23
- 실제 실행 전 Android SDK 또는 Xcode/CocoaPods 설정이 필요해요.

## 기반 패키지

| 패키지 | 역할 |
|--------|------|
| `flutter_riverpod` | 앱 상태와 비동기 상태 관리 |
| `go_router` | 화면 라우팅과 인증 redirect |
| `dio` | FastAPI HTTP client와 interceptor |
| `flutter_secure_storage` | access/refresh token과 device ID 보관 |
| `google_sign_in` | Google 모바일 로그인 |

## 현재 구조

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router/
│   │   └── app_router.dart
│   └── theme/
│       ├── app_color_scheme.dart
│       ├── app_component_themes.dart
│       ├── app_semantic_colors.dart
│       ├── app_theme.dart
│       └── tokens/          # 기본 디자인 토큰
├── core/
│   ├── config/              # dart-define 기반 앱 설정
│   ├── network/             # Dio client, 응답 envelope, 오류 매핑
│   ├── storage/             # token pair와 installation ID 보안 저장
│   └── widgets/             # 화면 공통 레이아웃과 상호작용 위젯
└── features/
    ├── auth/                # 인증 API, 세션 모델, Riverpod controller
    ├── onboarding/          # 완료 상태와 3장 onboarding 화면
    ├── conversation/
    │   └── presentation/widgets/
    ├── home/
    │   └── presentation/widgets/
    ├── roleplay_setup/
    │   ├── application/      # roleplay 상황·난이도 선택 상태
    │   ├── domain/           # preset, difficulty, role_character helper
    │   └── presentation/     # Roleplay Setup 화면과 widgets
    └── topic_prep/
        ├── application/      # topic prep API 상태
        ├── data/             # topic prep API repository
        ├── domain/           # 준비 카드 응답 모델
        └── presentation/     # Topic Input, Topic Prep 화면과 widgets

assets/
├── fonts/                   # Inter, JetBrains Mono variable font
└── licenses/                # 번들 font 라이선스
```

화면과 상태는 `features/` 아래에 feature-first로 배치하고, 여러 기능에서 재사용하는 UI만 `core/widgets/`에 둬요.

## 디자인 토큰

`lib/app/theme/tokens/tokens.dart`를 통해 아래 기본 토큰을 가져와요.

| 토큰 | 역할 |
|------|------|
| `AppPalette` | monochrome core, pastel block, 상태 색상 |
| `AppTypography` | Inter·JetBrains Mono 기반 TextStyle |
| `AppSpacing` | 8px 기반 간격과 화면 padding |
| `AppRadius` | 입력창, 카드, pill radius |
| `AppBorderWidth` | 기본·focus 테두리 굵기 |
| `AppSize` | 접근 가능한 touch target과 component 크기 |
| `AppMotion` | 버튼·상태 변화에 사용하는 애니메이션 시간 |

`AppColorScheme`은 공통 Material 3 색상 역할을, `AppSemanticColors`는 대화·문법 피드백·검색 상태처럼 Curitalk 전용 역할을 제공해요. `AppComponentThemes`는 버튼·입력창·Chip·카드·Bottom sheet·Bottom navigation의 상태별 스타일을 정의해요. `AppTheme.light`가 세 계층을 등록하며 앱 루트에서 사용해요.

토큰 원본은 `docs/design/DESIGN_SYSTEM.md`이며 화면 코드에는 raw Hex나 임의 수치를 직접 작성하지 않아요.

## 1차 공통 컴포넌트

화면에서는 `lib/core/widgets/widgets.dart` 하나를 import해 아래 위젯을 사용해요.

| 컴포넌트 | 역할 |
|----------|------|
| `AppScaffold` | Safe area와 화면 기본 여백이 적용된 페이지 골격 |
| `AppPrimaryButton` | loading·disabled 상태를 포함한 핵심 CTA |
| `AppBottomActionBar` | 화면 하단 CTA의 여백과 Safe area 처리 |
| `AppSectionLabel` | uppercase mono 스타일의 섹션 레이블 |
| `AppColorBlockCard` | 파스텔 color block 기반 콘텐츠 카드 |
| `AppAsyncStateView` | loading·error·empty 공통 상태 표현 |
| `AppPageIndicator` | 온보딩 등에 사용하는 현재 페이지 표시 |
| `AppModalSheet` | 키보드와 Safe area를 고려한 공통 bottom sheet |
| `MainNavigationBar` | Home·Chat·History·Profile 주 내비게이션 |

## 2차 도메인 컴포넌트

선택 UI처럼 여러 기능이 공유하는 요소는 `core/widgets/`, 대화와 Home 전용 요소는 각 feature의 `presentation/widgets/`에서 제공해요.

| 컴포넌트 | 역할 |
|----------|------|
| `AppSelectionChip` | 대화 방향·난이도 등의 단일 선택 chip |
| `AppSelectionCard` | 대화 방식·롤플레이 상황 등의 선택 카드 |
| `RecentConversationCard` | Home의 pastel 최근 대화 카드 |
| `ChatBubble` | 사용자·AI 역할별 정렬과 semantic color가 적용된 말풍선 |
| `GrammarFeedbackCard` | 사용자 메시지 아래의 교정 문장과 설명 |
| `TypingIndicator` | Reduce Motion 설정을 따르는 AI 응답 대기 표시 |

## 3차 입력·상태 컴포넌트

입력과 상태 전환처럼 화면 구현 시 오류가 생기기 쉬운 상호작용을 공통 컴포넌트로 제공해요.

| 컴포넌트 | 역할 |
|----------|------|
| `AppTextField` | 오류·제출·접근성 레이블을 지원하는 기본 입력창 |
| `SourceLinkTile` | 검색 출처의 제목·host와 열기 동작을 표시하는 행 |
| `TopicRetryCard` | 검색 품질 부족 안내와 두 가지 복구 동작 제공 |
| `ChatComposer` | 빈 메시지 차단, 전송·음성·sending 상태를 처리하는 입력창 |
| `NaturalFeedbackBadge` | 자연스러운 사용자 문장에 표시하는 접근 가능한 상태 chip |

## API와 보안 저장소

`ApiClient`는 백엔드의 `{ success, data, message }` envelope를 `ApiResponse<T>`로 변환하고, FastAPI·네트워크·timeout 오류를 `ApiException`으로 통일해요. 인증 요청에는 secure storage의 access token을 `Authorization: Bearer` 헤더로 자동 추가하며 로그인처럼 공개 요청은 `requiresAuth: false`로 제외할 수 있어요.

`SecureTokenStorage`는 access token과 refresh token을 하나의 JSON 값으로 저장해 token pair가 부분 저장되는 상황을 방지해요. `clearTokens()`는 installation ID를 유지하므로 로그아웃 후에도 같은 설치 식별자를 재사용할 수 있어요.

`authControllerProvider`는 앱 시작 시 저장된 token pair로 `/auth/me`를 조회해 `authenticated` 또는 `unauthenticated` 상태를 제공해요. `AsyncLoading`은 최초 확인과 로그인·로그아웃 처리 중 상태예요. Google SDK에서 받은 id token은 `signInWithGoogleIdToken()`에 전달하고, 로그아웃은 서버 revoke가 실패해도 로컬 token을 반드시 삭제해요.

인증 API가 `401`을 반환하면 `TokenRefreshInterceptor`가 `/auth/refresh`를 호출해 token pair를 rotate하고 원 요청을 한 번 재시도해요. 동시 `401`은 하나의 refresh 작업을 공유해요. 세션 revision을 함께 확인하므로 로그아웃이나 새 로그인 뒤에 늦게 도착한 refresh 결과는 저장하지 않아요. refresh token이 거절되면 secure storage를 비우고 Riverpod 상태를 `unauthenticated`로 전환하지만, 네트워크·서버 일시 장애에서는 token을 보존해 다음 재시도를 허용해요.

## 앱 시작 흐름

`go_router`는 onboarding 완료 상태와 `authControllerProvider`를 관찰해 아래 순서로 이동해요.

```text
Splash → Onboarding(최초 1회) → Google Login → Home
```

- Splash: 저장된 세션과 onboarding 완료 여부 확인
- Onboarding: 3장 소개 후 완료 상태를 secure storage에 저장
- Login: Google Sign-In SDK의 id token을 백엔드 `/auth/google/mobile`로 전달
- Home: 사용자 이름과 최근 대화 5개를 표시하고, 없으면 시작 제안을 표시
- Free Chat: Home sheet에서 Topic Input으로 이동한 뒤 `POST /api/search/topic-prep/`로 준비 카드를 불러옴
- Roleplay: Home sheet에서 Roleplay Setup으로 이동한 뒤 상황과 난이도를 선택함

## Topic Prep 흐름

Home의 `START CONVERSATION`에서 Free Chat을 선택하면 Topic Input 화면으로 이동해요. Topic Input은 2자 미만 입력을 클라이언트에서 막고, 예시 topic chip으로 빠르게 주제를 채울 수 있게 해요.

Topic Prep 화면은 전달받은 topic으로 `POST /api/search/topic-prep/`를 호출해 loading, ready, low-quality, error 상태를 표시해요.

| 상태 | 표시 |
|------|------|
| `loading` | 준비 중 안내 |
| `ready=true` | summary, sources, direction 4개, 선택 direction의 첫 질문 3개 |
| `ready=false` | retry guidance, example topic chip, edit topic 복귀 |
| `error` | 재시도 가능한 오류 상태 |

기본 선택은 `CASUAL_CHAT`과 첫 번째 질문이에요. 출처 링크는 현재 화면에 표시만 하고, 외부 브라우저 열기는 `url_launcher`를 도입하는 후속 작업에서 연결해요. 첫 답변 입력과 `POST /api/conversations/start/free-chat/` 연동도 다음 단계에서 구현해요.

## Roleplay Setup 흐름

Home의 `START CONVERSATION`에서 Roleplay를 선택하면 Roleplay Setup 화면으로 이동해요. 사용자는 preset 상황 카드 7개 중 하나를 고르거나, custom 입력으로 원하는 상황을 직접 작성할 수 있어요.

| 선택 | 동작 |
|------|------|
| preset 상황 | 선택 즉시 Start Roleplay CTA 활성화 |
| custom 상황 | 2자 이상 입력 시 Start Roleplay CTA 활성화 |
| 난이도 | `Easy`, `Normal`, `Challenge` 중 선택하며 기본값은 `Normal` |

현재 단계에서는 선택 결과를 백엔드 계약에 맞는 `role_character` 문자열로 합성할 수 있게 준비해요. 실제 `POST /api/conversations/start/roleplay/` 호출과 Conversation 화면 이동은 Conversation 화면 구현 단계에서 연결해요.

Google Sign-In 실행 시 다음 `dart-define`을 사용할 수 있어요.

```bash
flutter run \
  --dart-define=GOOGLE_CLIENT_ID=<ios-oauth-client-id> \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-oauth-client-id>
```

Android에서 `google-services.json`을 사용하지 않으면 `GOOGLE_SERVER_CLIENT_ID`가 필요해요. iOS는 `GOOGLE_CLIENT_ID`와 별개로 OAuth 설정의 `REVERSED_CLIENT_ID` URL scheme을 `Info.plist`에 등록해야 실제 로그인이 동작해요. 서버의 `GOOGLE_CLIENT_ID`는 동일한 Web OAuth client ID를 사용해요.

기본 API 주소는 `http://localhost:8010/api/`예요. 실행 환경에 따라 `--dart-define`으로 변경해요.

```bash
# iOS simulator / macOS
flutter run --dart-define=API_BASE_URL=http://localhost:8010/api/

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010/api/
```

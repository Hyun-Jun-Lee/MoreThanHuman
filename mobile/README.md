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
│   └── widgets/             # 화면 공통 레이아웃과 상호작용 위젯
└── features/
    ├── conversation/
    │   └── presentation/widgets/
    ├── home/
    │   └── presentation/widgets/
    └── topic_prep/
        └── presentation/widgets/

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

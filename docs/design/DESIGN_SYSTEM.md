---
name: Curitalk Interface System
platform: Flutter iOS and Android
theme: light
colors:
  primary: '#000000'
  on-primary: '#ffffff'
  canvas: '#ffffff'
  inverse-canvas: '#000000'
  surface-soft: '#f3f4f6'
  surface-subtle: '#f9f9ff'
  hairline: '#d1d5db'
  hairline-soft: '#e5e7eb'
  ink: '#000000'
  ink-secondary: '#4b5563'
  inverse-ink: '#ffffff'
  block-lime: '#d9f99d'
  block-lime-soft: '#e5f5d3'
  block-lilac: '#e8e4f4'
  block-lilac-soft: '#f1f3ff'
  block-cream: '#f6f4eb'
  block-blue: '#dbeafe'
  block-coral: '#ffb694'
  block-pink: '#fbdccd'
  block-navy: '#2a303d'
  accent-terracotta: '#8d4926'
  semantic-success: '#2e7d32'
  semantic-warning: '#7c5800'
  semantic-error: '#ba1a1a'
  error-container: '#ffdad6'
  overlay-scrim: '#000000'
typography:
  display-xl:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '800'
    lineHeight: '1.0'
    letterSpacing: -1.44px
  display-lg:
    fontFamily: Inter
    fontSize: 40px
    fontWeight: '800'
    lineHeight: '1.05'
    letterSpacing: -0.8px
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.15'
    letterSpacing: -0.32px
  headline-md:
    fontFamily: Inter
    fontSize: 26px
    fontWeight: '700'
    lineHeight: '1.25'
    letterSpacing: -0.26px
  body-lg:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '400'
    lineHeight: '1.4'
    letterSpacing: -0.14px
  body:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.45'
    letterSpacing: -0.14px
  body-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.45'
    letterSpacing: 0
  button:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: '1.25'
    letterSpacing: 0
  label-mono:
    fontFamily: JetBrains Mono
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.7px
  caption-mono:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 1.2px
spacing:
  hair: 1px
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px
  screen-padding: 24px
  section-gap: 48px
rounded:
  xs: 2px
  sm: 6px
  md: 12px
  lg: 24px
  xl: 32px
  pill: 50px
  full: 9999px
borders:
  hairline: 1px
  focused: 2px
sizes:
  touch-target: 48px
  icon: 24px
  icon-button: 44px
  input-min-height: 48px
  bottom-nav-height: 72px
motion:
  fast: 120ms
  standard: 240ms
  slow: 300ms
---

## 1. 시스템 방향

Curitalk은 Figma 마케팅 시스템의 편집형 대비와 컬러 블록 문법을 모바일 학습 앱에 맞게 변형해요. 기본 화면은 흑백의 깨끗한 캔버스를 유지하고, 대화 주제·학습 피드백·최근 대화처럼 의미가 있는 콘텐츠 묶음에만 파스텔 컬러 블록을 사용해요.

이 시스템의 핵심은 **Warm Terracotta & Sand가 아니라 Monochrome Editorial + Pastel Color Blocks**예요. Terracotta는 일부 Stitch 화면의 아이콘이나 작은 강조 요소에만 제한적으로 등장하며, 앱의 주 배경이나 CTA 색상이 아니에요.

핵심 원칙은 다음과 같아요.

- Black과 White가 CTA, 본문, 내비게이션을 담당해요.
- Lime, Lilac, Cream, Mint 계열, Blue, Coral, Pink는 콘텐츠를 구분하는 큰 면으로 사용해요.
- 버튼은 pill, 주요 카드와 패널은 24px 이상의 큰 radius를 사용해요.
- 그림자와 gradient보다 색상 면, 여백, 테두리 굵기로 계층을 만들어요.
- 큰 Inter 제목과 uppercase JetBrains Mono 레이블을 함께 사용해 편집형 리듬을 만들어요.

## 2. 기준 자료와 우선순위

디자인 판단 우선순위는 아래와 같아요.

1. 이 문서의 semantic token과 사용 규칙
2. docs/design/stitch_design/의 PNG 화면
3. 같은 폴더의 HTML 색상·spacing·radius 값

Stitch HTML은 시각적 참고 자료이며 Flutter 위젯 구조나 화면별 임시 theme 값을 그대로 복사하지 않아요. 화면마다 생성된 grayscale, periwinkle, terracotta theme map이 다르므로 이 문서가 구현 시 정규화된 기준이 돼요.

## 3. 색상

### 3.1 Monochrome Core

- primary와 ink: 핵심 CTA, 선택 상태, 제목, 주요 본문
- canvas: 앱 기본 배경과 흰색 카드
- inverse-canvas: 사용자 말풍선과 강한 선택 상태
- surface-soft: 아이콘 버튼, 비활성 행, 낮은 우선순위 컨테이너
- surface-subtle: bottom sheet와 아주 옅은 패널
- hairline, hairline-soft: 입력창, 카드, 리스트 구분선
- ink-secondary: 설명, 보조 문구, 시간 정보에만 사용

원본 마케팅 시스템은 mid-gray 텍스트를 거의 사용하지 않지만, Curitalk 모바일 앱은 긴 설명과 상태 정보가 많으므로 접근 가능한 보조 텍스트 역할을 허용해요. 중요한 학습 내용과 CTA는 항상 ink를 사용해요.

### 3.2 Pastel Color Blocks

- block-lime: 높은 주목도가 필요한 topic summary, 준비 완료 상태
- block-lime-soft: 최근 대화 카드와 낮은 강도의 긍정 상태
- block-lilac: 인라인 문법 원문, 학습 안내
- block-lilac-soft: 대화 준비 카드, 선택 가능한 연습 방식
- block-cream: 문법 교정 제안, roleplay 카드, 부드러운 안내
- block-blue: 스포츠·정보형 최근 대화 카드
- block-coral: 제한적인 feature highlight
- block-pink: 보조 학습 feature 또는 일러스트레이션
- block-navy: 역상 정보 패널처럼 강한 대비가 필요한 예외적인 영역

한 컴포넌트에는 하나의 block color만 사용해요. Home의 최근 대화 목록처럼 같은 계층의 카드가 반복될 때는 주제 구분을 위해 block color를 순환할 수 있어요.

### 3.3 Terracotta의 역할

accent-terracotta는 start_conversation_sheet 같은 일부 Stitch 산출물에서 사용된 보조 강조색이에요. 다음 영역에만 사용할 수 있어요.

- 작은 원형 아이콘 배경
- 일러스트레이션의 제한적인 강조
- Coral 계열 블록 위의 고대비 세부 요소

Primary CTA, 앱 배경, 전체 화면 theme에는 사용하지 않아요.

### 3.4 Semantic Colors

- semantic-success: 완료·검증 성공 아이콘
- semantic-warning: 검색 정보가 불충분하거나 재시도가 필요한 상태
- semantic-error: 입력 오류와 실패 상태
- error-container: 오류 설명의 낮은 강도 배경
- overlay-scrim: modal과 bottom sheet 뒤에 45\~60% opacity로 적용

색상만으로 상태를 전달하지 않고 아이콘과 텍스트를 함께 제공해요.

## 4. 타이포그래피

### 4.1 Font Family

- **Inter**: 모든 display, headline, body, button
- **JetBrains Mono**: category, eyebrow, caption, metadata

figmaSans와 figmaMono의 오픈소스 대체로 사용해요. Stitch 산출물에 포함된 Quicksand 같은 화면별 임시 font는 구현 기준에 포함하지 않아요.

### 4.2 사용 규칙

- display-xl: 온보딩과 핵심 empty state의 짧은 제목
- display-lg: Home 인사말과 화면의 강한 opener
- headline-lg: 화면 제목과 큰 카드 제목
- headline-md: 대화 주제, 준비 카드, bottom sheet 제목
- body-lg: 온보딩 설명과 핵심 학습 문장
- body: 기본 대화·설명 문장
- body-sm: 카드 설명, 보조 정보
- button: 모든 text CTA
- label-mono: 버튼의 기술적 레이블, category chip
- caption-mono: metadata, 진행 단계, 작은 상태 레이블

Mono 역할은 항상 uppercase를 기본으로 하며 문장형 본문에는 사용하지 않아요. Display는 두 줄에서 세 줄 이내로 유지하고, 큰 제목일수록 line height와 letter spacing을 더 촘촘하게 사용해요.

## 5. Layout & Spacing

- 기본 단위는 8px예요. 4px은 미세 정렬, 12px은 compact 내부 간격에만 사용해요.
- 일반 화면의 좌우 padding은 screen-padding 24px이에요.
- 폭이 좁거나 입력 중심인 화면에서는 16px까지 줄일 수 있어요.
- 주요 섹션 사이는 section-gap 48px을 사용해요.
- 카드 내부 padding은 24px, 큰 feature panel은 32\~48px을 사용해요.
- full-width color block은 화면 가장자리까지 닿을 수 있지만 내부 콘텐츠는 safe area와 screen padding을 지켜요.
- bottom CTA는 SafeArea 위에 배치하고 콘텐츠를 가리지 않도록 scroll padding을 확보해요.

## 6. Elevation & Depth

Curitalk은 기본적으로 flat system이에요.

| Level | 처리 | 사용 |
|---|---|---|
| 0 | 그림자와 테두리 없음 | Canvas, pastel color block |
| 1 | 1px hairline | 입력창, outline card, list divider |
| 2 | 약한 0 4px 16px black 6% | Floating menu, sheet 내부의 예외적 tile |
| 3 | Scrim + modal surface | Bottom sheet, dialog |

Color block 자체에는 그림자를 추가하지 않아요. focus와 pressed 상태는 border, fill, scale 변화로 표현해요.

## 7. Shapes

- rounded.md 12px: 입력창, 작은 list item
- rounded.lg 24px: 학습 카드, 대화 준비 패널, 문법 피드백
- rounded.xl 32px: hero panel, bottom sheet 상단
- rounded.pill 50px: 모든 text CTA와 chip
- rounded.full: 원형 icon button과 선택 indicator

큰 구조는 sturdy한 rounded block, 상호작용 요소는 pill로 구분해요. 사각형 CTA는 사용하지 않아요.

## 8. Components

### 8.1 Buttons

**Primary Button**

- Black background, White text
- button 또는 짧은 uppercase label-mono
- 최소 높이 48px, 좌우 padding 24px
- rounded.pill, shadow 없음
- pressed 시 0.98 scale 또는 짧은 opacity 변화

**Secondary Button**

- White background, Black text
- 1\~2px Black border
- Primary와 동일한 높이와 radius

**Text Button**

- 투명 배경, Black 또는 ink-secondary
- 최소 48px hit target

**Icon Button**

- 기본 44x44px
- surface-soft 또는 inverse surface 위의 translucent White
- rounded.full

### 8.2 Cards & Color Blocks

**Feature Card**

- Pastel block background
- rounded.lg
- 내부 padding 24\~32px
- 제목은 headline-md, metadata는 caption-mono

**Outline Card**

- Canvas background
- 1px hairline
- 낮은 우선순위 정보와 설정 항목

**Recent Conversation Card**

- 주제별 pastel block을 순환
- category는 White pill + caption-mono
- 제목은 headline-md, 미리보기는 body
- 그림자 없이 색상과 여백으로 구분

### 8.3 Conversation

- 사용자 메시지: inverse-canvas 배경 + inverse-ink
- AI 메시지: canvas 배경 + ink, 필요한 경우 1px hairline
- 대화 시작 질문: block-lilac-soft 또는 block-cream의 큰 panel
- typing/loading: 색상보다 motion과 짧은 상태 문구로 표현
- 말풍선 radius는 24\~32px이며 꼬리 모양은 사용하지 않아요.

### 8.4 Grammar Feedback

- 사용자 원문: block-lilac
- 수정 제안: block-cream
- Try: 레이블과 수정된 표현은 ink와 weight로 강조
- 이유 설명은 body-sm + ink-secondary
- 오류 단어는 색상만 쓰지 않고 underline이나 아이콘을 함께 사용

### 8.5 Inputs, Chips & Selection

**Text Input**

- Canvas background, 1px hairline
- rounded.md, 최소 높이 48px
- focus 시 2px Black border, glow 없음
- error 시 semantic-error border와 설명 텍스트

**Chip**

- White 또는 pastel parent와 대비되는 surface
- rounded.pill, caption-mono
- 선택 상태는 Black fill + White text

### 8.6 Navigation & Bottom Sheet

**Bottom Navigation**

- Canvas background
- 선택 항목은 Black circular 또는 pill surface
- 선택·비선택 모두 icon과 label을 함께 제공
- 높이 72px 이상이며 SafeArea를 포함

**Bottom Sheet**

- Canvas 또는 surface-subtle
- 상단 corner는 rounded.xl
- Scrim 45\~60%
- 선택 row는 24px 이상의 radius와 48px 이상의 touch target

## 9. Interaction & Accessibility

- 모든 터치 영역은 최소 48x48px이에요.
- text와 배경의 대비는 WCAG AA를 충족해야 해요.
- pressed feedback은 100\~150ms, 화면 전환은 200\~300ms를 기본으로 해요.
- Reduce Motion 설정에서는 scale과 반복 애니메이션을 줄여요.
- Dynamic Type 확대 시 display보다 body와 action의 가독성을 우선해요.
- Android와 iOS의 SafeArea, keyboard inset을 항상 반영해요.

## 10. Do & Don't

### Do

- Black Primary CTA를 화면의 가장 중요한 행동 하나에만 사용해요.
- 하나의 정보 묶음에는 하나의 pastel block을 충분히 크게 사용해요.
- 화면 사이에 White canvas를 남겨 color block이 의도적으로 보이게 해요.
- Inter의 크기와 weight, JetBrains Mono의 taxonomy 대비로 계층을 만들어요.
- 버튼과 선택 chip은 pill 형태를 유지해요.
- 대화와 문법 피드백에는 앱 전용 semantic color 역할을 사용해요.

### Don't

- 앱 전체를 Terracotta 또는 Sand surface로 덮지 않아요.
- 여러 pastel 색상을 하나의 카드 안에서 장식적으로 섞지 않아요.
- Color block에 gradient나 강한 shadow를 추가하지 않아요.
- Mono font를 문장형 본문이나 긴 설명에 사용하지 않아요.
- 화면별 Stitch HTML의 임시 theme map을 Flutter에 그대로 복사하지 않아요.
- 상태를 색상 하나로만 전달하지 않아요.

## 11. Flutter 적용 기준

- Material 3 ColorScheme에는 monochrome core와 semantic status를 연결해요.
- Pastel block, conversation, grammar feedback 색상은 ThemeExtension으로 분리해요.
- spacing, radius, size는 immutable token class로 관리해요.
- typography는 TextTheme에 매핑하고 Mono 역할은 별도 extension으로 제공해요.
- v1은 light theme만 구현하며 system dynamic color는 사용하지 않아요.
- 폰트는 앱 asset에 포함해 네트워크 상태와 관계없이 동일하게 렌더링해요.
- 화면 코드에는 raw Hex, 임의 spacing, 임의 radius를 직접 작성하지 않아요.

## 12. Known Gaps

- Pastel Hex 값은 Stitch PNG와 HTML에서 정규화한 값이며 향후 실제 기기 검수에서 미세 조정할 수 있어요.
- Stitch 화면에는 Convia 명칭과 Quicksand, Terracotta 중심 theme 같은 과거 생성 흔적이 남아 있어요. Flutter 구현에서는 이 문서의 Curitalk token을 우선해요.
- Dark theme은 v1 범위가 아니며 block-navy는 light flow 안의 제한적인 inverse panel이에요.
- 문법 피드백의 success/warning/error 세부 상태는 실제 Flutter 화면 구현 시 접근성 검증 후 확정해요.

---
name: tomatalk Interface System
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
    fontFamily: Freesentation
    fontSize: 48px
    fontWeight: '700'
    lineHeight: '1.0'
    letterSpacing: -1.44px
  display-lg:
    fontFamily: Freesentation
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.05'
    letterSpacing: 0
  headline-lg:
    fontFamily: Freesentation
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.15'
    letterSpacing: -0.32px
  headline-md:
    fontFamily: Freesentation
    fontSize: 26px
    fontWeight: '700'
    lineHeight: '1.25'
    letterSpacing: -0.26px
  body-lg:
    fontFamily: Freesentation
    fontSize: 20px
    fontWeight: '400'
    lineHeight: '1.4'
    letterSpacing: -0.14px
  body:
    fontFamily: Freesentation
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.45'
    letterSpacing: -0.14px
  body-sm:
    fontFamily: Freesentation
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.45'
    letterSpacing: 0
  button:
    fontFamily: Freesentation
    fontSize: 16px
    fontWeight: '700'
    lineHeight: '1.25'
    letterSpacing: 0
  label:
    fontFamily: Freesentation
    fontSize: 14px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: 0.35px
  caption:
    fontFamily: Freesentation
    fontSize: 12px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0
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
  typing: 900ms
---

## 모바일 내비게이션 v2 — 구현 결정 (2026-09-22, 2026-10-04 갱신)

- 하단 목적지는 홈·내 정보 두 개예요. 각 탭은 화면과 스크롤 위치를 유지해요.
- 홈은 언어 스낵 → 최근 대화 최대 2개 → `＋ 새 대화` 순서예요. 최근 대화는 파스텔 카드를 유지하고, 카드를 누르면 이어 말해요.
- 홈의 `오늘의 토마토` 제목은 16px 버튼 서체와 좌우 8px 여백을 사용하고 가운데 정렬해요. 제목은 클릭 대상이 아니고, 오른쪽 `전체 보기` 버튼은 표시하지 않아요.
- 움직이는 주간 주제 카드는 실제 카드 너비와 높이를 고정하고 문구를 가운데 배치해요. 표시 문구는 공백 기준 두 어절마다 줄바꿈하고 최대 세 줄로 표시해요. 원문과 접근성 이름에는 표시용 줄바꿈을 넣지 않아요.
- 전체 대화 화면은 간결한 행 목록과 상단 `＋`로 구성해요. 기존 API의 페이지 조회를 연결하고 하단 탭을 숨겨요.
- 홈과 전체 대화 화면의 새 대화 버튼은 동일한 방식 선택 시트를 열어요. 준비·대화 중에는 탭을 숨기고 복귀 시 출발 화면을 유지해요.
- 내 정보는 기존 계정·언어 설정을 독립 화면으로 제공해요. 계정 영역에는 제목과 이메일 없이 프로필 원과 한 줄 사용자 이름만 표시하고, 이름은 20px Bold로 원 높이 안에 맞춰요. 구독·앱 언어·학습 언어 제목과 바로 아래 콘텐츠 사이에는 동일한 16px 간격을 사용해요. 세 섹션의 콘텐츠 글자는 앱 언어 버튼 기준인 Freesentation 12px Medium(500)으로 맞춰요. iOS 구독 영역은 현재 플랜을 첫 글자만 대문자인 영문(`Free`, `Advance`, `Plus`)의 검은색 상태 칩으로 표시하고, 옆의 흰색 `더 보기` 칩으로 구독 상세 화면을 열어요. 영어 UI의 해당 칩은 `Show more`, 앱 언어 칩은 `Korean`과 `English`로 첫 글자만 대문자로 표시해요. 학습 언어는 `한국어 → 영어`와 `영어 → 한국어` 두 옵션만 앱 언어와 같은 내용 폭 칩으로 가로 배치해요. 영어 UI에서는 칩 폭을 위해 `KR → EN`과 `EN → KR`로 축약하고 확인 팝업에는 전체 언어 이름을 표시해요. 앱 언어·학습 언어 변경 확인 팝업의 영문 확인 버튼은 `CHANGE`로 표시해요. 좁은 화면이나 큰 글씨에서는 다음 줄로 넘어갈 수 있어요. 온보딩의 언어쌍 카드 구성은 유지해요. 로그아웃은 화면 하단에 옅은 회색 `로그 아웃` 텍스트 버튼으로 표시하고 배경이나 외곽선은 두지 않아요. 홈 헤더의 오른쪽에는 원형 프로필 아이콘 대신 현재 언어 쌍 배지를 표시해요.
- iOS 구독 화면 하단의 이용약관·개인정보처리방침 링크는 내 정보의 로그아웃과 같은 Freesentation 12px Medium, 옅은 회색 텍스트 버튼으로 표시해요. 링크 위의 월간 자동 갱신 안내 문단은 표시하지 않아요.
- 탭 라벨은 기본 UI 서체로 항상 표시하고, 2개 항목의 너비와 터치 영역을 동일하게 유지해요. 탭 사이에는 슬라이드 전환을 넣지 않아요.

## 1. 시스템 방향

tomatalk은 Figma 마케팅 시스템의 편집형 대비와 컬러 블록 문법을 모바일 학습 앱에 맞게 변형해요. 기본 화면은 흑백의 깨끗한 캔버스를 유지하고, 대화 주제·학습 피드백·최근 대화처럼 의미가 있는 콘텐츠 묶음에만 파스텔 컬러 블록을 사용해요.

이 시스템의 핵심은 **Warm Terracotta & Sand가 아니라 Monochrome Editorial + Pastel Color Blocks**예요. Terracotta는 일부 Stitch 화면의 아이콘이나 작은 강조 요소에만 제한적으로 등장하며, 앱의 주 배경이나 CTA 색상이 아니에요.

핵심 원칙은 다음과 같아요.

- Black과 White가 CTA, 본문, 내비게이션을 담당해요.
- Lime, Lilac, Cream, Mint 계열, Blue, Coral, Pink는 콘텐츠를 구분하는 큰 면으로 사용해요.
- 버튼은 pill, 주요 카드와 패널은 24px 이상의 큰 radius를 사용해요.
- 그림자와 gradient보다 색상 면, 여백, 테두리 굵기로 계층을 만들어요.
- Freesentation의 Regular 본문과 Bold 제목·CTA, Medium 보조 정보로 계층을 만들어요.

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

원본 마케팅 시스템은 mid-gray 텍스트를 거의 사용하지 않지만, tomatalk 모바일 앱은 긴 설명과 상태 정보가 많으므로 접근 가능한 보조 텍스트 역할을 허용해요. 중요한 학습 내용과 CTA는 항상 ink를 사용해요.

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

- **Freesentation**: 앱의 모든 텍스트에 쓰는 기본 폰트예요. Light(300), Regular(400), Medium(500), Bold(700) 네 파일을 번들해요.

본문은 Regular, 작은 보조 정보는 Medium, 제목과 CTA는 Bold를 사용해요. Light는 파일을 등록하지만 현재 텍스트 계층에는 배정하지 않아요. 화면별 Stitch HTML의 임시 font는 구현 기준에 포함하지 않아요.

### 4.2 사용 규칙

- display-xl: 온보딩과 핵심 empty state의 짧은 제목
- display-lg: Login hero처럼 짧고 브랜드감 있는 opener. Splash는 제공 이미지로 표시해요.
- headline-lg: 화면 제목과 큰 카드 제목
- headline-md: 대화 주제, 준비 카드, bottom sheet 제목
- body-lg: 온보딩 설명과 핵심 학습 문장
- body: 기본 대화·설명 문장
- body-sm: 카드 설명, 보조 정보
- button: 모든 text CTA
- label: 섹션 제목, category chip
- caption: metadata, 진행 단계, 작은 상태 레이블

섹션 제목 컴포넌트는 영문을 uppercase로 표시해요. Display는 두 줄에서 세 줄 이내로 유지하고, 큰 제목일수록 line height를 더 촘촘하게 사용해요.

| 계층 | 크기 / 굵기 | 주 용도 |
|---|---:|---|
| `displayXl` | 48 / Bold 700 | 가장 큰 강조 제목 |
| `displayLg` | 40 / Bold 700 | 로그인 대표 문구 |
| `headlineLg` | 32 / Bold 700 | 화면 제목, 큰 카드 제목 |
| `headlineMd` | 26 / Bold 700 | 카드·시트 제목 |
| `bodyLg` | 20 / Regular 400 | 큰 본문 |
| `body` | 18 / Regular 400 | 기본 설명·대화 문장 |
| `bodySm` | 16 / Regular 400 | 보조 설명, 입력·채팅 텍스트 |
| `button` | 16 / Bold 700 | 버튼·CTA |
| `label` | 14 / Bold 700 | 섹션·카테고리 레이블 |
| `caption` | 12 / Medium 500 | 메타데이터·작은 상태 표시 |

## 5. Layout & Spacing

- 기본 단위는 8px예요. 4px은 미세 정렬, 12px은 compact 내부 간격에만 사용해요.
- 일반 화면의 좌우 padding은 screen-padding 24px이에요.
- 폭이 좁거나 입력 중심인 화면에서는 16px까지 줄일 수 있어요.
- 주요 섹션 사이는 section-gap 48px을 사용해요.
- 카드 내부 padding은 24px, 큰 feature panel은 32\~48px을 사용해요.
- full-width color block은 화면 가장자리까지 닿을 수 있지만 내부 콘텐츠는 safe area와 screen padding을 지켜요.
- bottom CTA는 SafeArea 위에 배치하고 콘텐츠를 가리지 않도록 scroll padding을 확보해요.

## 6. Elevation & Depth

tomatalk은 기본적으로 flat system이에요.

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
- 유형은 제목 오른쪽 위의 White pill + caption-mono 배지에 `freechat` 또는 `roleplaying`으로 표시해요. 한국어·영어 UI에서 같은 문구를 사용해요.
- 제목은 왼쪽 headline-md이며 표시할 때 두 어절마다 줄바꿈하고 최대 세 줄로 제한해요. 원문과 접근성 이름은 유지해요. 잠긴 대화만 `읽기 전용` 상태를 보여줘요. 메시지 수·계속 대화하기 문구는 표시하지 않아요.
- 오른쪽 위 X를 제거하고, 왼쪽 스와이프로 오른쪽 `삭제` 텍스트 동작을 드러내요. 삭제는 기존 확인 팝업을 거쳐요.
- 그림자 없이 색상과 여백으로 구분

**Tomato Language Snacks (v2.6, 2026-09-20)**

- 디버그 빌드에서만 열람 수 왼쪽에 restart 아이콘 버튼과 한국어/영어 테스트용 리셋 툴팁을 표시해요. 모션·팝업 중 비활성화하며 release/profile 레이아웃에는 포함하지 않아요.
- Home의 최근 대화 위에 현재 열람 수/12와 토마토 바구니를 표시하며 "오늘의 언어" section label은 사용하지 않아요. 투명 PNG 바구니와 수정된 3입 이미지를 사용하고 별도 배경 없이 Home 배경 위에 표시해요. 텍스트·컨트롤은 onSurface 색상을 사용해요.
- 바구니를 누르면 토마토를 꺼내요. 토마토 3개를 각각 4입 먹으며 투명 PNG 5단계를 교체하고 360ms 눌림·반동을 재생해요. 이미지 영역은 220px 정사각형, 원본 캔버스 좌표는 유지해요.
- 꺼내기 모션은 400ms로, 바구니 위치의 작은 토마토가 중앙으로 이동하며 42%에서 100%로 커지고 살짝 반동을 줘요. 바구니는 먼저 페이드 아웃하고 토마토는 빠르게 나타나며, 고정 영역 안에서 transform·opacity만 바꿔 주변 레이아웃은 움직이지 않아요. 모션 감소 설정에서는 즉시 전환해요.
- 토마토 한 개를 완료한 팝업을 닫으면 바구니로 돌아가며 `tomato_basket_leave_2/1/0.png`로 남은 개수를 보여줘요. 다음 토마토는 사용자가 바구니를 다시 눌러 꺼내요. 총 9개 이미지는 미리 로딩해요.
- 터치 영역의 InkWell 물결·눌림 배경은 끄고 토마토 애니메이션만 재생해요. 키보드 포커스·툴팁은 유지하며 팝업 상단에는 페이지 번호 없이 닫기 버튼만 표시해요. Home의 일일 열람 수/12는 유지해요.
- 토마토 번호/3은 유지하고 토마토·바구니 아래의 진행 점·체크는 모두 표시하지 않아요. 전환 시 높이가 바뀌지 않게 같은 여백을 확보해요. 터치 도중과 콘텐츠 팝업이 열렸을 때 중복 입력을 막고, reduce motion에서는 토마토 움직임을 생략해요. 바구니 아이콘과 토마토 버튼에 툴팁·접근성 이름을 제공해요.
- 한입마다 지역별 표현은 lilac, 용법 차이는 blue, 동음이의어는 lime-soft 팝업을 열어요. 닫기 아이콘은 스크롤 영역 밖에 두고 본문만 스크롤해요. 마지막 입의 팝업 뒤에는 꼭지를 유지하고, 세 토마토 완료 후 팝업을 닫으면 빈 바구니·12/12와 소진·자정 충전 안내를 표시하고 터치를 비활성화해요. 현지 자정 이후 새 바구니로 교체하되, 열린 팝업·애니메이션은 종료 후 갱신해요.
- 지역별 표현은 넓은 화면에서 두 열, 작은 화면·큰 글자 설정에서는 세로 배치해요. 용법 차이·동음이의어는 표현별 설명과 예문을 세로로 표시해요.
- 표현은 headline-md, 설명·예문은 body-sm을 사용하며 내용을 잘라내지 않아요. 기존 5초 자동 전환·이전/다음 탐색은 Home에서 사용하지 않아요.
- 설명 언어는 앱 chrome과 분리하고 학습 대상 콘텐츠의 explanation_language를 따라요.

### 8.3 Conversation

- 사용자 메시지: inverse-canvas 배경 + inverse-ink
- AI 메시지: canvas 배경 + ink, 필요한 경우 1px hairline
- 대화 시작 질문: block-lilac-soft 또는 block-cream의 큰 panel
- typing/loading: 색상보다 motion과 짧은 상태 문구로 표현
- composer는 pill outline 안에 입력창과 원형 send action을 배치해요.
- 자연스러운 문장 상태는 check icon과 mono label을 함께 표시해요.
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

### 8.6 Source & Retry State

- 검색 출처 행은 제목, host, 외부 이동 icon을 함께 표시해요.
- 검색 품질 부족 상태는 searchRetry semantic surface 하나로 묶어요.
- 재시도 카드에는 주제 수정과 다른 아이디어 선택을 모두 제공해 막힌 흐름을 만들지 않아요.

### 8.7 Navigation & Bottom Sheet

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
- Freesentation의 크기와 Regular·Medium·Bold 굵기 대비로 계층을 만들어요.
- 버튼과 선택 chip은 pill 형태를 유지해요.
- 대화와 문법 피드백에는 앱 전용 semantic color 역할을 사용해요.

### Don't

- 앱 전체를 Terracotta 또는 Sand surface로 덮지 않아요.
- 여러 pastel 색상을 하나의 카드 안에서 장식적으로 섞지 않아요.
- Color block에 gradient나 강한 shadow를 추가하지 않아요.
- 작은 글씨에는 Light(300)를 사용하지 않아요.
- 화면별 Stitch HTML의 임시 theme map을 Flutter에 그대로 복사하지 않아요.
- 상태를 색상 하나로만 전달하지 않아요.

## 11. Flutter 적용 기준

- Material 3 ColorScheme에는 monochrome core와 semantic status를 연결해요.
- Pastel block, conversation, grammar feedback 색상은 ThemeExtension으로 분리해요.
- spacing, radius, size는 immutable token class로 관리해요.
- typography는 `AppTypography` 토큰과 기본 `ThemeData.fontFamily`로 적용해요.
- v1은 light theme만 구현하며 system dynamic color는 사용하지 않아요.
- 폰트는 앱 asset에 포함해 네트워크 상태와 관계없이 동일하게 렌더링해요.
- 화면 코드에는 raw Hex, 임의 spacing, 임의 radius를 직접 작성하지 않아요.

## 12. Known Gaps

- Pastel Hex 값은 Stitch PNG와 HTML에서 정규화한 값이며 향후 실제 기기 검수에서 미세 조정할 수 있어요.
- Stitch 화면에는 이전 서비스 명칭과 Quicksand, Terracotta 중심 theme 같은 과거 생성 흔적이 남아 있어요. Flutter 구현에서는 이 문서의 tomatalk token을 우선해요.
- Dark theme은 v1 범위가 아니며 block-navy는 light flow 안의 제한적인 inverse panel이에요.
- 문법 피드백은 일반 AI 말풍선과 구분되도록 `grammarSuggestionSurface`를 사용하고, 설명 텍스트는 gray 계열 보조 텍스트를 유지해요. 긴 교정/설명은 기본 접힘 상태에서 1줄로 표시하고 `SHOW MORE`/`SHOW LESS`로 확장해요.

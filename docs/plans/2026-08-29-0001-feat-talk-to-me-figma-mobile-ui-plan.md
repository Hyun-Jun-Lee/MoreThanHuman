---
title: "Talk to Me Figma Mobile UI - Plan"
type: feat
date: 2026-08-29
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: user-request
execution: figma-mcp
---

# Talk to Me Figma Mobile UI - Plan

## Goal Capsule

- **Objective:** Flutter 모바일 앱의 현재 UI 체계를 Figma의 편집 가능한 디자인 시스템과 대표 화면으로 옮긴다.
- **Means:** 기존 코드의 tokens, shared widgets, 주요 screens를 기준으로 Figma page 구조, variables/styles, component variants, 상태별 mobile screens를 생성한다.
- **Authority:** Figma 산출물은 디자이너 협업용 기준안이다. Flutter 코드의 런타임 동작, API 계약, product flow는 이 작업에서 변경하지 않는다.
- **Stop conditions:** `Button`, `Text Field`, `Selection Chip`, `Chat Bubble`, `Chat Composer`, `Bottom Navigation` 컴포넌트와 `Home`, `Topic Input`, `Topic Prep`, `Conversation` 상태 화면이 Figma에서 디자이너가 직접 편집 가능한 구조로 정리된다.

---

## Product Contract

### Requirements

- R1. Figma 파일은 디자이너가 빠르게 탐색할 수 있도록 `Cover`, `Foundations`, `Components`, `Screens` page 또는 section 구조를 가진다.
- R2. 색상, spacing, radius, size, typography는 Flutter token 이름과 대응되는 Figma variables/styles로 정리한다.
- R3. sans typography는 Figma에서 사용 가능한 fallback font를 쓰되, 코드 기준 font intent를 문서화된 layer naming으로 남긴다.
- R4. `Button` component는 primary, outline, text style과 default, disabled, loading state를 variant로 제공한다.
- R5. `Text Field` component는 default, focused, error, disabled state를 variant로 제공한다.
- R6. `Selection Chip` component는 selected true/false 상태를 variant로 제공한다.
- R7. `Chat Bubble` component는 user/assistant speaker와 normal/feedback 목적을 variant로 제공한다.
- R8. `Chat Composer` component는 idle, recording, sending, disabled state를 variant로 제공한다.
- R9. `Bottom Navigation` component는 Home, Chat, History, Profile selected state를 variant 또는 clearly editable instances로 제공한다.
- R10. 대표 화면은 최소 `Home`, `Topic Input`, `Topic Prep`, `Conversation`을 포함한다.
- R11. 협업에 필요한 상태 화면은 최소 `Home / Empty`, `Home / With Recent Conversations`, `Topic Prep / Loading`, `Topic Prep / Ready`, `Conversation / Idle`, `Conversation / Recording`, `Conversation / Feedback Visible`을 포함한다.
- R12. Flow/Notes 정리, prototype 연결, 별도 설명용 흐름 화살표는 이번 범위에서 제외한다.

### Target Figma File

- **Service name:** `talk to me`
- **File:** `talk-to-me---mobile-ui`
- **URL:** `https://www.figma.com/design/7Lvbp0mXnmehEfpfDltl3P/talk-to-me---mobile-ui`
- **Current MCP account requirement:** `TalkToMe` Professional plan, Full seat

### Source of Truth

- Flutter tokens:
  - `mobile/lib/app/theme/tokens/app_palette.dart`
  - `mobile/lib/app/theme/tokens/app_spacing.dart`
  - `mobile/lib/app/theme/tokens/app_radius.dart`
  - `mobile/lib/app/theme/tokens/app_size.dart`
  - `mobile/lib/app/theme/app_typography.dart`
  - `mobile/lib/app/theme/app_semantic_colors.dart`
- Flutter component references:
  - `mobile/lib/core/widgets/app_primary_button.dart`
  - `mobile/lib/core/widgets/app_text_field.dart`
  - `mobile/lib/core/widgets/app_selection_chip.dart`
  - `mobile/lib/core/widgets/app_color_block_card.dart`
  - `mobile/lib/features/conversation/presentation/widgets/chat_bubble.dart`
  - `mobile/lib/features/conversation/presentation/widgets/chat_composer.dart`
  - `mobile/lib/features/home/presentation/widgets/recent_conversation_card.dart`
  - `mobile/lib/features/home/presentation/widgets/main_navigation_bar.dart`
- Flutter screen references:
  - `mobile/lib/features/home/presentation/home_screen.dart`
  - `mobile/lib/features/topic_input/presentation/topic_input_screen.dart`
  - `mobile/lib/features/topic_prep/presentation/topic_prep_screen.dart`
  - `mobile/lib/features/conversation/presentation/conversation_screen.dart`

---

## Design Plan

### Page and Section Structure

- `Cover`
  - Product title: `talk to me`
  - Scope label: `Mobile UI Draft`
  - Small metadata: generated from Flutter source, date, target viewport
- `Foundations`
  - Color primitives and semantic colors
  - Typography styles
  - Spacing, radius, and size scales
  - Component anatomy references only when needed to make tokens understandable
- `Components`
  - Editable component sets for the core Flutter widgets
  - Variant naming that mirrors product state rather than implementation internals
- `Screens`
  - Mobile frames built from component instances and shared styles
  - State frames grouped by feature and screen name

If Figma MCP cannot create multiple pages reliably, use one page with four large top-level frames named `Cover / talk to me`, `Foundations / talk to me`, `Components / talk to me`, and `Screens / talk to me`.

### Token and Style Naming

Use slash-separated names so designers can scan the library and developers can map values back to Flutter tokens.

```text
color/primitive/black
color/primitive/white
color/surface/canvas
color/surface/soft
color/surface/subtle
color/text/primary
color/text/secondary
color/border/hairline
color/block/lime
color/block/lilac
color/block/cream
color/block/blue
color/block/coral
color/feedback/success
color/feedback/warning
color/feedback/error

spacing/xxs
spacing/xs
spacing/sm
spacing/md
spacing/lg
spacing/xl
spacing/xxl
spacing/screen-padding
spacing/section-gap

radius/xs
radius/sm
radius/md
radius/lg
radius/xl
radius/pill
radius/full

size/touch-target
size/icon
size/icon-button
size/input-min-height
size/bottom-navigation-height

typography/display/xl
typography/display/lg
typography/headline/lg
typography/headline/md
typography/body/lg
typography/body/default
typography/body/sm
typography/button/default
typography/label/mono
typography/caption/mono
```

Typography mapping:

- Flutter `Pretendard` intent maps to Figma `Inter` fallback unless `Pretendard` is available in the file.
- Flutter `Newsreader` display styles keep `Newsreader` when available.
- Flutter `JetBrains Mono` label/caption styles keep `JetBrains Mono` when available.
- Flutter negative letter spacing should be approximated only if Figma font rendering remains readable; do not force clipped or cramped text.

### Component Variant Contract

#### Button

- **Component set:** `Button`
- **Properties:** `style`, `state`, `icon`
- **Variants:**
  - `style=primary`, `state=default`
  - `style=primary`, `state=disabled`
  - `style=primary`, `state=loading`
  - `style=outline`, `state=default`
  - `style=outline`, `state=disabled`
  - `style=text`, `state=default`
  - `style=text`, `state=disabled`
- **Anatomy:** container, optional leading icon, label, optional loading indicator
- **Code reference:** `AppPrimaryButton`, app button themes

#### Text Field

- **Component set:** `Text Field`
- **Properties:** `state`, `leading`, `trailing`
- **Variants:**
  - `state=default`
  - `state=focused`
  - `state=error`
  - `state=disabled`
- **Anatomy:** input container, placeholder/value text, optional helper or error text, optional icon affordances
- **Code reference:** `AppTextField`, input decoration theme

#### Selection Chip

- **Component set:** `Selection Chip`
- **Properties:** `selected`
- **Variants:**
  - `selected=false`
  - `selected=true`
- **Anatomy:** pill container, uppercase label, optional selected treatment
- **Code reference:** `AppSelectionChip`

#### Chat Bubble

- **Component set:** `Chat Bubble`
- **Properties:** `speaker`, `purpose`
- **Variants:**
  - `speaker=user`, `purpose=normal`
  - `speaker=assistant`, `purpose=normal`
  - `speaker=assistant`, `purpose=feedback`
- **Anatomy:** rounded message surface, message text, optional feedback badge or correction block
- **Code reference:** `ChatBubble`, grammar/readability feedback widgets

#### Chat Composer

- **Component set:** `Chat Composer`
- **Properties:** `state`
- **Variants:**
  - `state=idle`
  - `state=recording`
  - `state=sending`
  - `state=disabled`
- **Anatomy:** rounded input shell, mic control, status or draft text, cancel action, send action
- **Code reference:** `ChatComposer`

#### Bottom Navigation

- **Component set:** `Bottom Navigation`
- **Properties:** `selected`
- **Variants:**
  - `selected=home`
  - `selected=chat`
  - `selected=history`
  - `selected=profile`
- **Anatomy:** fixed-height navigation container, four destinations, icon and label treatment
- **Code reference:** `MainNavigationBar`

---

## Screen Plan

### Mobile Frame Baseline

- Use `390 x 844` as the default mobile frame size.
- Use `spacing/screen-padding` for horizontal content padding.
- Use `size/bottom-navigation-height` for Home shell navigation.
- Keep status bar and device chrome minimal unless needed for visual alignment.

### Home

- `Home / Empty`
  - Header with `talk to me` identity and profile affordance
  - Primary start conversation action
  - Empty recent conversation state
  - Bottom navigation with `selected=home`
- `Home / With Recent Conversations`
  - Same shell as empty state
  - Recent conversation cards using color block treatments
  - At least two example cards with title, preview, and timestamp-like metadata if available in current UI

### Topic Input

- `Topic Input / Default`
  - Screen heading and short prompt copy
  - Topic text field
  - Primary continue button
  - Optional suggested topic chips if represented in current Flutter UI
- `Topic Input / Filled`
  - Text field with example topic
  - Enabled continue button

### Topic Prep

- `Topic Prep / Loading`
  - Loading state that preserves layout intent
  - Search/prep progress copy using current app tone
- `Topic Prep / Ready`
  - Prepared topic summary card
  - Key vocabulary or talking points if present in current UI
  - Source link tiles if present
  - Primary start conversation action

### Conversation

- `Conversation / Idle`
  - Assistant greeting bubble
  - User/assistant message examples
  - Chat composer `state=idle`
- `Conversation / Recording`
  - Same conversation structure
  - Chat composer `state=recording`
  - Recording status treatment
- `Conversation / Feedback Visible`
  - User message and assistant reply
  - Feedback or correction card/bubble visible below the relevant turn
  - Chat composer available at bottom

---

## Execution Units

### U1. Validate Figma Access and Existing State

- Confirm MCP `whoami` shows `TalkToMe`, `tier=pro`, `seat=Full`.
- Read the target Figma file metadata.
- Locate existing `Cover / talk to me` and `Foundations / talk to me` frames if present.
- Reuse existing variables and styles when their names and values match the Flutter source.
- Do not create duplicate token collections or duplicate top-level frames unless the previous attempt is unusable.

### U2. Normalize Foundations

- Ensure color, spacing, radius, size, and typography variables/styles follow the naming contract.
- Patch missing or stale token values from the Flutter source.
- Fix clipped labels, inconsistent text heights, and non-editable token samples.
- Confirm Foundations can be inspected visually through a Figma screenshot.

### U3. Build Component Sets

- Create `Components / talk to me` if missing.
- Build component sets in this order:
  1. `Button`
  2. `Text Field`
  3. `Selection Chip`
  4. `Chat Bubble`
  5. `Chat Composer`
  6. `Bottom Navigation`
- Use auto layout for every component where Flutter layout behavior depends on padding, gap, or intrinsic text size.
- Use component properties and variants rather than detached repeated frames wherever Figma MCP supports it reliably.
- After each component set, return and record node IDs in the local Figma state ledger.

### U4. Build Screen Frames

- Create `Screens / talk to me` if missing.
- Build screens using component instances when available.
- Group frames by feature in this order:
  1. `Home`
  2. `Topic Input`
  3. `Topic Prep`
  4. `Conversation`
- Include the required state frames from R11.
- Keep all screen text editable.
- Avoid prototype connections, flow arrows, and separate notes sections.

### U5. Visual QA and Cleanup

- Capture screenshots of `Components / talk to me` and `Screens / talk to me`.
- Check for overlapping text, clipped text, blank frames, detached duplicate components, and inconsistent spacing.
- Rename ambiguous layers to product-readable names.
- Ensure designers can duplicate a screen frame and modify text/components without breaking the layout.
- Update the local Figma state ledger with created frame, component, and component set IDs.

---

## Verification Plan

| Area | Evidence |
|---|---|
| Figma access | `whoami` returns `TalkToMe` with `Full` seat on `pro` tier |
| Page structure | `Cover`, `Foundations`, `Components`, `Screens` exist as pages or top-level frames |
| Tokens | Figma variables/styles match Flutter palette, spacing, radius, size, and typography intent |
| Components | Required component sets and variants exist and are editable |
| Screens | Required representative and state screens exist at mobile size |
| Layout quality | Screenshot review shows no clipped text, incoherent overlap, or blank areas |
| Collaboration readiness | Component names, variant properties, and screen names are understandable without a separate notes/flow page |

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Figma MCP duplicates existing frames from prior attempts | First inspect metadata and reuse known frame/style IDs from the state ledger |
| Font mismatch between Flutter and Figma | Use Inter fallback for Pretendard intent and keep style names mapped to Flutter typography |
| Variant creation fails or is unstable through MCP | Fall back to clearly named components in grouped frames, then combine into variants manually where possible |
| Text clips after font/style assignment | Use explicit text box sizing and screenshot QA after Foundations, Components, and Screens |
| Screen frames drift from actual Flutter UI | Re-read the Flutter source widgets before generating each screen group |
| Designer expects prototype flow documentation | Keep scope explicit: no Flow/Notes, no prototype wiring in this plan |

## Definition of Done

- Figma file contains a clean `talk to me` mobile UI structure with Foundations, Components, and Screens.
- Required component sets exist with the specified variants.
- Required representative and state screens are built from reusable styles/components.
- The file is ready for a designer with Full seat and edit permission to duplicate, adjust, and continue the mobile UI work.
- No Flow/Notes section or prototype-flow deliverable is created.

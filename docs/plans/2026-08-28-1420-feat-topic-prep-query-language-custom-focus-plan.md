---
title: "Topic Prep Query Language and Custom Focus - Plan"
type: feat
date: 2026-08-28
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: user-request
execution: code
---

# Topic Prep Query Language and Custom Focus - Plan

## Goal Capsule

- **Objective:** Topic Prep의 설명은 사용자가 입력한 주제의 언어를 우선 사용하고, 대화 방향은 세 가지 추천과 직접 입력을 함께 제공한다.
- **Means:** backend가 표시 언어를 결정해 요약·방향 설명을 생성하고, custom focus용 질문 생성 API와 Flutter 선택 흐름을 추가한다.
- **Authority:** 이 계획은 자유 대화 Topic Prep의 준비 카드와 첫 질문 handoff만 다룬다. 실제 대화의 학습 대상 언어 계약은 바꾸지 않는다.
- **Stop conditions:** 한국어·영어 입력에서 설명 언어와 추천/직접 입력 흐름이 각각 검증되고, 첫 질문과 실제 대화가 항상 학습 대상 언어를 유지하면 완료한다.

---

## Product Contract

### Requirements

- R1. Topic Prep의 `summary`, 추천 방향의 `title`과 `description`은 입력 주제 언어를 우선 사용한다.
- R2. 입력 언어가 명확하지 않으면 해당 사용자의 native language를 표시 언어로 사용한다.
- R3. 추천 방향의 `first_questions`와 이후 실제 자유 대화의 assistant 응답은 target language를 유지한다.
- R4. 기존 화면 제목 `대화 방향 고르기`/`Choose a direction`은 각각 `어떤 주제가 좋으세요?`/`What would you like to talk about?`으로 바꾼다.
- R5. 준비 결과는 고정 추천 방향 세 개를 제공한다. 각 방향에는 target language의 첫 질문 세 개가 있다.
- R6. 사용자는 추천 세 개 중 하나를 선택하거나 원하는 대화 방향을 직접 입력할 수 있다.
- R7. 직접 입력 필드의 한국어 placeholder는 정확히 `마음에 드는 주제가 없으면 직접 입력해보세요`이다. 영어도 같은 의미를 제공한다.
- R8. 직접 입력 후 system locale과 무관하게 영어 CTA `Submit`을 누르면 입력 방향에 맞는 target-language 첫 질문 세 개를 생성해 보여 준다.
- R9. 직접 입력은 주제가 아니라 이미 검색·요약된 주제에 대해 어떤 관점으로 이야기할지 나타내는 focus다. 원래 topic과 출처는 유지한다.
- R10. 빈 값, 과도하게 긴 값, 요청 실패, 질문 생성 실패는 두 언어 UI에서 재시도 가능한 안내와 함께 처리한다.
- R11. 서버가 받은 `custom_focus`는 다음 free chat 시작 요청에도 함께 전달되어 첫 assistant turn의 대화 의도를 보존한다.
- R12. 준비가 완료된 Topic Prep에서 사용자는 현재 주제의 추천 대화 방향 세 개를 다시 생성할 수 있다. 주제 summary와 출처는 화면에서 유지하고, 새 방향과 각 first question 세 개만 교체한다.

### Language Ownership

| 콘텐츠 | 소유자 | 선택 규칙 | 예시 |
|---|---|---|---|
| 화면 제목, placeholder, 버튼, 오류 | Flutter `AppCopy` | system locale (`ko`, 그 외 `en`) | `어떤 주제가 좋으세요?` |
| 주제 요약 | Topic Prep backend | input language, 모호하면 native language | `리센느` + Korean native -> Korean summary |
| 추천 방향 title/description | Topic Prep backend | input language, 모호하면 native language | Korean topic -> Korean direction explanation |
| 추천/직접 입력의 first questions | Topic Prep backend | target language | Korean topic + English target -> English questions |
| 실제 자유 대화 | conversation backend | target language | focus가 Korean이어도 English practice 유지 |

### Display Language Resolver

`display_language`는 요청마다 backend에서 하나만 결정하고, summary와 방향 설명 생성에 함께 넣는다.

1. Hangul 비중이 분명하면 `ko`를 선택한다.
2. Latin 문자 기반의 단어·문장이 분명하면 `en`을 선택한다.
3. 레거시 Chinese 지원을 위해 Han 문자가 분명하면 `zh`를 선택한다.
4. 숫자·URL·emoji만 있는 입력, 스크립트가 섞였지만 우세하지 않은 입력, 단독 로마자 고유명사처럼 판별할 근거가 부족한 입력은 native language로 fallback한다.
5. native language가 지원하지 않는 값이면 기존 language-context의 결정적 fallback을 사용한다. 이 계획의 `ko`/`en` UI 범위에서는 English가 최종 fallback이다.

이 resolver는 입력 문장을 번역하지 않는다. `display_language`는 설명용이고, `target_language`는 질문과 대화용이라는 두 값이 동시에 존재한다.

### Key Flows

#### F1. 한국어 입력, 영어 학습

- 사용자는 `리센느`를 입력하고 target language가 English다.
- 서버는 `display_language=ko`로 Korean summary와 Korean 추천 방향 설명 세 개를 만든다.
- 각 방향의 first questions와 대화 시작 후 assistant response는 English다.

#### F2. 영어 입력, 한국어 학습

- 사용자는 영어 topic을 입력하고 target language가 Korean이다.
- 서버는 English summary와 English 추천 방향 설명 세 개를 만든다.
- first questions 및 실제 대화는 Korean으로 진행한다.

#### F3. 모호한 입력

- 사용자가 `2026`, `RESCENE`, URL 또는 emoji처럼 언어를 확정할 수 없는 값을 입력한다.
- Korean native user는 Korean 설명, English native user는 English 설명을 본다.
- target language 질문과 대화는 독립적으로 유지된다.

#### F4. 추천 방향 선택

- 사용자는 세 추천 중 하나를 누르고 target-language first question 세 개 중 하나를 선택한다.
- 기존 conversation start payload는 선택 방향과 질문을 전달한다.

#### F5. 직접 입력 방향

- 사용자는 placeholder가 있는 입력 필드에 `멤버들의 음악적 영향에 대해 이야기하고 싶어요` 또는 `I want to discuss their musical influences`를 입력한다.
- 영어 고정 CTA `Submit`은 custom-focus 질문 생성 요청을 보낸다.
- 응답 전에는 disabled/loading 상태를 보이고, 성공하면 해당 focus의 target-language 질문 세 개로 선택 UI를 대체하거나 이어서 표시한다.
- 질문을 고르면 conversation start가 원래 topic, 선택 질문, `custom_focus`를 전달한다.

#### F6. 추천 대화 방향 재생성

- 사용자는 추천 방향 영역의 영어 고정 CTA `Show different directions`를 누른다.
- 서버는 같은 topic과 profile language context로, 현재 화면의 summary·sources를 바꾸지 않는 새 추천 방향 세 개와 각 target-language first question 세 개를 생성한다.
- 요청 중 action은 disabled 상태가 되고, 성공하면 기존 추천 선택과 질문 선택을 해제한 뒤 새 세 방향으로 교체한다.
- 실패하면 기존 추천 결과는 남겨 두고 locale별 안내와 재시도 action을 표시한다. 직접 입력 focus 및 이미 생성된 custom 질문은 유지한다.

### Copy Contract

| Key | Korean | English |
|---|---|---|
| direction heading | 어떤 주제가 좋으세요? | What would you like to talk about? |
| custom focus placeholder | 마음에 드는 주제가 없으면 직접 입력해보세요 | If none of these feel right, enter your own. |
| custom focus submit | Submit | Submit |
| custom focus field label | 직접 입력하는 대화 방향 | Your own conversation focus |
| generating questions | 질문을 준비하는 중... | Preparing questions... |
| custom question failure | 원하는 방향의 질문을 준비하지 못했어요. 다시 시도해 주세요. | We could not prepare questions for that focus. Please try again. |
| custom focus empty validation | 대화 방향을 입력해 주세요. | Enter a conversation focus. |
| regenerate directions | Show different directions | Show different directions |
| regenerate directions loading | 새로운 대화 방향을 준비하는 중... | Preparing new directions... |
| regenerate directions failure | 새로운 대화 방향을 준비하지 못했어요. 다시 시도해 주세요. | We could not prepare new directions. Please try again. |

### Scope Boundaries

- **In scope:** display-language 판단, Topic Prep 카드의 3개 추천, custom focus 질문 생성·handoff, 한국어/영어 UI copy, API·mobile 테스트와 문서.
- **Out of scope:** AI 생성 결과의 사후 번역, 사용자별 UI language 설정, roleplay 흐름, 기존 conversation 전체를 native language로 전환, Chinese UI chrome 추가.
- **Deferred:** 사용자가 설명 언어를 직접 선택하는 preference, custom focus 저장/재사용, 추천 방향 수를 개인화하는 ranking.

---

## Technical Plan

### Architecture Decisions

- KTD1. **표시 언어는 backend가 결정한다.** Flutter가 서버 생성 요약을 재판별하거나 번역하지 않는다. input/native/target context를 이미 받는 `search` service가 resolver를 소유한다.
- KTD2. **질문 생성은 별도 API로 만든다.** custom focus는 client-side 프롬프트 조합이 아니라 서버 검증·LLM 계약을 거친 `POST /api/search/topic-prep/custom-questions/`로 생성한다.
- KTD3. **추천 방향 enum에 CUSTOM을 추가하지 않는다.** 기존 고정 enum은 세 추천에만 쓴다. 직접 입력은 nullable `custom_focus`로 표현해 저장·분석·legacy direction 처리와 구분한다.
- KTD4. **custom focus는 원문으로 보존한다.** 사용자가 Korean/English로 적은 focus는 바꾸지 않고, 질문 프롬프트에 원문과 target language를 함께 준다. 설명 language와 focus language가 달라도 질문은 target language다.
- KTD5. **기본 추천은 정확히 세 개다.** schema/model의 `directions` 수와 prompt contract를 4에서 3으로 함께 변경한다. `casual_chat`, `debate`, `explanation_practice`를 유지하고 `interview_qa`를 제거한다. 직접 입력 focus가 interview 형식의 필요도 받는다.
- KTD6. **추천 방향 재생성은 directions-only API로 분리한다.** 새 요청은 현재 topic과 이전 direction의 title/description을 보내고, backend가 같은 language contract로 새로운 세 방향만 생성한다. summary·sources는 request/response에 포함하지 않아 화면의 기존 검증 결과를 보존한다.

### API Contract

`POST /api/search/topic-prep/custom-questions/`를 인증된 search router에 추가한다.

```json
{
  "topic": "리센느",
  "custom_focus": "멤버들의 음악적 영향에 대해 이야기하고 싶어요"
}
```

성공 응답 `data`:

```json
{
  "custom_focus": "멤버들의 음악적 영향에 대해 이야기하고 싶어요",
  "first_questions": [
    "Which musical influences would you like to start with?",
    "How do you think those influences shape the group's sound?",
    "Is there a song where you can hear that influence clearly?"
  ]
}
```

서버는 기존 topic-prep과 동일하게 topic을 재검색·품질 검증하고, profile의 `native_language`/`target_language`를 사용한다. response는 `first_questions`를 정확히 세 개로 제한한다. `custom_focus`는 trim한 원문을 echo한다.

자유 대화 시작 contract에는 nullable `custom_focus`를 추가한다. 기존 `conversation_direction` 선택 흐름은 유지한다. custom flow에서는 `custom_focus`가 존재하고 `conversation_direction`은 보내지 않으며, backend first-turn prompt가 해당 focus와 target language를 사용한다.

`POST /api/search/topic-prep/directions/`를 추가한다. 요청에는 `topic`과 현재 화면에 보인 `previous_directions`(각 type, title, description)를 보낸다. 서버는 topic을 다시 검증해 신뢰 가능한 context를 구성하고, 이전 제목·설명과 겹치지 않는 direction 세 개와 각 target-language first question 세 개만 반환한다. UI는 이 응답으로 direction 영역만 교체하며 summary와 sources를 재사용한다.

### Work Breakdown

#### U1. 입력 언어 우선 요약과 3개 추천

**Files**

- `backend/domains/search/service.py`
- `backend/domains/search/schemas.py`
- `backend/domains/search/router.py` (필요한 type/route 연결만)
- `backend/tests/domains/search/test_topic_prep_router.py`
- `backend/tests/domains/search/test_topic_prep_service.py` 또는 현행 service test 위치

**Changes**

1. pure helper로 `resolve_topic_display_language(topic, native_language)`를 만들고 script evidence와 fallback 결과를 테스트한다.
2. `_build_topic_prep_system_prompt`에 display/target language 역할을 분리해 주입한다. summary와 direction title/description은 display language, first questions는 target language임을 구조화된 JSON contract에 명시한다.
3. directions schema의 cardinality를 4에서 3으로 바꾸고 prompt의 “exactly four”를 “exactly three”으로 바꾼다.
4. input Korean/English, ambiguous input native fallback, target language와 설명 language가 다른 조합을 서비스·router 테스트로 고정한다.

#### U2. Custom focus 질문과 conversation handoff

**Files**

- `backend/domains/search/schemas.py`
- `backend/domains/search/router.py`
- `backend/domains/search/service.py`
- `backend/domains/conversation/schemas.py`
- `backend/domains/conversation/router.py`
- `backend/domains/conversation/service.py`
- `backend/tests/domains/search/test_topic_prep_router.py`
- `backend/tests/domains/conversation/test_topic_prep_handoff.py`

**Changes**

1. request/response schema와 route를 추가하고, empty/whitespace/length validation을 명시한다.
2. custom-focus prompt는 original topic, verified topic context, raw focus, native/display context, target language를 받는다. 설명을 새로 만들지 않고 first questions 세 개만 생성한다.
3. free-chat start request와 prompt context에 optional `custom_focus`를 추가한다. custom focus가 있으면 고정 direction label보다 custom focus를 우선한다.
4. directions-only request/response schema와 route를 추가한다. 이전 방향은 중복 회피 힌트로만 사용하고, 새로운 정확히 세 direction과 질문 세 개를 반환한다.
5. fixed direction legacy flow, custom flow, directions regeneration, invalid custom focus, provider malformed answer의 실패 경로를 테스트한다.

#### U3. Flutter data, domain, application 계층

**Files**

- `mobile/lib/features/topic_prep/domain/topic_prep_result.dart`
- `mobile/lib/features/topic_prep/data/topic_prep_repository.dart`
- `mobile/lib/features/topic_prep/application/topic_prep_controller.dart`
- `mobile/lib/features/conversation/domain/` 및 data/start request를 소유하는 파일
- 대응하는 `mobile/test/features/topic_prep/` 및 `mobile/test/features/conversation/` 테스트

**Changes**

1. direction parsing validation을 정확히 3개로 갱신하고 고정 enum 중 제거할 방향에 맞춰 model/fixture를 고친다.
2. `CustomFocusQuestions` value model, repository API, loading/error/success controller state를 추가한다. submit 중복을 막고 같은 focus의 최신 요청만 화면에 반영한다.
3. conversation start command에 optional `customFocus`를 추가한다. 추천 선택은 기존 `conversationDirection`, custom 선택은 `customFocus`를 전달한다.
4. `TopicPrepDirections` regeneration value/model과 repository/controller action을 추가한다. 요청 중 중복 실행을 막고, 성공 시 direction selection만 초기화한다.
5. target language 질문, raw custom focus, 새 direction 응답의 summary/source 불변을 보존하는 repository/controller/widget tests를 추가한다.

#### U4. Flutter Topic Prep UI와 양언어 copy

**Files**

- `mobile/lib/app/copy/app_copy.dart` 및 관련 copy test
- `mobile/lib/features/topic_prep/presentation/topic_prep_screen.dart`
- 필요 시 `mobile/lib/features/topic_prep/presentation/widgets/`의 신규 재사용 input widget
- `mobile/test/features/topic_prep/presentation/topic_prep_screen_test.dart`

**Changes**

1. heading과 custom-focus copy key를 `AppCopy`에 ko/en으로 추가한다. 제목은 위 Copy Contract를 정확히 사용한다.
2. 추천 세 개는 기존 선택 카드 패턴을 유지한다. 그 아래에 accessible label, text field, 제출 CTA를 둔다.
3. empty validation, loading disabled state, error/retry, keyboard submit, focus disposal을 구현한다.
4. custom 질문이 준비되면 선택 가능한 세 질문과 현재 focus를 표시하고, 질문 선택 후 start flow로 보낸다.
5. 추천 영역에 regenerate action을 두고, loading, 실패 시 기존 card 유지, 성공 시 새 card·selection reset 상태를 구현한다.
6. English/ Korean system locale에서 copy, three recommended cards, direct input submit, directions regeneration failure/retry와 handoff payload를 widget tests로 검증한다.

#### U5. Contracts and Documentation

**Files**

- `docs/DSL.md`
- `README.md`
- `mobile/README.md`
- `.agent/architecture.md` (실제 ownership/flow가 바뀌면)

**Changes**

1. Topic Prep response의 three-directions rule, display-language vs target-language responsibility, custom-questions API를 DSL에 기록한다.
2. API usage/example과 authentication/validation을 README에 동기화한다.
3. mobile README에 custom focus UX와 system chrome/native/topic/target language 경계를 보완한다.
4. 구현 완료 시 coordination changelog와 STATE를 업데이트한다.

---

## Verification Plan

| Area | Evidence |
|---|---|
| Display language | `리센느` -> Korean summary/descriptions, English topic -> English summary/descriptions, ambiguous `2026` -> native-language fallback |
| Target language isolation | Korean description + English target returns English questions and starts English conversation; inverse pair also passes |
| Three recommendations | schema parsing, provider output handling, Flutter rendering 모두 3개를 요구 |
| Custom focus API | request validation, exactly three target-language questions, malformed LLM payload recovery |
| Direction regeneration | 이전 방향과 겹치지 않는 세 새 추천, summary/source 화면 상태 유지, loading 중 중복 요청 방지, 실패 시 기존 추천 유지 |
| Handoff | recommended path sends direction; custom path sends custom focus and preserves it in first-turn prompt |
| UI copy | ko/en title, placeholder, CTA, loading/error; Korean placeholder is exact string |
| Regression | backend selected pytest, `flutter analyze --no-pub`, affected Flutter widget/domain tests |

Manual QA는 Korean and English system locale에서 각각 Korean/English topic, opposite target language, ambiguous topic, direct input success/failure를 통과한다.

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| `RESCENE` 같은 로마자 고유명사를 English로 오판 | 문장·단어 evidence가 부족한 짧은 romanized token은 native fallback으로 분류하고 test fixture를 둔다. |
| summary와 question language가 섞임 | prompt에 field-level language contract를 넣고 parsed-response tests로 분리 검증한다. |
| custom focus가 원래 topic과 관계없음 | topic context에서 질문을 만들고, 완전히 무관한 값은 대화를 시작하기보다 focus refinement 안내로 회복한다. |
| 4개 방향 fixture가 남음 | backend schema, frontend model, mock fixture, widget assertions을 같은 변경에서 3개로 바꾼다. |
| double submit/race | controller의 submit 상태와 request identity로 최신 성공값만 반영한다. |

---

## Settled Decisions

1. 추천 방향은 `casual_chat`, `debate`, `explanation_practice`를 유지하고 `interview_qa`를 제거한다.
2. 직접 입력 flow도 기존 추천 flow와 마찬가지로 target-language 첫 질문을 정확히 세 개 보여 준다.
3. 원래 topic과 무관한 custom focus에는 질문을 생성하지 않고, 해당 topic 안에서 다시 입력하도록 한국어/영어 recovery 안내를 반환한다.

## Definition of Done

- 설명 언어와 target-language 질문/대화의 경계가 backend contract와 automated tests로 고정된다.
- 세 추천 방향과 custom focus 모두 첫 질문 선택부터 실제 대화까지 동작한다.
- 준비된 topic에서 새 추천 방향 세 개를 받아도 기존 summary·sources와 custom focus 결과는 유지된다.
- 시스템 locale가 Korean/English인 화면에서 문구와 접근성 label이 각각 자연스럽게 표시된다.
- API 문서와 모바일 UX 문서가 구현과 동기화되고, relevant backend/mobile tests와 analyzer가 통과한다.

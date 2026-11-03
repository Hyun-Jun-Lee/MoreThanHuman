---
title: "Remove Manual Roleplay Difficulty - Implementation Plan"
type: refactor
date: 2026-09-06
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: user-request
execution: code
---

# Remove Manual Roleplay Difficulty - Implementation Plan

## Goal Capsule

- **Objective:** Roleplay 시작 전 수동 난이도 선택을 제거하고, `roleplay_difficulty`의 API, 프롬프트, 저장소 의존성을 완전히 삭제한다.
- **Means:** Flutter Roleplay Setup을 상황 선택만 남기는 흐름으로 단순화하고, FastAPI conversation contract와 ORM을 정리한 뒤 Alembic migration으로 DB column과 PostgreSQL enum type을 제거한다.
- **Authority:** 이번 결정은 사용자가 확정했다. 향후 AI 기반 난이도 자동 조절은 현재 enum 또는 column을 재사용하지 않고, 별도 제품/데이터 모델 설계로 다룬다.
- **Stop conditions:** 새 roleplay는 난이도 입력 없이 시작되고, API 응답·대화 목록·DB schema·prompt 어디에도 `roleplay_difficulty`가 남지 않으며, SQLite와 PostgreSQL migration 경로 및 모바일/백엔드 회귀 검증이 통과한다.

---

## Product Contract

### Requirements

- R1. Roleplay Setup 화면은 preset/custom 상황 선택과 시작 CTA만 제공하며 난이도 label, chip, 설명을 표시하지 않는다.
- R2. Flutter roleplay 시작 호출은 `role_character`, 선택적 `search_context`, `include_audio_response`만 전송한다.
- R3. `POST /api/conversations/start/roleplay/`의 공개 request/response contract와 conversation 목록 contract에서 `roleplay_difficulty`를 제거한다.
- R4. Roleplay prompt와 첫 인사는 선택 난이도 또는 난이도별 말하기 스타일을 참조하지 않고, 역할·언어 snapshot·기존 role guideline만 사용한다.
- R5. `RoleplayDifficulty` Python/Dart enum, ORM column, response model field, copy helper, 전용 widget 및 export를 삭제한다.
- R6. 신규 Alembic migration은 `conversations.roleplay_difficulty`를 삭제하고 PostgreSQL의 `roleplaydifficulty` enum type도 정리한다. 이미 적용된 2026-08-14 migration은 수정하지 않는다.
- R7. 문서와 흐름 명세는 roleplay를 “상황 선택 후 시작”으로 설명하며 수동 난이도 정책을 더 이상 외부 계약으로 묘사하지 않는다.
- R8. 이전 모바일 앱이 보내는 여분의 JSON key에 대한 별도 compatibility API를 추가하지 않는다. 현재 Pydantic request model의 기본 extra-field 처리로 인해 배포 전환 중 해당 key가 무시될 수는 있지만, 지원하는 공개 contract는 아니다.

### Scope Boundaries

**In scope**

- Roleplay 수동 난이도 UI, state/payload, HTTP field, backend enum/schema/model/service/prompt, migration, 테스트, API/UX/architecture/용어 문서 정리
- 현재 DB에서 난이도 값이 들어 있던 historical row의 해당 값 삭제

**Out of scope**

- AI가 사용자의 응답을 분석해 난이도를 추론·변경하는 기능
- Free Chat 또는 Roleplay의 새 적응형 난이도 prompt 정책
- 난이도 추론 결과, confidence, source, history를 저장할 신규 테이블/컬럼 설계
- 다른 roleplay situation, 언어 snapshot, 음성 시작 또는 문법 피드백 동작 변경

### API Contract After This Change

```text
POST /api/conversations/start/roleplay/
request  { role_character, search_context?, include_audio_response? }
response { conversation_id, message_id, conversation_type, role_character?, language, response, ... }

GET /api/conversations/
result   { id, title, conversation_type, role_character?, language, message_count, status, ... }
```

`roleplay_difficulty`는 OpenAPI schema, DSL, JSON request/response, mobile parser 어느 곳에도 포함되지 않는다.

---

## Key Technical Decisions

### KTD1. 현재 수동 난이도 데이터는 보존하거나 이름만 바꾸지 않는다

기존 값은 사용자가 설정한 `EASY/NORMAL/CHALLENGE`이지, AI가 대화 중 추론한 능력 또는 현재 적응 상태가 아니다. 의미가 다른 값을 자동 조절 기능의 seed로 재사용하면 데이터 해석과 모델 정책이 뒤섞인다. 따라서 column과 PostgreSQL enum을 삭제하고, 자동 조절이 구체화될 때 `difficulty_level`, `source`, `confidence`, `updated_at` 등 그 기능의 의미에 맞는 별도 모델을 설계한다.

### KTD2. API field와 DB column을 같은 릴리스에서 제거하되, 배포는 code-first로 진행한다

새 backend는 column이 남아 있는 DB에서도 동작한다. 따라서 production에서는 먼저 새 backend를 배포하고, 그 다음 migration을 적용해 column/type을 삭제한다. 반대로 migration을 먼저 실행하면 구 backend가 ORM field를 참조해 roleplay 시작 또는 이어가기에서 실패할 수 있다. 모바일 앱은 이 backend 이후 배포해도 여분 key가 현재 Pydantic 기본 동작상 무시될 수 있지만, 서버가 해당 field를 다시 문서화하거나 저장하지는 않는다.

### KTD3. Roleplay는 역할 기반의 자연스러운 진행을 유지한다

난이도 section만 제거하고 `role_character`, target/feedback language context, role-specific vocabulary, immersive follow-up, maximum response length 규칙은 유지한다. 이 변경은 roleplay 품질 정책을 새로 정하는 일이 아니라 수동 조절 knob를 제거하는 일이다.

### KTD4. DB migration은 SQLite와 PostgreSQL을 모두 고려해 reversible schema path를 제공한다

`upgrade`는 batch table alteration로 SQLite에서 column을 안전하게 제거하고 PostgreSQL일 때만 named enum type을 drop한다. `downgrade`는 enum type을 다시 만든 후 nullable column을 복원한다. 삭제된 과거 difficulty 값은 복원하지 않는다. 데이터 손실은 사용자가 확정한 schema-removal의 의도된 결과다.

---

## Current-State Trace

| Surface | Current behavior | Target behavior |
| --- | --- | --- |
| Flutter setup | `RoleplayDifficulty.normal`을 기본값으로 state/payload에 보관하고 selector를 표시 | scenario/custom input만 보관하고 바로 start 가능 |
| Mobile API | roleplay start body와 response parser에 `roleplay_difficulty` 포함 | field를 보내거나 해석하지 않음 |
| Backend schema/service | request default, response fields, model column, `RoleplayDifficulty`, prompt helper가 연결됨 | role character와 language context만 사용 |
| Persistence | `conversations.roleplay_difficulty` 및 PostgreSQL `roleplaydifficulty` type 존재 | 신규 migration으로 둘 다 제거 |
| Docs | README, DSL, mobile flow, architecture, glossary가 selector/field 설명 | 수동 난이도 설명 제거 |

---

## Implementation Units

### U1. Backend public contract와 roleplay execution path에서 난이도 제거

- **Requirements:** R3, R4, R5, R8
- **Files:**
  - `backend/domains/conversation/enums.py`
  - `backend/domains/conversation/schemas.py`
  - `backend/domains/conversation/router.py`
  - `backend/domains/conversation/service.py`
  - `backend/tests/domains/conversation/test_topic_prep_handoff.py`
  - `backend/tests/domains/voice/test_multimodal_conversation_router.py`
- **Dependencies:** None
- **Implementation:**
  1. Remove `RoleplayDifficulty` from the conversation enum module and all imports.
  2. Remove `roleplay_difficulty` from `StartRoleplayRequest`, `Conversation`, and `ConversationResponse`; consequently remove it from `MultimodalConversationResponse` too.
  3. Stop passing a difficulty argument from router to `start_roleplay_conversation`.
  4. Change `start_roleplay_conversation`, `continue_conversation`, `build_system_prompt`, and `build_roleplay_prompt` signatures/callers so the service neither receives nor reads difficulty.
  5. Delete default resolution and prompt-style helper methods. Remove the roleplay prompt section and the first-greeting sentence that inject difficulty style; retain the existing role/target-language greeting instruction.
  6. Keep the response envelope, role character, language snapshot, TTS behavior, and conversation/message ownership paths unchanged.
- **Patterns to follow:** Current `ConversationService` separation between `build_roleplay_prompt` and `build_free_chat_prompt`; `StartRoleplayRequest` is the generated OpenAPI source used by router contract tests.
- **Test scenarios:**
  - A roleplay prompt still contains role and target-language guidance but contains no selected-difficulty/style wording.
  - Starting roleplay stores only role/language metadata, returns no difficulty key, and continues with the same role-based prompt.
  - Text and voice roleplay-start requests accept the reduced payload, preserve audio response behavior, and OpenAPI schema no longer publishes the field.

### U2. Remove difficulty persistence and add the destructive schema migration

- **Requirements:** R5, R6
- **Files:**
  - `backend/domains/conversation/models.py`
  - `backend/alembic/versions/<new_revision>_remove_roleplay_difficulty.py`
  - `backend/tests/domains/conversation/test_conversation_repository.py`
  - `backend/tests/alembic/test_roleplay_difficulty_removal_migration.py` (new)
- **Dependencies:** U1 must remove ORM/service references before production migration deployment.
- **Implementation:**
  1. Remove `roleplay_difficulty` from `ConversationModel` and remove the no-longer-needed enum import, while retaining SQLAlchemy enum use for conversation/message/status fields.
  2. Add a new revision after `20260828_0001_add_profile_app_locale`; never edit `20260814_0001_add_roleplay_difficulty.py`, because deployed migration history is immutable.
  3. In `upgrade`, use `op.batch_alter_table("conversations")` to drop the nullable column. On PostgreSQL, then drop `roleplaydifficulty` with `checkfirst=True`; SQLite needs no standalone enum drop.
  4. In `downgrade`, recreate the PostgreSQL enum type before adding back the nullable column through batch alteration. Do not attempt to repopulate historic values.
  5. Replace persistence tests that assert difficulty storage/nullability with tests proving roleplay still persists a long `role_character` and conversation rows no longer expose a difficulty model attribute.
- **Patterns to follow:** `backend/alembic/versions/20260814_0001_add_roleplay_difficulty.py` for dialect-aware PostgreSQL enum lifecycle and batch table alteration; repository tests' in-memory SQLite metadata setup.
- **Test scenarios:**
  - ORM metadata creates and saves free-chat/roleplay conversations without a difficulty column/attribute.
  - The new migration test uses a disposable SQLite DB, upgrades through the old difficulty revision to `head`, and asserts `PRAGMA table_info(conversations)` no longer lists the column.
  - PostgreSQL migration smoke (staging/disposable database) reaches head and confirms neither `conversations.roleplay_difficulty` nor type `roleplaydifficulty` remains; downgrade restores only nullable schema compatibility.

### U3. Simplify Flutter roleplay setup and roleplay-start boundary

- **Requirements:** R1, R2, R5
- **Files:**
  - `mobile/lib/features/roleplay_setup/application/roleplay_setup_controller.dart`
  - `mobile/lib/features/roleplay_setup/domain/roleplay_setup_payload.dart`
  - `mobile/lib/features/roleplay_setup/presentation/roleplay_setup_screen.dart`
  - `mobile/lib/features/roleplay_setup/roleplay_setup.dart`
  - `mobile/lib/features/roleplay_setup/presentation/widgets/widgets.dart`
  - `mobile/lib/features/roleplay_setup/domain/roleplay_difficulty.dart` (delete)
  - `mobile/lib/features/roleplay_setup/presentation/widgets/roleplay_difficulty_chip.dart` (delete)
  - `mobile/lib/core/copy/app_copy.dart`
  - `mobile/lib/features/conversation/domain/conversation_repository.dart`
  - `mobile/lib/features/conversation/data/api_conversation_repository.dart`
  - `mobile/lib/features/conversation/application/start_conversation_controller.dart`
  - `mobile/lib/features/conversation/domain/conversation_models.dart`
  - `mobile/lib/features/home/domain/conversation_summary.dart`
- **Dependencies:** U1 defines the reduced API response/request contract.
- **Implementation:**
  1. Remove `difficulty` from `RoleplaySetupState`, `copyWith`, `selectDifficulty`, and `RoleplaySetupPayload`; payload validity remains determined by a valid situation/custom counterpart and exposes only `roleCharacter`.
  2. Delete the selector widget, enum, barrel exports, difficulty copy methods, and the setup-screen section. Preserve scenario ordering, custom input validation, CTA enablement, navigation, and start failure handling.
  3. Remove `roleplayDifficulty` parameters/defaults from repository interface, API implementation, controller, and all fake implementations. Omit `roleplay_difficulty` from the Dio request body.
  4. Remove response/list parsing and public Dart fields for difficulty; continue parsing `role_character`, language, response, audio and all unrelated fields.
- **Patterns to follow:** Existing feature-first roleplay setup controller/payload boundary and `ApiConversationRepository` envelope decoding.
- **Test scenarios:**
  - Initial roleplay setup has no difficulty state; selecting a preset or valid custom situation yields a payload and enables start.
  - The screen does not render the difficulty section/chips, while scenario/custom selection and start navigation still work.
  - API repository sends exactly the reduced roleplay body and accepts the reduced backend response.
  - Start controller refreshes recent conversations and retains initial audio handling without a difficulty argument.
  - Conversation response and summary parsers accept roleplay data without a difficulty property.

### U4. Synchronize public and internal documentation with the reduced contract

- **Requirements:** R7
- **Files:**
  - `README.md`
  - `docs/DSL.md`
  - `mobile/README.md`
  - `docs/mobile-flow-spec.md`
  - `.agent/architecture.md`
  - `CONCEPTS.md`
- **Dependencies:** U1-U3 finalize exact API and UI shape. Claim `README.md` in `.agent/_coordination/HANDOFF.md` before editing because it is a shared file.
- **Implementation:**
  1. Remove `roleplay_difficulty` from README request example and explanation, DSL model/type/grammar definitions, and mobile README feature-tree descriptions.
  2. Replace Roleplay Setup flow diagrams/wireframes/state table so they move from situation selection directly to conversation, with no difficulty selector/state.
  3. Update architecture data-flow prose and feature-tree description to state roleplay sends/stores `role_character` only; remove the obsolete glossary entry for Roleplay Difficulty.
  4. Do not document a provisional automatic-difficulty schema. Record it only as out of scope until product policy and storage semantics are decided.
- **Patterns to follow:** `AGENTS.md` N-way API synchronization requirement for README + DSL + router; current mobile-flow state/diagram conventions.
- **Test scenarios:**
  - Repository-wide exact search after implementation finds `roleplay_difficulty` and `RoleplayDifficulty` only in the historical add migration, new removal migration, and migration-verification expectations.
  - All public API examples and roleplay flow descriptions match the actual reduced OpenAPI/Dio payload.

---

## Sequencing and Rollout

1. Implement U1 and U2 code changes together on a branch; run backend unit/OpenAPI checks while the old DB column still exists.
2. Implement U3 against the reduced API contract; run targeted Flutter tests and static analysis.
3. Complete U4 and run an exact repository search to ensure product-facing references are gone.
4. Deploy backend code that no longer reads/writes the column.
5. Apply the new Alembic revision to production/staging. This permanently discards historical manual difficulty values and drops the PostgreSQL enum.
6. Release the Flutter app without the selector. During staggered rollout, older clients may send an undocumented extra field that the current Pydantic model ignores; no backend fallback or persistence is retained.

---

## Verification Contract

### Backend

- `cd backend && uv run pytest tests/domains/conversation/test_topic_prep_handoff.py tests/domains/conversation/test_conversation_repository.py tests/domains/voice/test_multimodal_conversation_router.py tests/alembic/test_roleplay_difficulty_removal_migration.py`
- On a disposable SQLite database, upgrade from the difficulty-introducing revision through `head`, inspect `conversations`, and verify the dropped column is absent.
- On staging/disposable PostgreSQL, run `uv run alembic upgrade head`; inspect `information_schema.columns` and `pg_type` to confirm removal of both the column and `roleplaydifficulty` type. Run downgrade/upgrade smoke only against disposable data.

### Mobile

- `cd mobile && dart format lib test`
- `cd mobile && flutter test test/features/roleplay_setup test/features/conversation/data/api_conversation_repository_test.dart test/features/conversation/application/start_conversation_controller_test.dart test/features/conversation/domain/conversation_models_test.dart test/features/home/domain/conversation_summary_test.dart`
- `cd mobile && flutter analyze --no-pub`

### Documentation and Contract Sweep

- Compare generated FastAPI OpenAPI roleplay schemas with `README.md` and `docs/DSL.md`.
- Run an exact search across runtime code and live contracts (`backend/domains`, `backend/tests`, `mobile/lib`, `mobile/test`, `README.md`, `docs/DSL.md`, `docs/mobile-flow-spec.md`, `mobile/README.md`, `.agent/architecture.md`, `CONCEPTS.md`) and review each remaining hit. Historical add/remove migrations and migration-test expectations are allowed; product/runtime hits are not. Archived plans under `docs/plans/` are historical records and are excluded from this gate.

---

## Risks and Mitigations

| Risk | Consequence | Mitigation |
| --- | --- | --- |
| Migration precedes backend code deployment | Old ORM/service may read a missing column | Enforce code-first deployment order and run migration only after new backend is healthy |
| PostgreSQL enum remains after column drop | Dead database type creates future naming collision/confusion | Explicit dialect-aware `DROP TYPE ... checkfirst` and staging inspection |
| SQLite drop behavior differs from PostgreSQL | Local migration appears healthy but production migration fails | Use batch alteration for SQLite and execute PostgreSQL staging smoke |
| Old mobile build still sends removed field | Release overlap could produce request mismatch | Keep no special compatibility endpoint; rely on current default ignored-extra behavior only during rollout and remove it from all supported contracts |
| Future adaptive feature reuses stale semantics | AI inference state is confused with a past user choice | Declare a fresh model design as a prerequisite for that feature |

## Definition of Done

- No user-visible Roleplay difficulty control or copy remains.
- No active backend/mobile runtime code imports, accepts, saves, returns, parses, or prompts from `roleplay_difficulty` / `RoleplayDifficulty`.
- The new Alembic revision removes the conversation column and PostgreSQL enum, with an explicit nullable schema-only downgrade.
- Roleplay remains functional for preset and custom situations, language snapshots, text, and initial audio response.
- Focused backend/mobile tests, migration smoke checks, static analysis, and documentation/API-contract sweep pass.
- The manual difficulty setting is absent from all public docs; adaptive difficulty remains explicitly deferred to a new design.

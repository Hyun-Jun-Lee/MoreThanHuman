---
title: "Profile App Language and Conversation Deletion - Plan"
type: feat
date: 2026-08-28
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: user-request
execution: code
---

# Profile App Language and Conversation Deletion - Plan

## Goal Capsule

- **Objective:** 사용자가 프로필에서 앱 표시 언어를 Korean 또는 English로 바꾸고, 자신의 대화를 완전히 삭제할 수 있게 한다.
- **Means:** 프로필에 앱 표시 언어를 저장해 Flutter `MaterialApp` locale을 override하고, 이미 존재하는 대화 삭제 API를 목록·대화 화면의 확인 흐름에 연결한다.
- **Authority:** 표시 언어는 UI chrome만 바꾼다. 학습 언어쌍, Topic Prep 콘텐츠 언어, 기존 대화 snapshot은 바꾸지 않는다. 대화 삭제는 복구 없는 완전 삭제다.
- **Stop conditions:** 저장한 앱 언어가 기기·세션을 넘어서 적용되고, 사용자가 확인한 대화는 본인 소유 데이터와 하위 메시지/문법 피드백까지 제거되며 앱 목록과 화면에서 즉시 사라진다.

---

## Product Contract

### Requirements

- R1. Profile sheet에 `App language`/`앱 언어` 설정을 추가하고 Korean과 English를 선택할 수 있게 한다.
- R2. 선택한 앱 표시 언어는 authenticated profile에 저장되고, 같은 계정으로 다른 기기에서 로그인해도 적용된다.
- R3. 프로필에 명시한 앱 언어는 device system locale보다 우선한다. 아직 선택값이 없는 기존 사용자는 기존처럼 system locale(`ko`, 그 외 `en`)을 따른다.
- R4. 언어 저장에 성공하면 현재 화면을 포함한 앱 chrome이 즉시 새 언어로 다시 그려진다. 로그인 전 onboarding/login은 profile이 없으므로 system locale을 계속 사용한다.
- R5. app language는 `native_language`, `target_language`, `feedback_language`와 별도다. 이를 바꿔도 학습 언어쌍, 기존 대화와 AI 콘텐츠의 언어 계약은 달라지지 않는다.
- R6. 사용자는 Home 최근 대화, History 목록, 열린 Conversation 화면에서 자기 대화 삭제를 시작할 수 있다.
- R7. 삭제 전에는 해당 대화 제목을 포함한 locale별 확인 dialog를 한 번 표시한다. 확인/취소와 요청 중 disabled 상태를 제공한다.
- R8. 삭제 확인 뒤 server의 conversation row, messages, grammar feedback 등 연관된 앱 DB 데이터는 복구 없이 완전히 삭제한다.
- R9. 삭제 성공 시 목록에서는 항목을 즉시 제거하고, 열린 conversation이면 안전하게 Home으로 이동한다. 실패하면 기존 화면·목록을 보존하고 locale별 재시도 안내를 제공한다.
- R10. 삭제 API는 항상 authenticated current user ownership을 확인한다. 다른 사용자의 대화 ID는 존재 여부를 노출하지 않는 기존 `404` 정책을 유지한다.

### Key Flows

#### F1. Profile app language change

1. 사용자가 Profile sheet의 `앱 언어`/`App language`에서 Korean 또는 English를 선택하고 저장한다.
2. 모바일은 `PUT /api/auth/me/app-locale`에 선택값을 보낸다.
3. backend는 profile의 nullable `app_locale`을 저장하고, 최신 profile을 반환한다.
4. 앱 locale provider가 새 값을 반영해 `MaterialApp.router(locale: ...)`와 `AppCopy`를 즉시 재구성한다.
5. 사용자가 다시 앱을 열거나 다른 기기에서 로그인하면 `/auth/me`의 값으로 같은 앱 표시 언어가 적용된다.

#### F2. Existing user fallback

1. migration 이전 또는 아직 app language를 고르지 않은 profile의 `app_locale`은 `null`이다.
2. Flutter는 explicit override가 없을 때만 device system locale을 사용한다.
3. 따라서 기존 onboarding/login/system-locale 행동과 사용자 학습 설정은 바뀌지 않는다.

#### F3. Delete from a list

1. 사용자가 Home 또는 History의 conversation card overflow delete icon을 누른다.
2. 확인 dialog에서 취소하면 아무 데이터도 바뀌지 않는다.
3. 삭제를 확인하면 해당 card의 control과 동일 deletion action이 loading 상태가 된다.
4. 성공하면 recent-conversations provider에서 해당 ID를 제거하고, 필요 시 background reload로 서버 목록과 동기화한다.

#### F4. Delete an open conversation

1. 사용자가 Conversation app bar의 delete icon을 누른다.
2. 확인 뒤 delete request가 성공하면 message/grammar polling 및 audio playback을 정리하고 Home으로 이동한다.
3. 실패하면 현재 conversation, draft, scroll state를 그대로 유지하고 dialog/snackbar에서 재시도할 수 있다.

### Scope Boundaries

- **In scope:** profile-persisted `ko`/`en` app display override, existing-user system fallback, app-wide immediate locale update, complete conversation deletion UI, ownership/cascade verification, docs and tests.
- **Out of scope:** device OS language 변경, 새 학습 언어쌍, Chinese app chrome, account deletion, 삭제 복구/휴지통, bulk deletion, undo snackbar.
- **Deferred:** profile의 `system default` reset option, display language 추가 지원, deletion audit log/retention, multi-select cleanup.

---

## Technical Plan

### Architecture Decisions

- KTD1. **`app_locale`은 profile의 nullable 별도 컬럼이다.** `native_language` 등 learning context 필드에 재사용하거나 섞지 않는다. 값은 `ko`, `en`, `null`만 허용하며 `null`은 device system locale fallback 의미다.
- KTD2. **프로필 API가 source of truth다.** `GET /auth/me`은 `app_locale`을 포함하고 `PUT /auth/me/app-locale`은 값 저장 후 최신 profile을 반환한다. Flutter local state는 즉시 UI를 갱신하지만 서버 profile로 다시 수렴한다.
- KTD3. **`MaterialApp`이 effective locale을 소유한다.** `AppCopy`는 이미 `Localizations.localeOf(context)`를 사용하므로 화면별 locale branch를 만들지 않는다. effective locale provider는 authenticated profile의 explicit `app_locale`, 없으면 platform locale 순으로 고른다.
- KTD4. **완전 삭제의 backend path는 기존 endpoint를 사용한다.** `DELETE /api/conversations/{conversation_id}/`는 이미 ownership lookup 후 SQLAlchemy `delete`를 수행한다. ORM cascade(`Conversation -> Message -> GrammarFeedback`)를 테스트로 보강하며 새 delete endpoint를 만들지 않는다.
- KTD5. **삭제는 destructive confirmation을 요구한다.** confirmation 전에는 네트워크 호출을 하지 않으며, 성공 전 optimistic removal을 하지 않는다. 서버 성공 후 provider state와 navigation을 갱신한다.

### API and Data Contract

Profile model/migration에 다음 nullable field를 추가한다.

```text
profiles.app_locale: String(2) | null  // "ko" | "en" | null
```

```http
PUT /api/auth/me/app-locale
Authorization: Bearer <token>
Content-Type: application/json

{ "app_locale": "ko" }
```

성공 응답은 `UserProfile`과 동일한 shape에 `app_locale`을 포함한다. request는 unknown value와 extra field를 거부한다. `null` 수용 여부는 API에 두지 않는다. 사용자가 명시적으로 Korean/English 중 하나를 고르는 현재 UI만 지원하고, system fallback은 기존 profile과 migration의 `null` 값에만 적용한다.

대화 삭제 contract는 그대로 유지한다.

```http
DELETE /api/conversations/{conversation_id}/
Authorization: Bearer <token>
```

`200`은 성공, `404`는 없는 ID 또는 다른 사용자 소유, `401/403`은 인증 실패다. mobile은 서버 Korean message를 표시하지 않고 `AppCopy`의 locale별 성공/실패 copy를 사용한다.

### Work Breakdown

#### U1. Backend profile app locale persistence

**Files**

- `backend/alembic/versions/<new_revision>_add_profile_app_locale.py`
- `backend/domains/auth/models.py`
- `backend/domains/auth/schemas.py`
- `backend/domains/auth/repository.py`
- `backend/domains/auth/service.py`
- `backend/domains/auth/router.py`
- `backend/tests/domains/auth/test_profiles_repository.py`
- `backend/tests/domains/auth/test_language_preferences_router.py` 또는 신규 app-locale router test

**Changes**

1. nullable `app_locale` column migration과 downgrade를 추가한다. 기존 rows에는 `null`을 유지한다.
2. `AppLocaleCode` closed enum/request schema를 만들고, UserProfile response에서 nullable field를 serialize한다.
3. repository/service update method는 profile ownership을 기준으로 `ko`/`en`만 저장하고 updated timestamp를 갱신한다.
4. `/auth/me` read, app-locale update success, invalid code, extra field rejection, existing null profile의 serialization을 테스트한다.

#### U2. Flutter app-locale state and profile setting

**Files**

- `mobile/lib/app/app.dart`
- `mobile/lib/core/copy/app_copy.dart` 및 `mobile/lib/core/copy/copy.dart`
- `mobile/lib/features/auth/domain/user_profile.dart`
- `mobile/lib/features/auth/domain/auth_repository.dart`
- `mobile/lib/features/auth/data/api_auth_repository.dart`
- `mobile/lib/features/auth/application/auth_controller.dart` 또는 dedicated app-locale controller
- `mobile/lib/features/home/presentation/account_sheet.dart`
- auth/app/copy/account-sheet tests

**Changes**

1. profile JSON model과 repository에 app locale update operation을 추가한다.
2. effective locale provider를 만든다. profile value가 `ko`/`en`이면 `MaterialApp.router.locale`로 지정하고, `null`이면 `locale`을 지정하지 않아 Flutter가 platform locale을 사용하게 한다.
3. profile sheet에는 language pair 설정과 별도인 `앱 언어` section을 둔다. Korean/English selection control과 save/error/loading state를 제공한다.
4. 저장 성공은 auth session의 UserProfile을 atomically 갱신해 앱 전체 UI를 즉시 리빌드한다. 실패하면 기존 effective locale과 선택 전 profile을 유지한다.
5. Korean and English system locale, explicit opposite override, existing null fallback, learning-language-pair 불변을 unit/widget tests로 고정한다.

#### U3. Conversation deletion mobile integration

**Files**

- `mobile/lib/features/conversation/domain/conversation_repository.dart`
- `mobile/lib/features/conversation/data/api_conversation_repository.dart`
- `mobile/lib/features/conversation/application/`의 dedicated deletion controller
- `mobile/lib/features/conversation/presentation/conversation_screen.dart`
- `mobile/lib/features/home/presentation/widgets/recent_conversation_card.dart`
- `mobile/lib/features/home/presentation/home_screen.dart`
- `mobile/lib/features/history/presentation/history_screen.dart`
- `mobile/lib/core/copy/app_copy.dart`
- affected conversation/home/history widget and repository tests

**Changes**

1. repository에 `deleteConversation(conversationId)`를 추가해 기존 DELETE API를 호출한다.
2. one-operation deletion controller는 loading/error를 소유하고, success 후 `recentConversationsControllerProvider`를 invalidate/reload한다.
3. card에 tooltip·semantic label을 가진 icon overflow deletion action을 추가한다. Home/History에서 같은 component와 confirmation dialog를 재사용한다.
4. Conversation app bar에도 delete icon을 추가한다. delete 진행 중 send/composer와 deletion action을 적절히 disable하고, 성공 시 router callback으로 Home으로 돌아간다.
5. `AppCopy`에 dialog title/body/cancel/confirm, deleting status, failure/success semantic copy를 Korean/English로 추가한다. 최종 삭제 confirm은 분명한 destructive wording을 사용한다.
6. repository request, cancel path, success removal, request failure retention, open-screen navigation, accessibility/locale rendering을 테스트한다.

#### U4. Backend deletion integrity and docs

**Files**

- `backend/tests/domains/conversation/`의 delete/router/repository test
- `README.md`
- `docs/DSL.md`
- `mobile/README.md`
- `.agent/architecture.md`

**Changes**

1. existing delete endpoint가 owner conversation만 지우고 associated messages/grammar feedback을 지우며 다른 user data는 유지하는 integration test를 추가한다.
2. README와 DSL에 profile app-locale endpoint/field 및 deletion complete-removal semantics를 기록한다.
3. mobile README와 architecture에 profile display-locale ownership, system fallback, complete deletion state/navigation flow를 갱신한다.
4. 구현 완료 시 coordination changelog와 STATE를 업데이트한다.

---

## Verification Plan

| Area | Evidence |
|---|---|
| Profile persistence | Korean/English save, app restart/profile reload, invalid value rejection, migration null fallback |
| UI locale override | Korean-system + English app setting, English-system + Korean app setting, null profile + system fallback |
| Learning isolation | app locale change does not mutate `native/target/feedback` or existing conversation snapshot |
| Complete deletion | conversation, messages, grammar feedback removed; another user's conversation is preserved and receives 404 |
| List UX | Home/History cancel, loading, success removal, failure preservation, provider refresh |
| Open chat UX | confirmation, deletion success navigation Home, audio/grammar cleanup, request failure remains in conversation |
| Regression | selected backend pytest, `flutter analyze --no-pub`, affected Flutter tests in both `ko`/`en` locales |

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| App locale is confused with learning target language | separate `app_locale` field, distinct profile section/copy, and invariant tests |
| Startup briefly shows platform locale before authenticated profile arrives | profile override applies immediately after session restore; pre-login remains intentionally system-locale based |
| User accidentally deletes a conversation | explicit title-bearing confirmation, no swipe-to-delete or optimistic removal, no hidden destructive shortcut |
| Deletion leaves related records | ORM cascade tests cover messages and grammar feedback; deletion is routed only through owned repository lookup |
| Stale list after delete | remove/invalidate only after success and reload recent-conversations provider |

## Definition of Done

- Profile에서 Korean/English app display language가 저장되고, 앱 chrome이 즉시 및 다음 로그인에도 그 값으로 표시된다.
- app display language와 learning language context가 서로 영향을 주지 않는다.
- 사용자가 명시적으로 확인한 대화는 Home, History, Conversation 화면에서 완전 삭제되고 다시 접근할 수 없다.
- API, migration, mobile flow와 Korean/English test coverage가 문서 및 구현과 동기화된다.

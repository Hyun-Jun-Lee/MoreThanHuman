---
title: 첫 로그인 닉네임 설정 계획
type: feat
date: 2026-10-18
artifact_contract: ce-unified-plan/v1
product_contract_source: user-request
execution: code
---

# 첫 로그인 닉네임 설정 계획

## 목표

Google·Apple로 처음 가입한 사용자는 인증과 앱 프로필 조회가 끝난 직후 닉네임 입력 팝업을 보게 해요. 저장한 닉네임은 계정의 표시 이름으로 쓰고, `내 정보`에서 나중에 수정할 수 있게 해요. 닉네임 중복은 검사하거나 제한하지 않아요. 기존 가입자에게는 신규 가입 팝업을 띄우지 않아요.

## 현재 구조와 결정

- Supabase 로그인 뒤 `AuthController`가 `GET /api/auth/me`로 앱 프로필을 받아요. `get_current_user`가 어떤 보호 API에서든 프로필을 처음 만들 수 있으므로, 기기의 로그인 횟수나 가입 시각으로 신규 여부를 판단하지 않아요.
- `profiles.name`은 OAuth 이름 또는 이메일 앞부분이고, `UserProfile`과 `ProfileScreen`은 이를 화면에 표시해요. 로그인 때 기존 프로필의 이름을 자동 갱신하지 않아요.
- **KTD1 — 닉네임은 별도 필드:** `profiles.nickname`을 nullable로 추가하고 OAuth 원본인 `name`은 보존해요. 표시 이름은 `nickname ?? name`을 사용해요.
- **KTD2 — 서버 데이터로 첫 설정 판정:** 마이그레이션에서 기존 모든 프로필의 `nickname`을 `name`으로 채워요. 배포 후 생성되는 프로필의 `nickname`은 `NULL`로 두고, `GET /api/auth/me`가 이를 그대로 반환해요. `NULL`이면 첫 설정 미완료예요. 닉네임 저장 이후에는 null로 되돌리는 기능을 제공하지 않아요.
- **KTD3 — 첫 설정은 완료해야 진행:** 신규 사용자의 팝업은 배경 탭·뒤로 가기로 닫히지 않으며, 유효한 닉네임 저장 성공 후 닫혀요. 저장 실패 시 입력값을 유지하고 오류와 재시도를 보여줘요. 이는 팝업을 반드시 거치게 한다는 제품 가정이에요. 건너뛰기를 원한다면 구현 전 `nickname_setup_completed` 같은 별도 상태 필드가 필요해요.
- **KTD4 — 중복 허용:** 닉네임에 UNIQUE 제약, 조회 API, 중복 검사 요청을 추가하지 않아요. 같은 닉네임을 여러 계정이 사용할 수 있어요. 계정 식별과 수정 권한은 계속 Supabase 사용자 ID로 처리해요.

---

## 요구사항과 완료 기준

- **R1.** 신규 계정은 Google·Apple 로그인 또는 기존 Supabase 세션 복원 후 `/auth/me`에서 `nickname: null`을 받으면 팝업을 한 번만 열어요. 팝업 표시 전에 다른 시작 팝업이나 화면 전환과 충돌하지 않아야 해요.
- **R2.** 기존 가입자는 마이그레이션 후 현재 표시 이름을 유지하며 신규 가입 팝업이 뜨지 않아요.
- **R3.** 닉네임은 앞뒤 공백을 제거한 1~20자의 표시 문자열로 저장해요. 공백만 입력하거나 줄바꿈·제어 문자가 들어간 값은 거절해요. 동일한 값은 다른 계정에서도 허용해요. 서버가 최종 검증하고, 앱은 같은 안내를 보여줘요.
- **R4.** 저장은 인증된 본인 프로필에만 적용되고, 성공하면 최신 `UserProfile`을 돌려줘요. 앱 상태와 `내 정보`의 이름·프로필 이니셜이 즉시 바뀌어요.
- **R5.** `내 정보`에서 현재 닉네임을 다시 수정할 수 있어요. 수정 팝업은 취소할 수 있고, 실패하면 기존 표시 이름을 유지해요.
- **R6.** 한국어·영어 앱 언어에 맞는 팝업 제목, 입력 힌트, 저장 버튼, 검증·저장 오류 문구를 제공해요.

### 수용 예시

| 사례 | 기대 동작 |
|---|---|
| 신규 Google/Apple 계정의 첫 로그인 | `nickname: null` → 팝업 → 저장 성공 → 홈과 내 정보에 닉네임 표시 |
| 예전 가입자의 앱 업데이트 후 로그인 | 마이그레이션된 닉네임 표시, 팝업 없음 |
| 팝업에서 저장 실패 후 앱 재시작 | 서버 값은 계속 null, 입력 팝업 재표시 |
| 같은 닉네임을 두 계정에 저장 | 두 요청 모두 성공 |
| 내 정보에서 닉네임 변경 | 새 닉네임이 즉시 표시되고 다음 로그인에도 유지 |

---

## 구현 단위

### U1. 프로필 스키마와 기존 가입자 이관

**목표:** 기존 사용자와 신규 사용자의 첫 설정 상태를 서버 데이터로 확실히 구분해요.

**파일:** `backend/alembic/versions/`의 새 migration, `backend/domains/auth/models.py`, `backend/tests/alembic/`의 migration 테스트.

**접근:** 현재 Alembic head에 `nickname VARCHAR(100) NULL`을 추가하고 같은 migration에서 기존 행의 `nickname = name`을 채워요. 기존 `name`이 최대 100자라 이관 중 잘림을 피하고, 새 입력의 20자 제한은 API에서 검증해요. `profiles.name`은 유지해요. migration 이후 생성 경로에는 닉네임 기본값을 넣지 않아요. 운영 DB의 기존 프로필 수와 `nickname IS NULL` 수를 적용 전후 확인해요. 여러 서버 버전이 잠시 겹쳐도 구버전 앱은 새 응답 필드를 무시할 수 있게 배포 순서를 잡아요.

**검증:** 기존 행은 이름이 이관되고, 새 행은 null이며, 반복 인증 조회가 null을 임의로 채우지 않아요.

### U2. 닉네임 API 계약과 저장

**목표:** 본인의 닉네임을 안전하게 저장하고 최신 프로필을 반환해요.

**파일:** `backend/domains/auth/schemas.py`, `repository.py`, `service.py`, `router.py`, `backend/tests/domains/auth/`의 관련 테스트, `docs/DSL.md`, `.agent/_contracts/SUPABASE_AUTH.md`.

**접근:** `UserProfile`에 `nickname: string | null`을 추가하고 `PUT /api/auth/me/nickname`에 `{ "nickname": "..." }`를 받아 기존 `{ success, data }` 형식의 전체 `UserProfile`을 반환해요. 요청은 빈 값·길이·줄바꿈·제어 문자를 검증하고, 저장 전 앞뒤 공백을 제거해요. `get_current_user`의 인증·프로필 생성 흐름은 유지하고, 저장은 검증된 현재 사용자 ID만 사용해요. 같은 닉네임을 가진 다른 계정 조회나 UNIQUE 인덱스는 만들지 않아요. API 계약 문서와 인증 계약은 구현과 같은 작업 단위로 갱신해요.

**검증:** 인증 실패, 유효하지 않은 입력, 본인 저장, 타 계정과 동일 닉네임 허용, 재로그인 시 유지, 인증 재조회 시 미변경을 확인해요.

### U3. 앱 프로필 상태와 첫 로그인 팝업

**목표:** 서버의 `nickname: null`을 신규 가입 완료 전 상태로 해석하고 첫 인증 직후 한 번만 팝업을 띄워요.

**파일:** `mobile/lib/features/auth/domain/user_profile.dart`, `mobile/lib/features/auth/domain/auth_repository.dart`, `mobile/lib/features/auth/data/api_auth_repository.dart`, `mobile/lib/features/auth/application/auth_controller.dart`, `mobile/lib/app/router/app_router.dart` 또는 인증된 화면을 감싸는 게이트 위젯, 닉네임 팝업 위젯, `mobile/lib/core/copy/app_copy.dart`, 관련 모바일 테스트.

**접근:** `UserProfile`에 nullable 닉네임과 표시 이름 getter를 추가하고, 저장 API를 호출하는 repository/controller 동작을 만들어요. 로그인·세션 복원에서 `/auth/me`가 성공하고 인증 상태가 확정된 뒤, 인증된 화면의 상위 게이트가 null 닉네임인 사용자에 대해 팝업을 예약해요. 사용자 ID별 표시 중 가드로 라우터 재빌드나 locale 변경에 따른 중복 팝업을 막아요. 팝업은 초기 설정일 때 닫을 수 없고 저장 중 중복 제출을 막아요. 성공 응답으로 인증 상태를 교체한 뒤 닫아요. 실패 시 입력을 유지하고 다시 저장할 수 있어요. 닉네임이 있는 계정, 로그아웃 직후, 인증 복원 오류에서는 표시하지 않아요.

**검증:** Google·Apple 성공, 재시작 복원, 기존 계정, 저장 실패/재시도, 빠른 화면 전환, 반복 rebuild에서 팝업 개수를 확인해요.

### U4. 내 정보 표시와 수정 진입점

**목표:** 사용자가 현재 닉네임을 보고 수정할 수 있어요.

**파일:** `mobile/lib/features/profile/presentation/profile_screen.dart`, 닉네임 팝업 위젯, `mobile/lib/core/copy/app_copy.dart`, `mobile/test/features/profile/` 관련 테스트.

**접근:** 현재 `user.name` 대신 표시 이름 getter를 이름 텍스트와 아바타 이니셜에 사용해요. 이름 영역에 수정 동작을 연결하고 기존 닉네임을 입력란의 초기값으로 보여줘요. 수정 모드는 취소 가능하며, 저장 성공 후 화면 상태만 갱신해요. 기존 이름 행의 한 줄 말줄임과 프로필 아이콘 높이 제약을 유지해요.

**검증:** 한국어·영어 UI에서 표시·수정·취소·오류, 긴 닉네임과 작은 화면의 레이아웃을 확인해요.

---

## 배포 순서와 영향

1. DB migration을 적용하고 기존 행의 닉네임 이관 결과를 확인해요.
2. 백엔드 API와 `docs/DSL.md`를 배포해요. 기존 앱은 응답의 새 필드를 사용하지 않아요.
3. 모바일 앱을 배포해 신규 가입 팝업과 내 정보 수정을 활성화해요.

기존 사용자에게 보이는 이름은 유지돼요. 신규 사용자는 서버에 닉네임이 저장되기 전까지 매 로그인·세션 복원 시 설정 팝업이 다시 떠요. 구버전 앱에서 가입한 사용자도 닉네임이 null이면 새 앱으로 업데이트한 첫 로그인 때 팝업을 보게 돼요. DB 마이그레이션 롤백 시 닉네임 데이터가 소실되므로, 운영 롤백은 우선 모바일·API만 이전 버전으로 되돌리고 DB 컬럼은 유지하는 방식을 권장해요.

## 범위 밖

닉네임 중복 검사, 검색·멘션·공개 프로필, Supabase `user_metadata` 동기화, 기존 사용자의 닉네임 재입력 강제, 닉네임 건너뛰기 기능은 이번 범위에 넣지 않아요. 건너뛰기 요구가 생기면 null 하나로는 '아직 보지 않음'과 '나중에 하기'를 구별할 수 없으므로 별도 완료 상태를 설계해요.

## 완료 조건

마이그레이션과 API 테스트, Flutter 단위·위젯 테스트, `flutter analyze`가 통과하고, 신규/기존 계정의 실제 로그인 경로에서 위 수용 예시를 확인해요. API·인증 계약 및 아키텍처 문서를 구현과 동기화해요.

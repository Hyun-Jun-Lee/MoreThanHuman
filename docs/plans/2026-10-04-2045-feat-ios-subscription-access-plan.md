---
title: iOS Apple 구독과 대화 권한 연동 계획
type: feat
date: 2026-10-04
artifact_contract: ce-unified-plan/v1
product_contract_source: ce-plan-bootstrap
execution: code
---

# iOS Apple 구독과 대화 권한 연동 계획

## Goal Capsule

- **Objective:** 학습자가 iOS에서 Advance 또는 Plus를 구독·복원하면 같은 Convia 계정의 대화 한도가 정확히 바뀌고, 만료·환불 후에도 기존 기록을 잃지 않아요.
- **Means:** StoreKit 2 구매 결과를 백엔드에서 Apple 서명과 현재 구독 상태로 검증하고, 서버 권한에 따라 활성 대화 슬롯과 발화를 제어해요. (KTD1~KTD5)
- **Authority:** 이 대화에서 확정한 상품·무료/유료 한도·잠금 정책이 기준이에요. 기존 `.agent/_contracts/CONVERSATION_ACCESS.md`의 영구 슬롯 grant와 기존 계정 보장 규칙은 이번 정책으로 대체해요.
- **Execution profile:** 이 문서는 구현 계획이에요. 구현 시 계약 문서를 먼저 개정한 뒤 백엔드, Flutter, 운영 검증 순으로 진행해요.
- **Stop condition:** Definition of Done의 서버·앱·Sandbox·운영 조건이 충족되고 App Store 심사 제출에 필요한 화면과 문구가 준비되면 구현 완료예요. 실제 운영 활성화와 심사 제출은 배포 단계예요.

## Product Contract

### Summary

iOS 앱에서 월간 `Advance`와 `Plus`를 구매·복원하고 서버가 Apple 거래를 확인해 계정 권한을 부여해요. 무료 계정은 활성 대화 1개와 대화당 사용자 발화 15회, Advance는 활성 대화 5개와 무제한 발화, Plus는 활성 대화 10개와 무제한 발화를 사용해요. 초과 대화는 읽기 전용으로 보존해요.

### Problem Frame

현재 백엔드는 `CONVERSATION_ACCESS_ENABLED=false`가 기본값이고, 활성화해도 모든 저장 대화를 슬롯으로 세며 기존 계정의 여러 대화를 영구 무료 슬롯으로 보장해요. Flutter는 실제 기록 대신 빈 ‘잠금 자리’를 보여줘요. 이 상태로 결제를 연결하면 구독 만료 시 합의한 읽기 전용 전환과 대화 선택을 표현할 수 없어요.

### Requirements

- **R1.** 판매 대상은 App Store Connect의 같은 구독 그룹(`22439301`, 참조명 `ttm_scbscribe`)에 속한 1개월 자동 갱신 상품 `Advance`, `Plus`예요. 대소문자까지 같은 제품 ID를 사용해요. 앱은 StoreKit의 현지화된 실제 가격·기간을 표시하고 가격 환경변수는 두지 않아요.
- **R2.** 무료 계정은 동시 활성 대화 1개에 사용자 발화 15회를 적용해요. Advance는 활성 대화 최대 5개, Plus는 최대 10개이며 두 구독은 활성 대화의 사용자 발화 횟수에 제한이 없어요. `ACTIVE`와 `COMPLETED` 대화 모두 활성 슬롯을 차지해요.
- **R3.** 저장된 대화 수에는 평생 한도를 두지 않아요. 비활성 대화는 목록·메시지 읽기·삭제가 가능하고 생성 한도에 포함되지 않지만 텍스트·음성 발화는 거절해요. 사용자는 활성 대화를 다른 저장 대화로 교체하거나 비워 새 대화를 시작할 수 있어요.
- **R4.** 기존 계정에 대화가 여러 개면 무료 권한에서 최근 실제 사용 대화 1개만 활성화하고 나머지는 읽기 전용으로 잠가요. 사용자가 다른 대화를 선택하면 원자적으로 교체해요. 선택된 무료 대화의 기존 발화 수는 초기화하지 않으며 15회 이상이면 추가 발화는 막아요.
- **R5.** 구독 취소 후 결제된 기간까지 유료 혜택을 유지해요. Apple이 확인한 결제 유예 기간에는 혜택을 유지하고, 만료·환불·철회 시 무료 1개 또는 남은 유효 상품의 권한으로 낮춰요. Plus에서 Advance로 바뀌면 최대 5개만 활성화해요. 나머지 기록은 보존해요.
- **R6.** 구매·복원·갱신·상품 변경은 해당 Convia 계정에만 반영해요. 같은 Apple 원거래를 두 Convia 계정에 동시에 부여하지 않아요. Apple 로그인이 아닌 Google 로그인 Convia 계정에서도 iOS 구매가 가능해요.
- **R7.** iOS에서는 요금제 비교, 구매, 구매 복원, 구독 관리 진입을 제공해요. 결제 실패·취소·검증 대기에는 권한을 선부여하지 않고 복구 가능한 상태를 안내해요. paywall에는 실제 가격·갱신 주기·혜택·이용약관·개인정보처리방침을 표시해요.
- **R8.** Android에서는 이번 출시의 구매 버튼을 숨겨요. 동일 Convia 계정에 iOS에서 검증된 권한이 있으면 Android에서도 서버가 허용한 대화 권한을 사용해요.
- **R9.** `com.morethanhuman.curitalk.conversation_slot_1` 단품은 이번 구현·앱 노출·심사 제출에서 제외해요. Plus 전용 추가 기능도 후속 과제예요.

### Key Decisions

- **무료 1개 외 실제 기록 잠금** (session-settled: user-directed — 기존 계정 다중 무료 슬롯 보장 대신 읽기 전용 보존을 선택했어요.) Governs R2~R4.
- **iOS 먼저 출시** (session-settled: user-directed — Android 결제 구현을 후속으로 미뤘어요.) Governs R7, R8.
- **두 상품 모두 월간, 단품 보류** (session-settled: user-directed — 판매 범위를 두 구독으로 좁혔어요.) Governs R1, R9.
- **구독 종료 후 초과 대화 잠금** (session-settled: user-approved — 기록을 보존하면서 유료 권한만 회수해요.) Governs R3~R5.

### Acceptance Examples

- **AE1.** 무료 사용자가 대화 1개에 사용자 발화 15회를 쓰면 16번째 텍스트·음성 발화는 서버에서 거절되고 기록 읽기는 계속 가능해요. Covers R2, R3.
- **AE2.** 기존 대화 4개인 무료 계정은 최근 사용 1개가 활성화되고 3개는 읽기 전용이에요. 잠긴 대화를 선택하면 기존 활성 대화가 잠기고 선택한 대화가 활성화돼요. Covers R3, R4.
- **AE3.** 같은 계정이 iOS에서 Advance를 구독하면 최대 5개 대화를 활성화하고 15회 초과 대화도 이어 말할 수 있어요. Plus로 업그레이드하면 10개까지 가능해요. Covers R1, R2, R6.
- **AE4.** 자동 갱신을 해지해도 확인된 종료 시각 전에는 한도가 유지돼요. 만료 또는 환불이 확인되면 최근 사용 순으로 허용 개수만 남고 다른 대화는 읽기 전용이 돼요. Covers R4, R5.
- **AE5.** 구매 성공 직후 네트워크가 끊겨 검증이 실패해도 앱 재진입·구매 복원으로 같은 거래를 다시 제출할 수 있고 중복 혜택은 생기지 않아요. Covers R6, R7.
- **AE6.** 다른 Convia 계정이 이미 연결된 Apple 원거래를 복원하면 두 번째 계정에는 권한을 주지 않고 원 계정 안내를 보여줘요. Covers R6.

### Scope Boundaries

- 서버가 구매 진위를 판단해요. 앱이 결제 성공 표시만으로 슬롯을 열지 않아요.
- 구독 기간·가격은 App Store Connect가 관리해요. 월간 가격 8,000원/15,000원은 한국 스토어 설정값이며 앱에 고정 문구로 저장하지 않아요.
- 과거 대화를 유료 구매 전용 대화로 옮기거나 `is_paid_conversation` 같은 영구 표시를 만들지 않아요. 이번 상품은 기간제 계정 권한이에요.

### Deferred to Follow-Up Work

- 단품 슬롯의 판매·소모성 검증·환불, Plus 전용 기능, Google Play Billing을 별도로 설계해요.

### Assumption to Confirm

- 다른 Convia 계정에서 같은 Apple 거래를 복원하면 **최초 연결 계정 유지**를 기본으로 계획해요. 사용자의 다른 선택이 오면 R6·AE6·U2·U5를 수정해야 해요. 기존 구매에 `appAccountToken`이 없을 때에는 검증 후 최초 복원 계정에만 연결해요.

## Planning Contract

### Key Technical Decisions

- **KTD1. Apple 거래를 서버에서 확인해요.** Flutter `in_app_purchase`의 StoreKit 2 거래 JWS 또는 거래 ID를 서버에 보내고, Apple 서명 검증과 App Store Server API의 최신 구독 상태 확인 후에만 권한을 저장해요. `Advance`·`Plus`, 앱 bundle ID, 환경, 구독 그룹, 만료·철회 정보를 검증해요. (`R1`, `R5`, `R6`)
- **KTD2. 원거래를 계정에 유일하게 묶어요.** `originalTransactionId`에 DB 유니크 제약을 두고 최초 결제 시 Convia 사용자 UUID를 `appAccountToken`으로 전달해요. 현재 인증 사용자, 서명된 token, 기존 소유자 사이 충돌은 거절해요. (`R6`)
- **KTD3. 현재 상태 조회로 이벤트를 조정해요.** App Store Server Notifications V2의 서명·중복 ID를 검증하고 해당 원거래를 Apple API에서 다시 조회해 현재 상태로 갱신해요. 순서가 뒤바뀐 알림을 그대로 적용하지 않아요. 누락 알림에 대비한 만료 임박/경과 재조회 작업과 앱 복원 재동기화 경로를 둬요. (`R5`)
- **KTD4. 대화 활성 선택을 서버에 저장해요.** `conversations`에 현재 슬롯 선택 여부를 기록하되 결제 여부와 혼동하지 않는 이름을 사용해요. 권한 변경·대화 생성·선택 교체·사용자 발화는 동일 계정 행을 먼저 잠그는 짧은 트랜잭션에서 한도와 만료 시각을 다시 검사해요. 결제 도메인과 대화 도메인의 연결은 서비스/공유 계약을 거치고, LLM·Apple 네트워크 호출 중에는 DB 잠금을 잡지 않아요. (`R2`~`R5`)
- **KTD5. 클라이언트는 서버 권한을 표시해요.** 기존 대화 접근 API를 확장하고 실제 대화 목록에 `is_locked`/활성 여부를 제공해요. iOS 구매는 서버 확인 후 권한 API를 갱신하고 Android에는 구매 CTA를 내지 않아요. (`R3`, `R7`, `R8`)

### High-Level Technical Design

```text
iOS StoreKit 2 → Flutter 거래 수신 → 인증된 검증 API → Apple 서명/상태 API
                                                    ↓
                                      원거래-계정 연결·구독 상태 DB
                                                    ↓
                            서버 권한(1/5/10, 15회/무제한) → 대화 API → Flutter
Apple 알림 V2 → 서명 검증 → 현재 상태 재조회 ────────────┘
```

```text
active / grace → cancel 예정: 결제 종료까지 기존 권한
active / grace → expired / revoked: 한도 축소, 초과 대화 읽기 전용
expired → renewed / recovered: 최신 상품 한도로 잠금 대화 재활성 가능
Plus → Advance: 10 → 5, 최근 사용 대화 우선 유지, 사용자 재선택 가능
```

무료/유료 한도는 요청 시 서버의 유효 시각을 기준으로 다시 계산해요. 로컬 만료 시각을 지났고 Apple 재조회가 실패하면 검증되지 않은 유료 기간을 늘리지 않고 동기화 대기와 재시도를 제공해요. 알림과 재조회는 갱신 지연을 줄이는 경로예요.

### API/데이터 계약 방향

- `GET /api/billing/entitlement/`: `plan`, `status`, `expires_at`, `slot_limit`, `turn_limit`, `environment` 등 서버 확정 상태. 앱은 로그인 계정 변경 시 이전 응답을 폐기해요.
- `POST /api/billing/apple/verify/`: 인증된 사용자가 StoreKit 거래의 JWS/거래 ID를 제출하고, 서버가 검증·소유권·현재 상태를 처리한 뒤 최신 entitlement를 돌려줘요. 구매와 복원은 같은 멱등 경로를 써요.
- `POST /api/billing/apple/notifications/`: Apple V2 `signedPayload` 수신. 사용자 토큰 없이 Apple 서명으로 인증하고 알림 UUID를 멱등하게 처리해요.
- 기존 `GET /api/conversations/access/`의 `used_slots`는 **활성 대화 수**로 재정의하고 잠긴 대화 수를 별도 필드로 추가해요. `GET /api/conversations/{id}/access/`와 목록 항목에 잠금·발화 가능·무료 발화 잔여값을 표현해요. 새 필드는 기존 응답에 추가하는 방식으로 버전 호환성을 확인해요.
- 대화 선택/해제 API는 기존 대화의 소유권을 확인하고 같은 계정의 활성 슬롯을 원자적으로 교체해요. 슬롯이 꽉 찬 상태에서는 교체 대상 ID를 받아 의도하지 않은 대화를 잠그지 않아요.
- 구독 원거래, 최신 확인 시각/유효 기간/상태, 알림 처리 ID에 유니크 제약과 인덱스를 둬요. 취소·환불·재결제 이력을 추적할 수 있게 최소 감사 필드를 남기되 원본 JWS와 비밀 키는 로그에 기록하지 않아요.

### Existing-Code Impact and Sequence

1. `.agent/_contracts/CONVERSATION_ACCESS.md`, `STRATEGY.md`, `docs/DSL.md`, `docs/OPERATIONS.md`, `.agent/architecture.md`의 기존 보장 슬롯·영구 grant·빈 잠금 자리 설명을 먼저 개정해요. `conversation_slot_grants`와 `legacy_conversation_slots`는 저장 기록을 보존한 채 이번 권한 계산에서 제외하고, 제거 여부는 데이터 확인 후 별도 마이그레이션으로 판단해요.
2. `backend/domains/conversation/repository.py`의 일반·추천 대화 생성, `save_user_turn`, 텍스트·음성 전송 경로를 모두 같은 권한 정책에 연결해요. 추천 시작 예약·LLM 중에는 잠금을 잡지 않고 최종 저장 직전 재검사해요.
3. 백엔드가 검증·권한·잠금을 지원하고 Flutter가 복원/잠금 UI를 제공하기 전에는 `CONVERSATION_ACCESS_ENABLED=false`를 유지해요. 정책 활성화 직전 기존 무료 계정은 최근 사용 대화 1개만 선택하도록 이행해요. 기존 `snapshot_conversation_slots.py` 실행 지침은 폐기/교체해요.
4. 운영 키·Apple In-App Purchase 서명 키(`issuer ID`, `key ID`, 개인 키), 앱 Apple ID·bundle ID, Sandbox/Production V2 알림 URL을 준비해요. 비밀 키는 서버 비밀 저장소에만 두고 앱/저장소에는 넣지 않아요. 새 설정은 `.env.example`, `docs/ENVIRONMENT.md`, `backend/config.py`를 동기화해요.

## Implementation Units

### U1. 계약·마이그레이션과 활성 대화 모델

- **Goal:** 새 무료/구독 권한과 기존 대화 잠금 정책의 단일 계약을 만들어요.
- **Requirements:** R2~R5, R9.
- **Files:** `.agent/_contracts/CONVERSATION_ACCESS.md`, `STRATEGY.md`, `docs/DSL.md`, `backend/alembic/versions/`, `backend/domains/billing/models.py`, `backend/domains/conversation/models.py`, `backend/domains/auth/models.py`, `backend/scripts/snapshot_conversation_slots.py`, `docs/OPERATIONS.md`.
- **Approach:** 문서와 DRAFT→REVIEW→ACTIVE 계약을 먼저 수정해요. 대화별 활성 선택과 구독/거래 저장 모델을 추가하되 기존 대화·grant는 삭제하지 않아요. 최근 실제 사용자 발화 시각 우선, 생성 시각·ID 순으로 동률을 해소하는 이행 절차를 작성해요.
- **Test scenarios:** 기존 대화 0/1/여러 개, 15회 초과 대화, `COMPLETED` 대화, 재실행된 이행 작업에서 기록과 정확한 활성 개수를 확인해요.
- **Verification:** Alembic upgrade/downgrade를 빈 DB와 기존 fixture DB에 적용하고 데이터 보존을 확인해요.

### U2. Apple 거래 검증과 계정 연결

- **Goal:** iOS 구매·복원을 서버에서 한 계정에만 안전하게 연결해요.
- **Requirements:** R1, R5~R7; KTD1, KTD2.
- **Files:** `backend/domains/billing/` 새 도메인, `backend/main.py`, `backend/config.py`, `.env.example`, `docs/ENVIRONMENT.md`, `docs/DSL.md`, `backend/tests/domains/billing/`.
- **Approach:** Apple 공식 서버 라이브러리로 거래 JWS·앱/환경/상품을 검증하고 현재 구독 상태를 조회해요. 원거래 ID 유니크 제약과 계정 token 비교로 이중 부여를 차단해요. 검증 실패·Apple 장애·다른 계정 복원을 구분해 응답해요.
- **Test scenarios:** 정상 Advance/Plus, 변조 JWS, 다른 bundle/환경/상품, 만료·환불 거래, 동일 거래 재전송, 두 계정의 동시 연결 경합, `appAccountToken`이 없는 구거래의 최초 연결을 확인해요.
- **Verification:** mock Apple API 단위/라우터 테스트와 PostgreSQL 유니크 제약 경합 테스트를 실행해요.

### U3. 알림·갱신·상태 조정

- **Goal:** 앱이 닫혀 있어도 갱신·취소·유예·환불을 서버 권한에 반영해요.
- **Requirements:** R5, R6; KTD3.
- **Files:** `backend/domains/billing/`, `backend/scripts/`의 재조회 작업, `backend/tests/domains/billing/`, `docs/OPERATIONS.md`.
- **Approach:** V2 signed notification을 확인한 뒤 현재 구독 상태를 다시 조회해요. 클라이언트 검증보다 먼저 온 알림은 서명된 계정 token으로 안전하게 식별되면 연결하고, 식별할 수 없으면 복원 시까지 미연결로 보관해요. 알림 UUID 멱등성과 오래된 이벤트 무해성을 보장하고, 누락 알림을 복구할 운영 재조회 작업·실패 관측을 마련해요.
- **Test scenarios:** 중복·역순 알림, 취소 후 잔여 기간, 정상 갱신, grace, billing retry, 만료, 환불/철회, Apple API 일시 오류·재시도를 확인해요.
- **Verification:** Apple Sandbox 테스트 알림과 서버 로그/DB 상태를 비교해요.

### U4. 대화 권한·선택·발화 집행

- **Goal:** 서버의 모든 생성·전송 경로에서 현재 권한과 읽기 전용 상태를 동일하게 집행해요.
- **Requirements:** R2~R5, R8; KTD4, KTD5.
- **Files:** `backend/domains/conversation/{repository,service,router,topic_router,schemas}.py`, `backend/tests/domains/conversation/`, `backend/tests/domains/voice/`, `docs/DSL.md`.
- **Approach:** 활성 대화만 슬롯으로 세고, 일반/추천 생성·텍스트/음성 발화·선택/해제를 계정 잠금 순서에 맞춰 처리해요. 만료와 상품 변경 시 최근 사용 순으로 허용 개수만 유지하고 선택 API로 교체할 수 있게 해요. 읽기·삭제는 계속 허용해요.
- **Test scenarios:** 무료 1/15 경계, Advance 5·Plus 10 경계, 저장 대화 수가 한도를 초과한 계정, 잠긴 대화의 모든 전송 경로, 슬롯 교체/해제, 추천 시작 경합, 만료와 발화 동시 요청을 확인해요.
- **Verification:** 기존 conversation/voice 회귀 테스트와 PostgreSQL 병렬 생성·교체·발화 테스트를 실행해요.

### U5. Flutter 구매·복원·paywall

- **Goal:** iOS 학습자가 실제 스토어 상품 정보를 보고 결제·복원을 완료해요.
- **Requirements:** R1, R6~R8; KTD1, KTD5.
- **Files:** `mobile/pubspec.yaml`, `mobile/lib/features/billing/` 새 feature, `mobile/lib/features/profile/presentation/profile_screen.dart`, `mobile/lib/core/copy/app_copy.dart`, `mobile/test/features/billing/`, `mobile/ios/`의 필요한 StoreKit 설정.
- **Approach:** `in_app_purchase`로 `Advance`/`Plus`를 조회해 현지화된 가격을 표시해요. 구매 시 Convia 사용자 UUID를 StoreKit의 `appAccountToken`으로 전달해요. 구매 스트림을 구독하고 검증 API가 승인한 뒤 권한을 새로 조회해요. `restorePurchases`도 동일한 검증 경로로 보내며 거래 완료 처리는 플러그인 규칙에 맞추고 중단 시 재검증해요. Android에는 구매 CTA를 숨겨요.
- **Test scenarios:** 상품 조회 실패, 구매 성공·취소·실패·중복 이벤트, 검증 중 앱 종료/재실행, 복원 성공·다른 계정 충돌, iOS/Android CTA 차이, 계정 전환 중 늦은 응답 폐기를 확인해요.
- **Verification:** Flutter 단위/위젯 테스트 후 Sandbox 실제 기기에서 구매·복원·상품 변경을 시험해요.

### U6. 실제 대화 잠금·선택 UI

- **Goal:** 잠긴 대화를 찾고 읽고 활성 대화를 바꿀 수 있게 해요.
- **Requirements:** R2~R5, R8; KTD5.
- **Files:** `mobile/lib/features/{home,history,conversation}/`, `mobile/lib/features/conversation/{data,domain}/`, `mobile/lib/core/copy/app_copy.dart`, 관련 `mobile/test/features/`.
- **Approach:** 빈 잠금 자리 대신 목록의 실제 잠긴 대화에 읽기 전용 표식과 재선택 동작을 표시해요. composer는 서버 `can_send`/잠금 이유를 따르고 15회 종료와 구독 잠금을 다르게 안내해요. 계정·앱 복귀·구독 상태 변경 시 권한을 새로 조회해요.
- **Test scenarios:** 무료 0/1/다중 대화, 15회 소진, 구독 업그레이드·만료, 잠긴 대화 읽기/삭제/선택, 오프라인 또는 권한 조회 오류, Android의 iOS 구매 권한 표시를 확인해요.
- **Verification:** Flutter 위젯 테스트와 iOS 실제 화면 동선 검증을 실행해요.

### U7. 출시 설정·문서·최종 검증

- **Goal:** 정책을 안전하게 켜고 App Store 심사에 제출할 수 있는 상태를 만들어요.
- **Requirements:** R1~R9.
- **Files:** `.env.example`, `docs/ENVIRONMENT.md`, `docs/OPERATIONS.md`, `docs/DSL.md`, `.agent/architecture.md`, `README.md`(실행 변경 시), App Store Connect의 상품 메타데이터/심사 정보.
- **Approach:** 공유 파일은 `.agent/_coordination/HANDOFF.md`에 claim하고 STATE·CHANGELOG를 갱신해요. 앱 구버전/신버전과 서버 플래그 조합을 검증한 뒤 Sandbox→TestFlight→운영 순으로 활성화해요. Advance/Plus의 실제 혜택·월간 가격·심사 스크린샷을 App Store Connect에 맞추고, 최초 구독 상품은 새 앱 버전과 함께 심사에 제출해요. 단품은 심사 대상에서 제외해요.
- **Test scenarios:** 기존 무료 다중 대화 이행, 신규/기존 구매·복원, Plus↔Advance, 자동 갱신 해지, grace/만료/환불, 알림 누락·재처리, 서버 일시 장애, Android 버튼 비노출을 end-to-end로 확인해요.
- **Verification:** 배포 환경의 알림 테스트와 TestFlight Sandbox 계정으로 실제 스토어 동선을 확인하고, 롤백 시 플래그를 꺼도 대화 기록이 남는지 점검해요.

## Verification Contract

- **백엔드:** `cd backend && uv run alembic upgrade head`, `uv run pytest -q`를 기본으로 실행하고 billing/conversation/voice 관련 테스트를 먼저 확인해요. 마이그레이션은 기존 데이터 복제본에서 보존 여부를 별도로 확인해요.
- **모바일:** `cd mobile && flutter analyze && flutter test`. StoreKit SDK 동작은 mock만으로 확정하지 않고 Sandbox/TestFlight 실기기에서 검증해요.
- **경합:** PostgreSQL에서 같은 계정의 생성·교체·전송·결제 알림 동시 요청을 재현해 1/5/10 슬롯, 15회 경계, 원거래 소유권이 깨지지 않는지 확인해요. SQLite 결과는 이 경합의 증거로 사용하지 않아요.
- **운영:** Apple Sandbox의 테스트 알림, 구매 복원, 취소 후 잔여 기간, 만료/환불, Plus↔Advance를 확인하고 서버 entitlement와 앱 표시가 일치하는지 기록해요. 가격·기간은 StoreKit 조회값을 기준으로 확인해요.
- **문서:** API·환경변수·배포 변경은 AGENTS.md §5.8의 모든 표면을 같은 작업 단위로 동기화하고, 기존 문서의 상충하는 정책을 제거해요.

## Definition of Done

- `Advance`/`Plus` 구매·복원 후 Apple 검증에 성공해야만 서버 권한이 바뀌고, 동일 원거래는 한 계정에만 연결돼요.
- 무료 1개/15회, Advance 5개/무제한, Plus 10개/무제한이 모든 대화 생성·텍스트·음성 경로에 동일하게 적용돼요.
- 만료·환불·하향 전환 시 초과 대화는 읽기 전용으로 보존되고 사용자가 활성 대화를 선택·해제할 수 있어요. 기존 다중 대화 무료 계정도 예외가 아니에요.
- iOS 결제 화면은 스토어 가격·복원·관리·약관을 제공하고 Android는 구매 CTA를 숨겨요.
- 알림 누락/중복/역순과 Apple 일시 장애의 복구 절차가 검증되고, 정책 스위치를 켜기 전 데이터 이행·Sandbox 검증·운영 문서가 끝나요.
- 구현 중 포기한 실험 코드와 오래된 ‘영구 추가 슬롯/기존 슬롯 보장’ 계약 문구를 제거해요. 보존이 필요한 기존 DB 데이터는 삭제하지 않아요.

## Appendix

### Apple/Flutter 근거

- [Apple App Store Server API](https://developer.apple.com/documentation/appstoreserverapi): 서명된 거래/현재 구독 상태/알림 이력 조회.
- [Apple Server Notifications V2](https://developer.apple.com/documentation/AppStoreServerNotifications/receiving-app-store-server-notifications): `signedPayload` 수신과 검증.
- [Apple 구독 상태 값](https://developer.apple.com/documentation/appstoreservernotifications/status): active/expired/billing retry/grace/revoked.
- [Apple appAccountToken](https://developer.apple.com/documentation/storekit/transaction/appaccounttoken): 자체 계정 UUID 연결.
- [Flutter in_app_purchase](https://pub.dev/packages/in_app_purchase): StoreKit 2, 구매 스트림, 구매 복원과 거래 완료.

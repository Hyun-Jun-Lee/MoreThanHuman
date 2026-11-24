# Conversation Access v3 — REVIEW


회원은 기본 보관 대화 1개와 계정당 한 번 발급되는 체험 10턴을 받아요. 게스트의 활성 대화 1개·누적 5회는 별도 원장이며 회원 전환 시 사용량을 합산하지 않아요. 관리자는 무제한이에요. 회원 제한 rollout은 `CONVERSATION_ACCESS_ENABLED=false`가 기본이며 게스트 제한은 항상 적용해요.

슬롯은 보관 대화와 진행 중 역할극 시작 예약을 합쳐 새 생성에만 검사해요. 기존 회원 대화는 잠그지 않아요. 환불로 한도를 초과해도 기존 대화는 계속 이용하고 새 생성만 차단해요. 삭제는 슬롯만 비우며 사용한 턴을 반환하지 않아요. 진행 중 스트림 삭제는 409 `TURN_IN_PROGRESS`예요.

한 턴은 사용자 메시지 1개와 저장된 AI 텍스트 답변 1개예요. 체험 lot을 먼저, 이후 구매·수동 lot을 생성 순서대로 사용해요. profile 잠금 안에서 예약하고 AI 텍스트와 같은 트랜잭션에서 확정해요. 실패·5분 만료는 반환하고, 텍스트 저장 뒤 TTS 실패는 차감을 유지해요. 환불된 lot은 새 예약을 막으며 기존 예약은 성공하면 확정, 실패하면 무효화해요. 고정 역할극 인사·저장된 추천 첫 질문·다시 듣기는 차감하지 않아요. 음성은 STT 전 사전 검사와 저장 전 최종 검사를 거쳐요.

| Product ID | 유형 | 지급 |
|---|---|---|
| `com.morethanhuman.curitalk.slots.plus.1` | CONSUMABLE | 추가 대화 +1 |
| `com.morethanhuman.curitalk.slots.plus.3` | CONSUMABLE | 추가 대화 +3 |
| `com.morethanhuman.curitalk.turns.5` | CONSUMABLE | 답변 5회 |
| `com.morethanhuman.curitalk.turns.10` | CONSUMABLE | 답변 10회 |
| `com.morethanhuman.curitalk.turns.20` | CONSUMABLE | 답변 20회 |

- `GET /api/billing/entitlement/`: `plan=member|guest|admin`, `status`, `slot_limit`, `additional_slots`, `remaining_turns`, `trial_turns`, `paid_turns`, `unlimited`, `is_admin`, `source`, `turn_scope=account`, `limit_action`를 반환해요. 회원의 기존 호환 필드 `turn_limit`, `expires_at`은 null이에요. 게스트는 `turn_limit=5`예요.
- `GET /api/conversations/access/`: `enabled, can_create, used_slots, slot_limit, remaining_slots, locked_count, plan, turn_scope, remaining_turns, trial_turns, paid_turns, limit_action`을 반환해요. 회원의 `locked_count`는 0이에요.
- `GET /api/conversations/{id}/access/`: `enabled, user_turns, turn_limit, can_send, locked, turn_scope, remaining_turns, limit_action`을 반환해요. 회원의 `locked`는 false이며 `user_turns`는 해당 대화 메시지 수로 잔액이 아니에요.
- 부족 오류는 HTTP 409 `CONVERSATION_SLOTS_FULL`+`limit_action=buy_slots` 또는 `CONVERSATION_TURNS_FULL`+`buy_turns`예요. 게스트는 `GUEST_TURNS_FULL`+`login`이에요.
- `POST /api/billing/apple/verify/`: 회원 Bearer와 `{signed_transaction: JWS}`. 앱·환경·상품·소비성 유형·수량·계정 토큰을 검증하고 거래 ID별 한 번만 지급해요. 응답은 권한과 `delivery_status`, `terminal=true`예요. 삭제·환불 tombstone은 잔액 없는 terminal 응답을 반환할 수 있어요.
- `POST /api/billing/apple/terminalize/`: Bearer 없이 JWS를 제출해요. 삭제된 account token과 일치할 때만 `{delivery_status: deleted, terminal: true}`를 반환해요. 활성 계정에는 지급·종료하지 않아요.
- 다른 계정은 409 `PURCHASE_ACCOUNT_CONFLICT`, 잘못된 거래는 400 `INVALID_APPLE_PURCHASE`예요. 앱은 재시도 가능한 오류에서는 StoreKit 거래를 완료하지 않아요. 서버의 terminal 결과를 보존한 뒤에만 완료해요.
- `POST /api/billing/apple/notifications/`: `{signedPayload}`의 서명과 UUID를 검증해요. REFUND는 해당 거래의 슬롯 또는 lot 미사용분만 회수해요. 먼저 도착한 환불은 `refund-before-delivery`로 보존해요. CONSUMPTION_REQUEST는 감사 기록만 저장하며 소비 정보는 전송하지 않아요.

소비성 구매 복원 API·UI는 제공하지 않아요. 같은 tomatalk 계정의 재설치·기기 변경은 서버 잔액을 조회해요. 계정 삭제·재가입·다른 계정에는 과거 구매를 복원하거나 이전하지 않아요. 삭제 후 원문 구매·계정 ID 대신 버전형 HMAC tombstone을 보존해 재지급을 차단해요.

자체 지원 환불 검토는 턴 lot의 확정 사용이 0회이거나 슬롯 거래의 `first_used_at`이 없을 때만 가능해요. 첫 정상 사용자 답변 저장 시 그 전에 지급된 모든 미사용 슬롯 거래에 사용 시각을 기록하며 삭제로 되돌리지 않아요. Apple의 환불 심사는 별개이며 확정 환불은 사용 여부와 무관하게 반영해요.


운영 활성화 전 수동 검증은 [운영 가이드](../../docs/OPERATIONS.md#대화-이용-권한-활성화)를 따라요.

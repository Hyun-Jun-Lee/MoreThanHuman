# Conversation Access v1 — ACTIVE

권한 정책의 코드 기본값은 비활성화예요. 개발 환경에서는 `CONVERSATION_ACCESS_ENABLED=true`로 제한과 잠금 UI를 함께 시험해요. `false` 동안 기존 대화 생성·전송 동작을 유지하고 모바일은 잠금 자리를 표시하지 않아요. 가격과 실제 구매 플로우는 이 계약의 범위 밖이에요.

## Rules

- 무료 계정의 기본 동시 보유 한도는 대화 1개예요. `ACTIVE`와 `COMPLETED`를 모두 세고 삭제하면 슬롯을 다시 사용해요.
- 정책 활성화 직전 기존 계정의 보유 개수를 `legacy_conversation_slots`에 저장해요. 기본 한도는 `max(1, legacy_conversation_slots)`예요. 삭제해도 이 값은 유지해요.
- 검증된 영구 단품 구매 1건은 동시 보유 한도를 1칸 늘려요. 구매 검증·복원·환불은 결제 구현 시 추가해요.
- 무료 플랜의 각 대화는 사용자 발화 15회를 허용해요. 자유 대화의 첫 발화는 1회, 역할극의 AI 첫 인사는 0회예요. 이미 15회를 넘긴 대화도 읽기는 가능하지만 정책 활성화 후 추가 발화를 막아요.
- 대화 목록의 실제 항목은 잠기지 않아요. 잠금은 존재하지 않는 추가 대화 자리의 UI 표현이에요.

## API

- `GET /api/conversations/access/`는 `enabled`, `can_create`, `used_slots`, `slot_limit`, `remaining_slots`를 반환해요. 비활성화 상태의 `slot_limit`·`remaining_slots`는 `null`이에요.
- `GET /api/conversations/{id}/access/`는 `enabled`, `user_turns`, `turn_limit`, `can_send`를 반환해요. 비활성화 상태의 `turn_limit`은 `null`이에요.
- 한도를 넘긴 새 대화 생성은 HTTP 409, 코드 `CONVERSATION_SLOTS_FULL`, 추가 발화는 HTTP 409, 코드 `CONVERSATION_TURNS_FULL`로 거절해요. 기존 대화의 읽기·삭제는 허용해요.
- 클라이언트는 서버 권한값을 사용하고 플랜 이름만으로 잠금 여부를 추론하지 않아요.

## Activation

Alembic migration 후 정책을 켜기 직전에 기존 보유 개수를 스냅샷하는 CLI를 실행해요. 이미 스냅샷한 보장 슬롯은 재실행으로 줄이지 않아요. 스냅샷과 스위치 전환 사이에는 대화 생성·삭제를 잠시 멈춰야 해요. 개발 환경의 UI 확인에는 결제 없이 스위치를 켤 수 있어요. 운영에서는 결제 기능, 구매 복원 경로, 유료 플랜별 권한 판정이 준비되기 전에는 스위치를 켜지 않아요.

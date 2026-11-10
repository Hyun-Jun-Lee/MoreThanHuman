# Conversation Access v2 — REVIEW

구독과 대화 권한의 서버 계약이에요. `CONVERSATION_ACCESS_ENABLED=false`가 기본값이며, 결제 검증·구매 복원·모바일 잠금 UI·기존 대화 이행을 확인한 뒤 운영에서 켜요.

## 상품과 권한

- Apple 자동 갱신 월간 구독 제품 ID는 `Advance`, `Plus`예요. 같은 구독 그룹(`22439301`, 참조명 `ttm_scbscribe`)에 속해요. 가격은 App Store Connect에서 정하고 앱은 스토어 가격을 표시해요.
- 무료: 동시 활성 대화 1개, 활성 대화당 사용자 발화 15회. Advance: 동시 활성 대화 5개, 발화 무제한. Plus: 동시 활성 대화 10개, 발화 무제한. `ACTIVE`·`COMPLETED` 대화 모두 활성 슬롯을 사용해요.
- 저장된 대화의 총수는 제한하지 않아요. 비활성 대화는 앱에서 열 수 없고 목록에서 활성화하거나 삭제할 수 있어요. 서버의 메시지 조회 API는 기존 읽기 권한을 유지하며, 비활성 대화의 발화는 거절해요. 비활성 대화는 생성 슬롯을 차지하지 않아요. 활성 대화를 교체하거나 해제해 새 대화를 시작할 수 있어요.
- 기존 다중 대화 무료 계정은 최근 실제 사용 대화 1개만 활성화하고 나머지는 잠가요. 무료 대화의 누적 사용자 발화 수는 초기화하지 않아요. 사용자가 남길 대화를 다시 선택할 수 있어요.
- 구독 해지는 확인된 만료 시각까지 혜택을 유지해요. Apple이 확인한 billing grace 상태는 유효 기간까지 유지하고, 만료·환불·철회 시 유효 플랜의 슬롯 수만 활성 상태로 남겨요. Plus에서 Advance로 변경되면 5개 한도를 적용해요.
- 추가 슬롯 소모성 상품과 Plus 전용 후속 혜택은 이 계약의 범위 밖이에요. 기존 `legacy_conversation_slots`와 `conversation_slot_grants`는 데이터로 보존하되 새 권한 계산에서 제외해요.

## 구매 신뢰 경계

- Flutter의 구매 성공 이벤트만으로 혜택을 부여하지 않아요. 인증된 검증 API가 Apple 서명 거래와 현재 구독 상태를 확인해요.
- 원거래 ID는 한 tomatalk 계정에만 연결해요. 구매 시 tomatalk 사용자 UUID를 Apple `appAccountToken`으로 전달해요. 다른 계정의 복원은 기존 소유자 권한을 유지하고 두 번째 계정에는 혜택을 주지 않아요.
- Apple Server Notifications V2는 서명된 payload를 검증해요. 중복·역순 이벤트는 현재 Apple 상태 재조회로 조정하고, 알림 누락에 대비해 재조회 작업을 운영해요.
- Apple 로그인은 구매의 필수 조건이 아니에요. iOS에서 로그인한 Google/Apple tomatalk 계정 모두 구매할 수 있어요. Android 구매 UI는 숨기지만 같은 tomatalk 계정의 서버 권한은 적용해요.
- 추가 대화 잠금 안내 팝업은 주간 주제 시작 확인 팝업과 같은 높이로 표시해요. 슬롯 해제 위치는 현재 화면 제목인 `Conversations`(대화 목록)로 안내하고, iOS에서는 `SUBSCRIPT` 버튼으로 구독 화면으로 이동할 수 있어요.
- iOS 구독 화면에서 구매 복원을 누르면 확인 중 안내를 모달 팝업으로 표시해요. 서버 검증 결과가 오면 같은 팝업을 성공·실패 안내로 갱신하고, 확인 중 팝업을 닫은 뒤 도착한 결과는 다시 팝업으로 안내해요. 복원 상태 문구는 구독 버튼 위에 표시하지 않아요.
- 내 정보 화면은 구독 권한 조회가 완료되기 전이나 실패했을 때 Free 플랜으로 단정하지 않아요. 조회 중에는 구독 배지에 제공된 토마토 GIF 로딩과 확인 중 문구를 표시하고, 실패 시 조회 실패를 표시해요. Free는 서버가 반환한 플랜이 Free일 때만 표시해요.
- 홈과 대화 목록의 잠긴 항목은 대화 화면으로 이동하지 않아요. 화면 주소로 직접 진입할 때도 대화별 최신 권한을 확인한 뒤 잠겨 있으면 메시지 화면을 만들지 않고 잠금 안내를 표시해요. 권한 조회 실패 시에도 메시지를 표시하지 않아요.

## API

- `GET /api/billing/entitlement/`: 현재 `plan`, `status`, 만료 시각, 슬롯·발화 한도를 반환해요.
- `POST /api/billing/apple/verify/`: 구매·복원 거래를 같은 멱등 경로로 검증해요.
- `POST /api/billing/apple/notifications/`: Apple 서명 notification을 수신해요.
- `GET /api/conversations/access/`: `used_slots`는 활성 대화 수, `locked_count`는 비활성 대화 수예요. `slot_limit`은 현재 플랜 한도예요.
- `GET /api/conversations/{id}/access/`와 목록 항목: 잠금 상태와 `can_send`, 무료 발화 수·한도를 표시해요.
- 대화 선택·해제 API는 소유권을 확인하고 원자적으로 활성 슬롯을 교체해요. 잠긴 대화에 대한 전송은 HTTP 409 `CONVERSATION_LOCKED`, 슬롯 초과는 `CONVERSATION_SLOTS_FULL`, 무료 15회 초과는 `CONVERSATION_TURNS_FULL`이에요.

## 활성화

새 migration과 앱 버전을 배포하고 기존 대화 선택을 이행해요. Sandbox 구매·복원·만료·환불과 PostgreSQL 동시 요청을 검증하기 전에는 운영의 `CONVERSATION_ACCESS_ENABLED`를 켜지 않아요. 구버전 클라이언트의 접근이 남아 있으면 서버가 모든 생성·전송 경로를 계속 집행해요.

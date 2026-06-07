# 모바일 UX 메모

> 향후 Flutter 기반 모바일 앱을 위한 제품 메모 · 최종 갱신: 2026-06-07

## 1. 핵심 경험

사용자는 모바일 앱에서 원하는 주제나 상황을 고르고 AI와 영어로 대화해요. 백엔드는 대화 응답, 문법 피드백, 검색 컨텍스트, 학습 통계를 API로 제공해요.

## 2. 대화 흐름

권장 흐름:

1. 앱이 로그인 상태를 확인해요.
2. 사용자가 자유 대화 또는 롤플레이를 선택해요.
3. 자유 대화에서는 관심 주제를 입력하고 `POST /api/search/topic-prep/`로 준비 카드를 만들어요.
4. 앱은 준비 카드의 요약, 4개 대화 방향, 선택 방향의 첫 질문 3개를 보여줘요.
5. 사용자가 첫 질문 하나를 선택하고 답변하면 `POST /api/conversations/start/free-chat/`로 대화를 시작해요.
6. 롤플레이는 `POST /api/conversations/start/roleplay/`로 대화를 시작해요.
7. 응답의 `message_id`로 문법 피드백을 polling해요.
8. 이후 메시지는 `POST /api/conversations/{id}/message/`로 이어가요.

### 모바일 v1 인증 결정

- Google 로그인은 Flutter Google Sign-In SDK로 `id_token`을 받은 뒤 서버가 검증해 자체 `access_token`/`refresh_token`을 발급하는 방식을 우선해요.
- 서버 callback이 JSON으로 token pair를 반환하는 기존 OAuth 흐름은 Swagger/웹 확인용으로 유지할 수 있지만, 모바일 앱의 기본 로그인 플로우로 쓰지 않아요.
- 앱은 `device_id`를 설치 단위 UUID로 생성해 secure storage에 저장하고, Google 로그인 token 교환 요청에도 함께 전달해요.

### 모바일 v1 문법 피드백 결정

- 문법 피드백은 SSE보다 polling을 우선해요.
- 앱은 대화 응답의 `message_id`를 기준으로 `GET /api/grammar/message/{message_id}/`를 짧은 간격으로 재시도해요.
- `404`는 “아직 문법 피드백 생성 중” 상태로 처리하고, 일정 시간 이후에도 없으면 timeout 상태를 보여줘요.
- SSE 엔드포인트는 당장 제거하지 않고, 실시간성이 필요해질 때 선택적으로 다시 검토해요.

## 3. 모바일 앱에서 필요한 상태

| 상태 | 설명 |
|------|------|
| 인증 상태 | access token, 사용자 프로필, 토큰 만료 처리 |
| 대화 상태 | conversation id, title, type, role character |
| 메시지 상태 | user/assistant 메시지, 전송 중/성공/실패 |
| 문법 피드백 상태 | pending/completed/timeout/error |
| 검색 상태 | query, summary, source 목록 |
| 주제 준비 카드 상태 | topic, summary, directions, selected direction, selected question, quality, retry guidance |

## 4. 백엔드 API 관점의 UX 리스크

| 리스크 | 대응 |
|--------|------|
| 모바일 네트워크에서 SSE 연결이 끊김 | 모바일 v1은 polling 우선 |
| LLM 응답 지연 | 앱에서 전송 중 상태와 취소 흐름 제공 |
| 문법 피드백이 늦게 도착 | 메시지별 pending 상태 분리 |
| 토큰 만료 | refresh token 또는 재로그인 흐름 설계 |
| 검색/LLM 외부 API 실패 | 사용자에게 재시도 가능한 오류로 노출 |
| 주제 준비 카드 검색 품질 부족 | 더 구체적인 주제 예시를 보여주고 재입력 유도 |

## 5. 향후 API 후보

- `POST /api/auth/google/mobile`
- `GET /api/conversations/{conversation_id}/messages/?cursor=...`
- `POST /api/conversations/{conversation_id}/cancel-current-response`
- `GET /api/me/learning-summary`

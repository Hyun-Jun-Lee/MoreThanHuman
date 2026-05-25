# 모바일 UX 메모

> 향후 Flutter 기반 모바일 앱을 위한 제품 메모 · 최종 갱신: 2026-05-25

## 1. 핵심 경험

사용자는 모바일 앱에서 원하는 주제나 상황을 고르고 AI와 영어로 대화해요. 백엔드는 대화 응답, 문법 피드백, 검색 컨텍스트, 학습 통계를 API로 제공해요.

## 2. 대화 흐름

권장 흐름:

1. 앱이 로그인 상태를 확인해요.
2. 사용자가 자유 대화 또는 롤플레이를 선택해요.
3. 필요하면 `POST /api/search/`로 주제 컨텍스트를 만들어요.
4. `POST /api/conversations/start/free-chat/` 또는 `/roleplay/`로 대화를 시작해요.
5. 응답의 `message_id`로 문법 피드백 스트림을 구독해요.
6. 이후 메시지는 `POST /api/conversations/{id}/message/`로 이어가요.

## 3. 모바일 앱에서 필요한 상태

| 상태 | 설명 |
|------|------|
| 인증 상태 | access token, 사용자 프로필, 토큰 만료 처리 |
| 대화 상태 | conversation id, title, type, role character |
| 메시지 상태 | user/assistant 메시지, 전송 중/성공/실패 |
| 문법 피드백 상태 | pending/completed/timeout/error |
| 검색 상태 | query, summary, source 목록 |

## 4. 백엔드 API 관점의 UX 리스크

| 리스크 | 대응 |
|--------|------|
| 모바일 네트워크에서 SSE 연결이 끊김 | polling fallback API 검토 |
| LLM 응답 지연 | 앱에서 전송 중 상태와 취소 흐름 제공 |
| 문법 피드백이 늦게 도착 | 메시지별 pending 상태 분리 |
| 토큰 만료 | refresh token 또는 재로그인 흐름 설계 |
| 검색/LLM 외부 API 실패 | 사용자에게 재시도 가능한 오류로 노출 |

## 5. 향후 API 후보

- `POST /api/auth/refresh`
- `GET /api/grammar/message/{message_id}/status`
- `GET /api/conversations/{conversation_id}/messages/?cursor=...`
- `POST /api/conversations/{conversation_id}/cancel-current-response`
- `GET /api/me/learning-summary`

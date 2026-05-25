# 서비스·기술 피드백

> 범위: FastAPI 백엔드 API · 향후 클라이언트: Flutter 모바일 앱 · 최종 갱신: 2026-05-25

## 1. 제품 방향

MoreThanHuman (Convia)는 AI 기반 영어 회화 학습 플랫폼이에요. 현재 저장소는 백엔드 API를 담당하고, 사용자 경험은 향후 Flutter 모바일 앱에서 구현해요.

핵심 가치는 아래예요.

- 사용자가 고른 주제로 영어 대화를 시작할 수 있어야 해요.
- 자유 대화와 롤플레이를 모두 지원해야 해요.
- 사용자 발화에 대한 문법 피드백을 대화 흐름과 분리해 비동기로 제공해야 해요.
- 검색 결과를 대화 컨텍스트로 활용할 수 있어야 해요.
- 학습 기록과 문법 통계를 사용자별로 관리해야 해요.

## 2. 현재 구현된 백엔드 표면

| 영역 | 상태 | 대표 API |
|------|------|----------|
| 인증 | 구현 | `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me` |
| Google OAuth | 구현 | `GET /api/auth/google/login`, `GET /api/auth/google/callback` |
| 자유 대화 | 구현 | `POST /api/conversations/start/free-chat/` |
| 롤플레이 | 구현 | `POST /api/conversations/start/roleplay/` |
| 메시지 전송 | 구현 | `POST /api/conversations/{id}/message/` |
| 대화 관리 | 구현 | 목록, 상세, 메시지 목록, 제목 수정, 종료, 삭제 |
| 문법 체크 | 구현 | `POST /api/grammar/check/` |
| 문법 피드백 스트림 | 구현 | `GET /api/conversations/messages/{id}/grammar-feedback/stream` |
| 문법 통계 | 구현 | `GET /api/grammar/stats/` |
| 검색 요약 | 구현 | `POST /api/search/` |
| LLM provider | 구현 | OpenRouter, Ollama |

## 3. 모바일 앱 연동 시 주의점

### 인증

Flutter 앱은 `Authorization: Bearer <access_token>` 헤더를 기본 인증 방식으로 사용해야 해요. SSE처럼 헤더 전달이 까다로운 클라이언트 API를 사용할 경우에만 토큰 쿼리 파라미터를 제한적으로 사용해요.

### 문법 피드백

대화 응답은 즉시 반환하고 문법 피드백은 백그라운드에서 생성해요. 모바일 앱은 `message_id`를 저장한 뒤 SSE 스트림 또는 향후 대체 polling API로 피드백을 가져오는 흐름을 가져야 해요.

### 검색

검색은 DuckDuckGo 결과를 LLM으로 요약해 `search_context`에 넣을 수 있는 텍스트를 생성해요. 검색 결과 원문 전체를 장기 저장하지 않고, 대화 시작 전 컨텍스트로 사용하는 방식이 현재 구조에 맞아요.

### 사용자 데이터 분리

대화와 메시지는 `user_id` ownership을 기준으로 접근을 제한해요. 모바일 앱은 사용자 전환, 로그아웃, 토큰 만료 시 로컬 캐시를 명확히 분리해야 해요.

## 4. 백엔드 개선 후보

| 우선순위 | 개선 | 이유 |
|----------|------|------|
| 높음 | refresh token 도입 | 모바일 앱 장기 세션 관리에 필요 |
| 높음 | SSE 대체 polling API 검토 | 모바일 네트워크 환경에서 안정성 확보 |
| 중간 | conversation/message pagination 응답 메타 추가 | 모바일 무한 스크롤 구현 편의 |
| 중간 | grammar feedback 상태 API 추가 | pending/completed/failed 상태 표시 |
| 중간 | LLM provider 장애 fallback 정책 명시 | OpenRouter/Ollama 장애 대응 |
| 낮음 | 검색 결과 캐싱 | 반복 검색 비용과 지연 감소 |

## 5. 문서 동기화 체크리스트

API 변경 시 아래를 함께 갱신해요.

- `README.md`
- `docs/DSL.md`
- 해당 `backend/domains/*/router.py`

환경변수 변경 시 아래를 함께 갱신해요.

- `.env.example`
- `README.md`
- `backend/config.py`

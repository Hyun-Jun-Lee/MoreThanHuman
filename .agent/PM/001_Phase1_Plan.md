# 001 — Phase 1 개발 계획

> 프로젝트: MoreThanHuman (Convia) · 작성일: 2026-05-20

---

## 트리거

초기 제품 백로그 우선순위 기반 + 인증 시스템 구현 진행 중 (`backend/domains/auth/`)

---

## Phase 1 체크리스트

### 🔴 즉시 (P1-A)

- [ ] 대화 응답 SSE 스트리밍 추가 (`/api/conversations/{id}/message/stream`)
- [ ] MAX\_TOKENS 조정 + 시스템 프롬프트에 응답 길이 명시

### 🟡 배포 전 (P1-B)

- [ ] 인증 시스템 완성 (JWT + 사용자별 대화 격리)
  - `backend/domains/auth/` 구현 진행 중
  - Conversation 모델에 `user_id` FK 추가
  - 모든 API에 인증 미들웨어 적용
- [ ] 콘텐츠 필터링 레이어 (검색 쿼리 필터)
- [ ] 페이지네이션 응답에 `total` 필드 추가
- [ ] DuckDuckGo 검색 실패 graceful fallback

### 🟢 이후 (P1-C)

- [ ] `asyncio.create_task` → BackgroundTasks 또는 task queue 교체
- [ ] per-conversation 레벨 설정 (beginner/intermediate/advanced)
- [ ] AI 페르소나 설계
- [ ] 월간 리포트 카드

---

## 성공 기준

- 인증된 사용자만 자신의 대화에 접근 가능
- 대화 응답 첫 토큰 표시까지 2초 이내 (SSE 스트리밍)
- 검색 실패 시에도 대화가 정상 진행

---

## 리스크 완화

| 리스크 | 영향 | 완화 |
|--------|------|------|
| DB 스키마 변경 (user\_id 추가) | 기존 데이터 마이그레이션 필요 | SQLAlchemy migration 스크립트 작성 |
| SSE 스트리밍 + 문법 체크 동시 처리 | 복잡도 증가 | 대화 SSE와 문법 SSE를 별도 엔드포인트로 분리 (현행 유지) |
| LLM 프로바이더별 스트리밍 API 차이 | 추상화 레이어 수정 | LLMProvider에 `stream()` 메서드 추가 |

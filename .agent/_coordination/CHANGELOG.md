# CHANGELOG — 완료된 작업 기록

## 2026-05-20

- **AI Native 마이그레이션**: EstreGenesis v1.6.0 기반 `.agent/` 스캐폴딩 + `AGENTS.md` SSoT 생성 (Migration A)

## 2026-05-25

- **문서 최신화**: 백엔드 API + 향후 Flutter 모바일 앱 기준으로 `AGENTS.md`, 아키텍처, README, DSL, 피드백 문서 정리

## 2026-05-26

- **Refresh token 계약 확정**: `README.md`, `docs/DSL.md`에 refresh token + `device_id`(installation ID) 기반 인증 계약 반영
- **Refresh token 구현(초안)**: refresh token 발급/rotate, `device_id` 기반 1세션 정책, Google OAuth `state`에 `device_id` 전달
- **문서 정리 원칙 확정**: `README.md`/`docs/DSL.md`/`.agent/architecture.md`를 핵심 축으로 유지하고 임시 plan/feedback 문서를 제거
- **Pagination 메타 도입**: conversation/message 목록 API를 `results/pagination` 응답 구조와 정확 count 메타로 확장

## 2026-05-27

- **제품 전략 작성**: Convia의 핵심 문제, 접근, 사용자, 지표, 작업 트랙을 `STRATEGY.md`에 정리
- **주제 준비 카드 기획**: 대화 전 주제 준비 카드 요구사항을 `docs/brainstorms/2026-05-27-topic-prep-card-requirements.md`에 정리
- **주제 준비 카드 구현 계획**: 검색 품질 gate, 준비 카드 API, 대화 handoff, 모바일 연동 계약 구현 계획을 `docs/plans/2026-05-27-001-feat-topic-prep-card-plan.md`에 정리

## 2026-05-28

- **주제 준비 카드 계획 조정**: 웹 UI 범위를 제외하고 백엔드 API + Flutter 모바일 연동 계약 중심으로 구현 계획 수정
- **주제 준비 카드 백엔드 구현**: 검색 품질 gate, 준비 카드 API, 자유 대화 handoff, 모바일 계약 문서, pytest 커버리지 추가

## 2026-06-03

- **Swagger 개발 토큰 API 추가**: `ENV=dev`에서만 동작하는 `/api/auth/dev/token`과 문서/테스트 추가
- **검색 품질 파이프라인 구현 계획**: `ddgs` 전환, 검색 쿼리 보강, relevance score, LLM 품질 판단 조합 계획 작성
- **검색 품질 계획 보정**: rule 기반 핵심어 추출, 날짜 주입 정책, 모바일-first API 계약 전제를 계획에 반영
- **LLM output invariant learning 문서화**: `docs/solutions/`와 `CONCEPTS.md`에 topic prep ready 검증 패턴 기록

## 2026-06-04

- **검색 품질 계획 보정**: 검색 품질 파이프라인 계획에 hybrid query analysis, LLM query analyzer fallback, 날짜 주입 정책을 반영
- **검색 품질 파이프라인 구현**: ddgs adapter, hybrid query analysis, relevance filter, LLM quality judge, API 계약/테스트 반영
- **검색 LLM 진단 로그 추가**: query analysis, quality judge, summarization 단계별 로그와 fallback stack trace를 추가
- **OpenRouter 기본 provider 통일**: `.env`, `.env.example`, 설정 기본값, 환경변수 문서를 OpenRouter 우선으로 정리

## 2026-06-05

- **LLM source judge 리팩터링 계획**: deterministic relevance score 중심 필터를 LLM source selection 중심으로 바꾸는 후속 구현 계획 작성
- **LLM source judge 리팩터링 구현**: deterministic relevance score를 최종 판단에서 제거하고 LLM accepted sources 기반 검색 품질 판정으로 전환
- **LLM source judge 응답 보정**: 숫자 rating과 rejected source id 배열을 parser에서 정규화하고 curl 재검증으로 `ready=true` 확인
- **모바일 인증/피드백 결정 문서화**: Flutter Google SDK 기반 OAuth와 문법 피드백 polling 우선 결정을 README, DSL, UX, architecture 문서에 반영
- **문법 피드백 polling 계획 작성**: 기존 grammar feedback 조회 endpoint를 모바일 polling 계약으로 공식화하는 구현 계획 추가

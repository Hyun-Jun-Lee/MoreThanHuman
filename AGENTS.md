# AGENTS.md — Single Source of Truth

> **프로젝트**: MoreThanHuman (서비스명: tomatalk)
> **서비스**: AI 기반 영어·한국어 회화 학습 플랫폼
> **시드 버전**: EstreGenesis v1.6.0
> **마이그레이션일**: 2026-05-20

---

## 1. 읽기 순서

모든 AI 에이전트는 아래 순서로 문서를 읽어야 해요:

1. `AGENTS.md` (이 파일 — SSoT)
2. `.agent/rules.md` (코딩·문서·git·협업 정책)
3. `.agent/architecture.md` (시스템 아키텍처·스택·데이터 플로우)
4. `.agent/_coordination/STATE.md` (현재 진행 중인 작업)
5. `.agent/_contracts/` (현재 작업 영역과 관련된 인터페이스 계약)
6. `README.md` (서비스 소개·실행 방법·CLI, 상세 문서 진입점)
7. `docs/DSL.md` (도메인 DSL 명세)

**스코프 루트**: `.agent/`

---

## 2. 역할

| 역할 | 설명 |
|------|------|
| **Lead** | 아키텍처 결정, 코드 리뷰, 머지 승인 |
| **Backend** | FastAPI 도메인 개발 (conversation, grammar, search, auth, llm) |
| **Mobile** | `mobile/` Flutter 기반 iOS·Android 앱 개발 |

---

## 3. AI 서비스 브릿지

| 서비스 | 브릿지 파일 | 비고 |
|--------|-----------|------|
| Claude Code | `.claude/rules/bridge.md` | PreToolUse 훅 지원 |
| Codex | `AGENTS.md` | 저장소 진입 시 직접 참조 |

각 AI 서비스는 이 `AGENTS.md`를 공통 SSoT로 사용해요.

---

## 4. 코디네이션 프로토콜

멀티에이전트 동시 접근 시:

1. **작업 시작**: `.agent/_coordination/STATE.md`에 에이전트명·태스크·상태 기록
2. **공유 파일 편집**: `.agent/_coordination/HANDOFF.md`에 claim 먼저
3. **질문**: `.agent/_questions/open/YYYY-MM-DD_FROM-to-TO_NNN.md`
   - 🔴 24h blocker · 🟡 72h soon · 🟢 다음 주기
4. **인터페이스 변경**: `.agent/_contracts/NAME.md` (DRAFT → REVIEW → ACTIVE)
5. **완료**: `.agent/_coordination/CHANGELOG.md`에 1줄 기록하고 최근 2개만 유지, STATE.md에서 제거

**공유 파일 목록** (편집 전 반드시 HANDOFF claim):
- `backend/database.py`, `backend/config.py`, `backend/main.py`
- `backend/shared/*`
- `.env.example`
- `README.md`

---

## 5. 핵심 규칙

**5.1** 작업 언어: 한국어 · 말투: \~에요/예요 체 · 페이스 모드: Proactive 5\~6×

**5.2** 공유 계약·운영 방식이 바뀌면 구현과 같은 작업 단위에서 기준 문서를 갱신해요. 일상적인 구현마다 별도 계획 문서를 만들지는 않아요.

**5.3** `.agent/_lessons/`가 예상 밖 블로커를 기록. 새 태스크 전 관련 태그로 grep.

**5.4** 인덱스 ↔ 본문 동기화: 본문 추가/재명명/폐기/재작성 시 그 문서를 가리키는 모든 인덱스를 같은 커밋에 갱신.

**5.5** 외부 표면 N-way sync: 한 기능이 N개 외부 표면에 묘사될 때 같은 작업 단위로 갱신; 모든 표면의 changelog/version bump.

**5.6** 마크다운 `\~` escape: GFM이 단일 `\~` 두 개를 취소선으로 짝지움. 본문의 단일 `\~`는 `\~`로 escape.

**5.7** 작업 분해 전략: 작업에 분해 경로가 여러 개일 때, 1줄 announce → 판단/관성에 따라 진행 → 사용자 피벗 프롬프트 즉시 반영. Claude Code는 `Agent` tool 다중 호출 병렬.

**5.8 N-way sync 등록부**

| 기능 | 표면 목록 |
|------|----------|
| API 엔드포인트 | `docs/DSL.md` · `backend/domains/*/router.py` |
| 환경변수 | `.env.example` · `docs/ENVIRONMENT.md` · `backend/config.py` |
| 실행·CLI·배포 | `README.md` · `docs/OPERATIONS.md` · 해당 스크립트/Compose 설정 |

**5.9** agent-time 추정: 페이스 모드 Proactive 5\~6× 적용. 실행 중심 작업은 모드 상단, 디버깅은 중간, 연구/전략은 \~1× (인간 검토가 율속). `.agent/_lessons/`의 `estimation` 태그로 ±30%+ delta만 기록·보정.

**5.10** 문서 구조 원칙: `README.md`는 서비스 소개·실행 방법·CLI와 상세 문서 링크만 간결하게 유지해요. API 계약은 `docs/DSL.md`, 환경변수 설명은 `docs/ENVIRONMENT.md`, 배포·cron·복구는 `docs/OPERATIONS.md`, 내부 구조는 `.agent/architecture.md`를 단일 기준으로 삼아요. README에 상세 계약·설정 전체 표를 중복하지 않으며 실행에 영향을 주는 변경만 요약 반영해요.

**5.11** 임시 문서 정리: 계획·브레인스토밍·피드백 메모는 필요한 동안만 사용하고, 구현이 끝나면 결정 사항을 기준 문서와 테스트에 흡수한 뒤 삭제해요.

---

## 6. 클라이언트 방향

- 현재 저장소는 `backend/` FastAPI API와 `mobile/` Flutter 앱을 함께 관리해요.
- 사용자 앱은 Flutter 기반 iOS·Android 클라이언트로 개발해요.
- 이 SSoT는 백엔드 API, 모바일 앱, 두 영역의 연동 계약을 다뤄요.

---

## 7. 커밋 형식

```
<type>: <subject>

[optional body]
```

- **타입**: feat, fix, refactor, docs, test, chore, style, perf
- **제목**: 명확하고 간결하게 (50자 이내)
- **본문**: 필요시 상세 설명
- **금지**: Co-Authored-By, Generated with Claude Code 등 AI 생성 표기

---

## 8. 참조

| 문서 | 경로 | 설명 |
|------|------|------|
| 프로젝트 README | `README.md` | 서비스 소개·실행법·CLI·상세 문서 진입점 |
| 환경변수 | `docs/ENVIRONMENT.md` | 전체 설정·필수 여부·기본값 |
| 운영 가이드 | `docs/OPERATIONS.md` | 배포·주간 작업·장애 대응·복구 |
| DSL 명세 | `docs/DSL.md` | 도메인별 상세 스펙 |
| 모바일 UX 흐름 | `docs/mobile-flow-spec.md` | Flutter 화면과 사용자 흐름 |
| 아키텍처 | `.agent/architecture.md` | 시스템 아키텍처 상세 |
| 정책 | `.agent/rules.md` | 코딩·문서·git·협업 정책 |
| 문서화된 해결책 | `docs/solutions/` | 과거 문제 해결·패턴·워크플로우 learning |

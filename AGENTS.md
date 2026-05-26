# AGENTS.md — Single Source of Truth

> **프로젝트**: MoreThanHuman (Convia)
> **서비스**: AI 기반 영어 회화 학습 플랫폼
> **시드 버전**: EstreGenesis v1.6.0
> **마이그레이션일**: 2026-05-20

---

## 1. 읽기 순서

모든 AI 에이전트는 아래 순서로 문서를 읽어야 해요:

1. `AGENTS.md` (이 파일 — SSoT)
2. `.agent/rules.md` (코딩·문서·git·협업 정책)
3. `.agent/architecture.md` (시스템 아키텍처·스택·데이터 플로우)
4. `.agent/_coordination/STATE.md` (현재 진행 중인 작업)
5. `.agent/_contracts/` (인터페이스 계약)
6. `README.md` (프로젝트 상세 — API 레퍼런스, 환경변수, 실행법)
7. `docs/DSL.md` (도메인 DSL 명세)

**스코프 루트**: `.agent/`

---

## 2. 역할

| 역할 | 설명 |
|------|------|
| **Lead** | 아키텍처 결정, 코드 리뷰, 머지 승인 |
| **Backend** | FastAPI 도메인 개발 (conversation, grammar, search, auth, llm) |
| **Mobile** | 향후 Flutter 기반 모바일 앱 개발 |

---

## 3. AI 서비스 브릿지

| 서비스 | 브릿지 파일 | 비고 |
|--------|-----------|------|
| Claude Code | `.claude/rules/bridge.md` | PreToolUse 훅 지원 |
| Codex | `codex.md` | AGENTS.md 직접 참조 |

모든 브릿지는 이 `AGENTS.md`를 SSoT로 import해요.

---

## 4. 코디네이션 프로토콜

멀티에이전트 동시 접근 시:

1. **작업 시작**: `.agent/_coordination/STATE.md`에 에이전트명·태스크·상태 기록
2. **공유 파일 편집**: `.agent/_coordination/HANDOFF.md`에 claim 먼저
3. **질문**: `.agent/_questions/open/YYYY-MM-DD_FROM-to-TO_NNN.md`
   - 🔴 24h blocker · 🟡 72h soon · 🟢 다음 주기
4. **인터페이스 변경**: `.agent/_contracts/NAME.md` (DRAFT → REVIEW → ACTIVE)
5. **완료**: `.agent/_coordination/CHANGELOG.md`에 1줄 기록, STATE.md에서 제거

**공유 파일 목록** (편집 전 반드시 HANDOFF claim):
- `backend/database.py`, `backend/config.py`, `backend/main.py`
- `backend/shared/*`
- `.env.example`
- `README.md`

---

## 5. 핵심 규칙

**5.1** 작업 언어: 한국어 · 말투: \~에요/예요 체 · 페이스 모드: Proactive 5\~6×

**5.2** 코드 전에 문서. 모든 결정은 파일로 기록.

**5.3** `.agent/_lessons/`가 예상 밖 블로커를 기록. 새 태스크 전 관련 태그로 grep.

**5.4** 인덱스 ↔ 본문 동기화: 본문 추가/재명명/폐기/재작성 시 그 문서를 가리키는 모든 인덱스를 같은 커밋에 갱신.

**5.5** 외부 표면 N-way sync: 한 기능이 N개 외부 표면에 묘사될 때 같은 작업 단위로 갱신; 모든 표면의 changelog/version bump.

**5.6** 마크다운 `\~` escape: GFM이 단일 `\~` 두 개를 취소선으로 짝지움. 본문의 단일 `\~`는 `\~`로 escape.

**5.7** 작업 분해 전략: 작업에 분해 경로가 여러 개일 때, 1줄 announce → 판단/관성에 따라 진행 → 사용자 피벗 프롬프트 즉시 반영. Claude Code는 `Agent` tool 다중 호출 병렬.

**5.8 N-way sync 등록부**

| 기능 | 표면 목록 |
|------|----------|
| API 엔드포인트 | `README.md` · `docs/DSL.md` · `backend/domains/*/router.py` |
| 환경변수 | `.env.example` · `README.md` · `backend/config.py` |

**5.9** agent-time 추정: 페이스 모드 Proactive 5\~6× 적용. 실행 중심 작업은 모드 상단, 디버깅은 중간, 연구/전략은 \~1× (인간 검토가 율속). `.agent/_lessons/`의 `estimation` 태그로 ±30%+ delta만 기록·보정.

**5.10** 문서 구조 원칙: 핵심 문서는 `README.md`(실행·환경변수·사용 예시), `docs/DSL.md`(외부 API 계약), `.agent/architecture.md`(내부 구조) 세 축으로 유지해요. API 계약은 `docs/DSL.md`, 환경변수 설명은 `README.md`, 내부 구현 구조는 `.agent/architecture.md`를 단일 기준으로 삼아요.

**5.11** 임시 문서 정리: `PLAN_*.md`, 피드백 메모 같은 임시 문서는 구현 전 의사결정용으로만 쓰고, 반영이 끝나면 핵심 문서에 흡수한 뒤 삭제 또는 아카이브해요.

---

## 6. 클라이언트 방향

- 현재 저장소의 기준 범위는 FastAPI 백엔드 API예요.
- 사용자 앱은 향후 Flutter 기반 모바일 앱으로 개발해요.
- 이 SSoT는 백엔드 API와 향후 모바일 앱 연동 계약만 다뤄요.

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
| 프로젝트 README | `README.md` | API 레퍼런스, 환경변수, 실행법 |
| DSL 명세 | `docs/DSL.md` | 도메인별 상세 스펙 |
| 모바일 UX 메모 | `docs/UX_FEEDBACK.md` | 향후 Flutter 앱 UX 방향 |
| 아키텍처 | `.agent/architecture.md` | 시스템 아키텍처 상세 |
| 정책 | `.agent/rules.md` | 코딩·문서·git·협업 정책 |

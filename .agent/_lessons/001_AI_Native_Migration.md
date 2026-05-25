# 001 — AI Native 마이그레이션

> 날짜: 2026-05-20 · 태그: migration, ai-native, scaffolding

## Symptom

프로젝트에 Claude Code 설정(`.claude/`)만 존재하고, 멀티에이전트 SSoT(`AGENTS.md`)가 없었어요. `README.md`가 사실상 CLAUDE.md 역할을 겸하고 있었어요.

## Root Cause

프로젝트 초기에 AI Native 표준 없이 Claude Code 단독으로 개발을 시작했기 때문이에요.

## Fix

EstreGenesis v1.6.0 기반 Migration A 실행:

1. 기존 AI 관련 파일 감사 (README.md, .claude/)
2. 서비스 중립 규칙 추출 → `.agent/rules.md`
3. `AGENTS.md` SSoT 생성
4. 브릿지: Claude Code (`.claude/rules/bridge.md`) + Codex (`codex.md`)
5. 멀티에이전트 코디네이션: `_coordination/`, `_contracts/`, `_questions/`
6. 아키텍처 문서: `.agent/architecture.md` (버전 고정)

## Decisions

- `README.md`는 프로젝트 상세(API 레퍼런스, 환경변수, 실행법)로 유지 — AGENTS.md §1 읽기 순서에서 6번째
- 기존 `.claude/commands/commit.md` 커스텀 커맨드 보존
- 기존 `.claude/settings.local.json` 권한 설정 보존
- 기존 `docs/` 구조 그대로 유지

## Prevention

- 새 AI 서비스 추가 시 `AGENTS.md §3` 브릿지 테이블에 등록
- 새 공유 파일 추가 시 `AGENTS.md §4` 공유 파일 목록에 등록

## Search Tags

`migration` `ai-native` `scaffolding` `agents-md` `estregenesis` `multi-agent`

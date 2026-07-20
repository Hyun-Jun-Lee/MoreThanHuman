# 프로젝트 정책

> SSoT: `AGENTS.md` · 최종 갱신: 2026-05-20

---

## 언어 정책

- 코드 주석: 한국어 (필요 시 영어 기술 용어 허용)
- 커밋 메시지: `<type>: <영문 subject>` (제목 영문, 본문 한국어 허용)
- 문서: 한국어 기본 (API 명세·코드 내 docstring은 영어 허용)
- 변수/함수명: 영문 snake\_case (Python), camelCase (JavaScript)

---

## 코딩 정책

### Python (Backend)

- Python ≥ 3.12, 패키지 관리 uv
- 순수 함수 위주 함수형 프로그래밍 선호
- DDD 계층: `models → schemas → repository → service → router`
- 도메인 간 직접 참조 금지, `shared/` 모듈만 의존
- 서비스 계층에서 도메인 간 연동
- Pydantic v2 모델 사용
- SQLAlchemy 2.0 패턴
- FastAPI 0.109.x 표준 라우팅
- API 응답 래퍼: `{ success: bool, data/error, message? }`
- 에러 처리: `AppException` 기반 커스텀 예외

### Mobile Client

- 사용자 앱은 `mobile/`의 Flutter 기반 iOS·Android 앱으로 개발
- 모바일 코드는 feature-first 구조를 기본으로 사용
- 클라이언트 문서는 모바일 앱 요구사항, UX flow, API 계약 중심으로 작성

### 공통

- 환경변수: `.env` 파일, `.env.example` 동기화 필수
- 새 도메인 추가 시: `domains/{name}/` 폴더 → models → schemas → repository → service → router → `main.py` 라우터 등록

---

## 문서 정책

- 인덱스 ↔ 본문 동기화: 본문 변경 시 관련 인덱스 같은 커밋에 갱신
- N-way sync: `AGENTS.md §5.8` 등록부 참조
- 문서 위치:
  - 기술 문서 → `docs/`
  - AI 에이전트 운영 → `.agent/`
  - 프로젝트 관리 → `.agent/PM/`

---

## Git 정책

- 브랜치: `feature/*`, `fix/*`, `refactor/*`, `docs/*`
- 커밋 형식: `AGENTS.md §7` 참조
- 공유 파일 편집 전: `HANDOFF.md` claim 필수
- PR 필수: main 직접 커밋 금지 (멀티에이전트 환경)

---

## 협업 정책

- 태스크 시작/종료 시 `STATE.md` 갱신
- 블로커 >30분: `.agent/_lessons/NNN_title.md` 기록
- 인터페이스 변경: `_contracts/` DRAFT → REVIEW → ACTIVE
- 질문: `_questions/open/`에 파일 생성 (우선순위 🔴🟡🟢)

---

## 트러블슈팅 루프

블로커 >30분 시:

1. 수정 후 `.agent/_lessons/NNN_title.md` 작성
2. 내용: Symptom · Reproduction · Root cause · Fix · Prevention · Related commits · Search tags
3. 새 태스크 전 관련 태그로 grep
4. 여러 lesson에 패턴 발견 시 → `docs/troubleshooting/`로 승격

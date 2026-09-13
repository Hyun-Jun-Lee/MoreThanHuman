# MoreThanHuman

Curitalk은 관심 있는 주제로 AI와 대화하고 문법 피드백과 짧은 언어 지식을 학습하는 다국어 회화 앱이에요. 이 저장소는 FastAPI 백엔드(`backend/`)와 Flutter iOS·Android 앱(`mobile/`)을 함께 관리해요.

## 실행 준비

- 백엔드: Python 3.12 이상과 uv
- 모바일: Dart 3.12.2 이상을 포함한 Flutter SDK, iOS용 Xcode 또는 Android SDK
- 인증·LLM: Google 로그인이 설정된 Supabase 프로젝트와 OpenRouter 설정
- Docker 실행을 선택할 때만 Docker Engine과 Compose가 필요해요.

**아래 명령 블록은 각각 저장소 루트에서 시작하는 기준이에요.** 이미 .env가 있다면 덮어쓰지 말고 필요한 항목만 추가해요.

```bash
cp .env.example .env
```

| 필수 설정 | 용도 |
|-----------|------|
| `DATABASE_URL` | 로컬 SQLite 예시 또는 운영 PostgreSQL 연결 |
| `OPENROUTER_API_KEY`, `OPENROUTER_MODEL` | 기본 LLM API 키·모델 |
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | 사용자 인증 |
| `JWT_SECRET_KEY` | 현재 설정 로더에서 요구하는 레거시 secret |

기본 provider는 OpenRouter이며 Ollama도 지원해요. 전체 설정과 우선순위는 [환경변수 문서](docs/ENVIRONMENT.md)를 참고해요. **.env와 서버 전용 키는 커밋하거나 Flutter에 포함하지 않아요.**

## 실행 방법

### 로컬 백엔드

```bash
cd backend
uv sync
uv run alembic upgrade head
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8010
```

**마이그레이션 실행 전 대상 DB와 백업을 확인하세요. 스낵 v2 마이그레이션은 기존 스낵 데이터를 삭제해요.** 새 콘텐츠는 별도로 생성해야 해요.

실행 후 [Swagger](http://localhost:8010/docs)에서 API를 확인하고 [/health](http://localhost:8010/health)로 서버 응답을 확인할 수 있어요.

### 모바일 앱

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8010/api/ \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --dart-define=GOOGLE_CLIENT_ID=YOUR_IOS_CLIENT_ID \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

Flutter는 서버 .env를 자동으로 읽지 않아요. 위 공개 설정을 실제 값으로 바꾸고, Google 로그인 플랫폼 설정은 [모바일 문서](mobile/README.md#실행-설정)를 따라주세요. Android 에뮬레이터는 API 주소의 호스트를 `10.0.2.2`, 실제 기기는 접근 가능한 개발 PC 주소로 바꿔요.

### Docker 백엔드

외부 PostgreSQL·nginx 구성을 마친 운영 서버에서 API를 갱신하는 명령이에요.

```bash
docker compose up -d --build --force-recreate --no-deps api
```

컨테이너 시작 시 마이그레이션도 실행돼요. API의 8010 포트는 호스트에 직접 공개되지 않으며 nginx를 통해 접근해요. 최초 설치·HTTPS·복구는 [운영 가이드](docs/OPERATIONS.md)를 참고해요.

## CLI 명령어

### DB 마이그레이션

`backend/`에서 실행해요. 조회 명령으로 상태를 확인한 뒤 필요한 변경만 적용해요.

| 명령 | 설명 |
|------|------|
| `uv run alembic current` | 연결된 DB의 적용 revision 확인 |
| `uv run alembic heads` | 코드의 최신 revision 확인 |
| `uv run alembic upgrade head` | 미적용 마이그레이션 반영 |

### 스낵 콘텐츠 생성

로컬에서는 Docker나 API 서버 없이 DB와 LLM에 직접 연결해요. 먼저 의존성 설치와 마이그레이션을 완료해야 해요.

```bash
cd backend
uv run python -m scripts.generate_language_snacks \
  --language en --per-type 3 --run-key initial-v2
```

위 명령은 영어 콘텐츠를 지역별 표현·용법 차이·동음이의어 **각 3개씩, 총 9개** 목표로 생성해요. 검증 통과 시 즉시 발행하며 실패·중복·예산 제한으로 목표보다 적을 수 있어요.

| 옵션 | 설명 |
|------|------|
| `--language en\|ko\|all` | 생성 언어. 기본 all은 두 언어 합계 18개 목표 |
| `--per-type 3` | 언어별 유형별 목표 수량, 1..6. 생략하면 환경 설정 사용 |
| `--run-key initial-v2` | 같은 키·언어·수량은 기존 작업을 재개하고 완료된 작업은 추가 생성하지 않아요 |
| `--dry-run` | 후보만 미리 생성하고 DB에는 저장하지 않아요 |
| `--help` | 전체 옵션 확인 |

실행 키를 생략하면 현재 주간 슬롯을 사용해요. **실제 생성과 dry-run 모두 LLM 사용량이 발생해요.** 스낵 전용 설정이 없으면 기본 LLM provider·model을 사용해요.

Docker에서는 이미지 빌드와 DB 마이그레이션을 완료한 뒤 저장소 루트에서 실행해요.

```bash
/bin/sh deploy/scripts/generate-language-snacks.sh \
  --language en --per-type 3 --run-key initial-v2
```

이 래퍼만 Docker 실행을 요구해요. 월요일 오전 5시(한국 시간) cron 등록, 오류·재시도·잠금 설정은 [스낵 운영 절차](docs/OPERATIONS.md#언어-스낵-운영)를 참고해요.

### 테스트

백엔드:

```bash
cd backend
uv run pytest -q
```

모바일:

```bash
cd mobile
flutter analyze
flutter test
```

스낵 PostgreSQL 통합 테스트는 별도의 격리 테스트 DB를 `SNACK_TEST_POSTGRES_URL`로 지정해야 해요. 운영 DB를 사용하지 않아요.

## 상세 문서

| 문서 | 내용 |
|------|------|
| [환경변수](docs/ENVIRONMENT.md) | 전체 설정·기본값·provider 선택 |
| [운영 가이드](docs/OPERATIONS.md) | Docker 배포·인증·cron·복구 |
| [API 명세](docs/DSL.md) | 요청·응답·인증·도메인 계약 |
| [음성 지연 진단](docs/VOICE_LATENCY.md) | print 계측·10회 실험·연결 풀 v1 적용(2026-09-13) |
| [음성 스트리밍 제안](docs/VOICE_STREAMING.md) | 향후 문장별 TTS·앱 재생 설계 |
| [모바일 가이드](mobile/README.md) | 플랫폼·로그인 설정과 앱 개발 |
| [아키텍처](.agent/architecture.md) | 내부 구조와 데이터 흐름 |
| [디자인 시스템](docs/design/DESIGN_SYSTEM.md) | UI 토큰과 컴포넌트 기준 |
| [기여 규칙](AGENTS.md) | 코드·문서·Git 협업 규칙 |

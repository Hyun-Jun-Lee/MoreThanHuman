# 운영 가이드

> 최종 갱신: 2026-09-13 · 배포·주간 생성·복구 절차

[실행 및 CLI](../README.md) · [환경변수](ENVIRONMENT.md) · [API 계약](DSL.md)

## 배포 전 확인

- API와 생성 작업 모두 같은 외부 PostgreSQL에 연결해야 해요. 저장소의 Compose는 DB 서버를 설치하지 않아요.
- 운영 환경 파일은 서버에서만 관리해요. 예: `export CURITALK_ENV_FILE=/secure/path/curitalk.env`. cron에도 같은 경로를 지정해요.
- DB 백업과 미적용 Alembic revision을 확인해요. API 컨테이너는 시작할 때마다 `alembic upgrade head`를 먼저 실행해요. 스키마 변경이 있는 배포에서는 기존 API 쓰기와 생성 작업을 중지해 구버전 코드의 접근을 막아요.
- **스낵 v2 revision 20260912_0001은 기존 language_snacks를 삭제해요.** 적용 후 별도 생성 전까지 Home 스낵 목록은 비어 있어요.
- API 컨테이너의 8010 포트는 내부 네트워크에만 노출돼요. 외부 접근은 nginx의 80/443 포트를 통해 제공해요.

## Docker 실행

저장소 루트에서 실행해요. 이미 운영 구성이 완료된 API만 갱신할 때:

```bash
docker compose up -d --build --force-recreate --no-deps api
docker compose ps
docker compose logs --tail=100 api
```

최초 nginx 실행 전에는 [설정 파일](../deploy/nginx/conf.d/api.conf)의 도메인과 호스트 볼륨 경로를 확인하고, 문서 접근용 `deploy/nginx/auth/docs.htpasswd`를 준비해요. [계정 파일 생성 스크립트](../deploy/scripts/create-docs-htpasswd.sh)는 사용자명·비밀번호를 인자로 받아 파일을 생성하며 기존 파일을 덮어써요. 비밀번호를 명령 기록·프로세스 인자로 노출하지 않도록 서버의 secret 관리 절차를 사용해요.

```bash
docker compose up -d --build api nginx
```

기본 설정은 HTTP예요. HTTPS는 인증서 발급 후 [TLS 설정 예시](../deploy/nginx/conf.d/api.ssl.conf.example)의 도메인·인증서 경로를 확인해 적용해요. [인증서 갱신 스크립트](../deploy/scripts/certbot-renew.sh)는 호스트 certbot과 root 권한이 필요하고, 저장소 루트에서 실행해야 해요.

## 상태 확인

로컬 직접 실행은 `http://localhost:8010/health`, nginx 배포는 서비스 도메인의 `/health`를 확인해요. 현재 health 응답의 database 값은 고정 문자열이므로 실제 DB 접근은 인증된 조회 API나 별도 DB 점검으로 확인해야 해요.

## Swagger 인증

1. 모바일 앱 또는 Supabase Auth tooling에서 로그인된 사용자의 Supabase `access_token`을 복사해요.
2. Swagger 우측 상단 `Authorize`에 `Bearer <supabase_access_token>` 형식으로 입력해요.
3. `/api/search/`, `/api/search/topic-prep/`, `/api/conversations/` 같은 인증 API를 호출해요.
4. 만료되었거나 다른 Supabase project의 token이면 FastAPI가 `401`을 반환해요.

테스트 계정이 Supabase email/password 로그인을 사용할 수 있으면 Swagger에서 `POST /api/auth/swagger/token`으로 `access_token`을 발급받을 수 있어요. 이 helper는 `ENV=dev`에서는 기본 활성화되고, 그 외 환경에서는 `SWAGGER_TOKEN_ISSUER_ENABLED=true`와 `SWAGGER_TOKEN_ISSUER_SECRET`이 모두 설정되어야 해요. 운영에서 열 때는 nginx docs basic auth와 별개로 요청 body의 `secret`도 맞아야 합니다.

```text
Flutter App
→ Google Sign-In SDK로 로그인
→ Google id_token + access_token 획득
→ Supabase signInWithIdToken
→ Supabase access_token 획득
→ FastAPI API 호출 시 Authorization 헤더 사용
```

## 언어 스낵 운영

월요일 05:00 Asia/Seoul에 영어·한국어 각각 유형별 3개, 총 18개를 목표로 생성해요. 실패·중복·예산 초과 시 목표보다 적게 발행할 수 있어요. 모든 상태의 기존 지식 요약을 LLM에 전달하고 동일 identity 해시의 UNIQUE 제약과 의미 중복 검사를 함께 적용해요. 의미상 중복이나 내용 오류가 완전히 사라진다는 보장은 없어요.

1. 기존 스낵 쓰기·cron을 중지하고 필요한 백업을 확보해요. API 이미지를 빌드해 재시작하면 기존 compose command가 Alembic을 실행해요. **revision `20260912_0001`은 기존 스낵을 모두 삭제하고 테이블을 교체해요.** 다른 도메인 데이터는 보존해요.
2. `LANGUAGE_SNACKS_LOCK_DATABASE_URL`은 API와 **같은 DB**의 direct 또는 session pooling URL로 설정해요. `DATABASE_URL` 자체가 direct/session 연결이면 생략할 수 있어요. transaction pooling URL로 session advisory lock을 사용하면 안 돼요. API와 job에 같은 설정을 사용해요.
3. 배포 후 아래 후보 미리보기·초기 생성을 수동 확인해요. **dry-run도 LLM을 호출하지만 DB에는 저장하지 않아요.** 실제 발행 표본에서 세 유형·두 언어의 정확성을 확인해요.
4. [cron 예시](../deploy/cron/language-snacks.cron.example)의 저장소·로그 경로, Docker PATH, cron 데몬 시간대를 확인한 뒤 서버 사용자 crontab에 등록해요. 예시는 UTC 일요일 20시이며 KST 데몬에서는 월요일 05시를 사용해요. 이 저장소 변경만으로 cron이 설치되지는 않아요.

```bash
docker compose up -d --build --force-recreate --no-deps api
/bin/sh deploy/scripts/generate-language-snacks.sh --language en --dry-run
/bin/sh deploy/scripts/generate-language-snacks.sh --run-key initial-v2
```

작업은 API 이미지의 별도 `snack-generator` 컨테이너에서 실행하며 migration과 웹 서버를 실행하지 않아요. `CURITALK_ENV_FILE`을 사용하는 서버는 cron에도 같은 절대 경로를 지정해야 해요.

- 실행 키를 생략하면 가장 최근 월요일 05시 슬롯의 `weekly:YYYY-MM-DD:{en|ko}`를 사용해요. 같은 키·언어·수량 재실행은 같은 run을 재개하고 성공한 run에는 추가 생성하지 않아요. 수동 키에도 언어 suffix가 자동으로 붙어요.
- `--language en|ko|all`, `--per-type 1..6`을 지원해요. 같은 실행 키에서 목표 수량을 바꾸면 409에 해당하는 오류로 종료해요. 지난 주 누락분을 다음 주에 자동 누적하지 않아요.
- 예약을 먼저 재개하고 후보 라운드는 run당 최대 3회, 본문 생성은 예약당 최대 2회예요. API 일시 오류는 호출당 한 번 재시도해요. 호출·보수적 토큰 예산은 재실행에도 누적하고 시간 제한은 언어별 실행 시도에 적용해요. 예산을 다 쓴 run은 같은 설정에서 계속 재시도해도 진행하지 않아요.
- stdout JSON에서 언어별 상태·발행 수·중복/불확실 판정 수·호출/토큰 사용량·오류 코드를 확인해요. `partial`/`failed`는 exit 1, 실행 중 잠금 충돌은 `skipped`예요. 로그 회전과 실패 알림은 서버 운영 도구에서 설정해요.
- `history_budget_exceeded`는 이력을 자르지 않고 중단해요. 모델 컨텍스트·비용을 검토해 상한을 조정하거나 후속 검색 기반 설계를 적용해요.
- 잘못된 발행은 PATCH로 보관해요. archived identity는 재생성하지 않으며 오프라인 캐시를 즉시 회수하지는 못해요. 수동 POST의 검증 실패도 identity를 보관하므로 같은 지식을 다시 등록할 수 없어요.
- 롤백은 생성 작업을 중지하고 API를 정지한 뒤 **새 이미지로** `alembic downgrade 20260906_0002`를 실행하고 v1 이미지를 복원해요. downgrade도 모든 v2 스낵·생성 이력을 삭제하며 예전 스낵은 복원하지 않아요. 필요하면 사전 백업을 별도로 복원해요.

구버전 앱은 정상 온라인 조회 후 스낵이 숨겨지고, 새 앱은 언어별 v2 캐시를 사용해요. 구버전 앱의 이미 저장된 오프라인 카드는 원격 삭제할 수 없어요.

## 변경 기록

- 2026-09-13: README의 Swagger·스낵 배포/복구 절차를 이관하고 Docker의 DB·포트·초기 nginx 전제를 명시했어요.

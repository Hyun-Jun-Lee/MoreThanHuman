# 운영 가이드

> 최종 갱신: 2026-10-05 · 배포·주간 생성·복구 절차

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

API는 Uvicorn worker 2개로 실행해요. Compose 명령만 바꾼 경우에도 위 `up --force-recreate --no-deps api`로 API 컨테이너만 재생성하면 돼요. 전체 `docker compose down`은 필요하지 않으며 nginx는 실행 상태를 유지해요. API 재생성 중 짧은 요청 실패가 발생할 수 있으므로 상태 확인 뒤 실제 API 요청도 점검해요.

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

## 대화 이용 권한 활성화

`20261004_0002` migration은 Apple 구독·알림 표와 활성 대화 슬롯을 추가해요. `CONVERSATION_ACCESS_ENABLED=false`에서는 기존 대화 제한을 적용하지 않아요. 운영 활성화 전에는 Apple Sandbox의 구매·복원·갱신·만료·환불, PostgreSQL 동시 요청, 앱의 읽기 전용 대화 흐름을 확인해요.

개발 환경 미리보기와 향후 결제 출시 때는 아래 순서로 활성화해요.

1. API에 migration을 적용하고 새 iOS 앱을 배포해요. App Store Connect에서 월간 `Advance`·`Plus`를 같은 구독 그룹에 두고, 앱 내 구입 계약·세금·은행 정보와 상품 심사를 준비해요. 앱 빌드에는 공개 개인정보처리방침 URL을 `--dart-define=PRIVACY_POLICY_URL=...`로 제공해요.
2. 서버 비밀 저장소에 `APPLE_IAP_*` 설정을 주입해요. App Store Connect에서 Server Notifications V2 URL을 `https://<API 호스트>/api/billing/apple/notifications/`로 지정해요. Sandbox는 `APPLE_IAP_ENVIRONMENT=sandbox`, 운영은 `production`으로 분리해요. `backend/certs/apple/`의 Apple 공식 루트 인증서 3개를 배포물에 포함해요.
3. 기존 API의 대화 생성·삭제 쓰기를 잠시 중지하고, `backend/`에서 `uv run python -m scripts.initialize_conversation_slots`를 실행해요. 무료 계정은 가장 최근 사용자 발화가 있는 대화 1개만 활성화해요. 재실행 시 사용자가 직접 바꾼 활성 대화는 보존해요.
4. 무료 0/1/기존 다중 대화 계정과 Advance·Plus 계정에서 `GET /api/conversations/access/`, 생성·발화, 15회 경계, 대화 전환·해제, 만료·환불 잠금을 확인해요. 쓰기 중지가 유지되는 동안 `CONVERSATION_ACCESS_ENABLED=true`로 API를 재시작해요. 문제가 있으면 스위치를 `false`로 되돌리고 원인을 분석해요.

초기화와 스위치 변경 사이에 대화 생성·삭제가 발생하면 활성 슬롯 선택이 달라질 수 있으므로 쓰기를 중지해요. 이 CLI는 스위치가 이미 켜져 있으면 실행을 거부해요. 테스트용 `.env`에서 스위치를 켜면 무료 계정에 활성 슬롯 1개와 대화당 15회가 적용돼요. 읽기 전용 대화는 앱에서 열람·삭제하고, 슬롯이 가득 차면 기록 화면에서 현재 활성 대화를 해제하거나 교체해요.

동시 생성·발화 제한은 프로덕션 PostgreSQL의 행 잠금에 의존해요. 개발용 SQLite에서는 동시 요청 경계 검증을 대신할 수 없으므로 활성화 전 PostgreSQL에서 병렬 요청을 확인해요. Apple 알림 누락에 대비해 `backend/`에서 `uv run python -m scripts.reconcile_apple_subscriptions`를 주기적으로 실행하고 종료 코드·실패 건수를 모니터링해요. 이 작업은 Apple 현재 상태를 다시 조회하고 기존 Convia 계정 연결을 유지해요.

`ENV=dev`나 로컬 `.env`라는 파일명만으로 데이터가 운영과 분리되지는 않아요. UI 미리보기 전에 `DATABASE_URL`과 앱의 `SUPABASE_URL`이 별도 테스트 프로젝트를 가리키는지 확인해요. 같은 프로젝트라면 스위치를 켰을 때 실제 계정에도 제한이 적용돼요.

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

### 테스트용 바구니 리셋

2026-09-19 v1: `POST /api/v2/language-snacks/basket-reset/`은 운영자만 사용하는 테스트·지원용 리셋이에요. 사용자 진행은 기기에 있고 서버에는 최신 리셋 ID만 저장해요.

1. 신규 revision `20260919_0001`을 `uv run alembic upgrade head`로 적용하고 변경된 API·앱을 배포해요. 이 revision은 `language_snack_basket_resets` 테이블만 추가하며 기존 사용자·스낵은 삭제하지 않아요. 아직 v2 이전 DB라면 먼저 적용되는 `20260912_0001`의 데이터 삭제 경고도 확인해야 해요.
2. Swagger에서 대상 사용자의 Bearer로 `GET /api/auth/me`를 호출해 사용자 `id`를 확인해요.
3. `POST /api/v2/language-snacks/basket-reset/`의 `X-Operations-Key`에 서버 `LANGUAGE_SNACKS_OPERATIONS_KEY`를 입력하고 아래 body를 보내요. `content_language`는 영어 학습 `en`, 한국어 학습 `ko`예요.

```json
{
  "user_id": "대상 사용자의 UUID",
  "content_language": "en"
}
```

4. 200 응답의 `reset_id`를 확인하고 앱을 백그라운드로 보냈다가 Home으로 복귀해요. 앱 시작·Home 재진입에도 확인하며 같은 카드 12개를 유지하고 바구니에 토마토 3개가 복원돼요. 팝업·애니메이션 중이라면 종료 후 적용돼요.

GET은 일반 Bearer로 조회하며 운영 키를 앱에 넣지 않아요. 다른 기기는 각자 다음 조회 성공 때 반영돼요. 오프라인·구 앱에서는 즉시 반영되지 않으며, POST 성공 자체가 앱 리셋 완료를 뜻하지는 않아요. 테스트를 다시 시작하려면 POST를 다시 호출해요. 리셋 ID는 자정 이후에도 로컬에 유지되므로 같은 요청이 다음 날 소비를 초기화하지 않아요. DB 리셋 기록만 롤백할 때는 API 중지 후 `alembic downgrade 20260912_0001`로 새 테이블만 제거할 수 있어요.

## 주간 대화 추천 운영

`20261003_0001` migration 적용 뒤 `backend/`에서 수동 CLI를 실행해요. 이 버전은 cron·상시 worker·자동 알림을 설치하지 않아요. 새 묶음은 운영자가 실행한 경우에만 발행돼요.

```bash
cd backend
uv run alembic upgrade head
uv run python -m scripts.generate_weekly_topics --pair all
```

Docker Compose로 배포한 서버에서는 저장소 루트에서 `docker compose exec api python -m scripts.generate_weekly_topics --pair all`을 실행해요. API 배포와 DB migration만으로는 첫 주제가 생성되지 않아요.

`--pair ko-en|en-ko|all`로 대상 언어쌍을 고르고 `--week-start YYYY-MM-DD`로 슬롯을 지정할 수 있어요. 이 날짜는 월요일이어야 하며 미래 슬롯은 발행하지 않아요. 기본 슬롯은 서울 시간 월요일 05:00부터 시작해요. 실행하면 LLM 사용량이 발생해요. JSON stdout의 각 언어쌍 `published`/`existing`/`republished`/`failed`와 개수를 확인해요. 각 언어쌍당 모국어 주제와 학습 언어 첫 질문 8쌍을 요청하고 최소 6쌍이 검사를 통과해야 발행해요. 기본 재실행은 기존 묶음을 유지해요.

재발행은 후보 12쌍에서 최대 8쌍을 선별해요. 실패 결과의 `error`는 `invalid_generated_json`, `not_enough_valid_topics`, `not_enough_fresh_topics`, `invalid_safety_review`, `not_enough_approved_topics`, `not_enough_topics_to_preserve_ids`, `generation_failed`, `publication_failed` 중 하나예요. `valid_count`, `approved_count`, `required_count`는 해당 단계에서 확인된 개수예요. CLI는 원문이나 DB 오류 세부 정보를 출력하지 않아요. 한 언어쌍만 실패했다면 성공한 쌍을 다시 생성할 필요 없이 `--pair ko-en --republish`처럼 실패한 쌍만 재실행해요.

기존 주차를 새 주제·첫 질문으로 교체하려면 migration과 새 API 배포 후 `uv run python -m scripts.generate_weekly_topics --pair all --republish`를 실행해요. Docker에서는 `docker compose exec api python -m scripts.generate_weekly_topics --pair all --republish`를 사용해요. 모든 후보를 검증한 다음 활성 주제의 ID를 유지하며 문구와 질문을 한 트랜잭션에서 교체해요. 기존 활성 주제 수보다 검증된 후보가 적으면 기존 발행을 유지하고 실패로 종료해요. 보관된 주제와 완료된 대화·시작 예약은 보존해요. `--pair all`은 언어쌍별로 순서대로 실행되므로 한쪽만 성공할 수 있어요. migration 후 재발행 전의 구형 주제는 첫 질문이 없어 새 대화를 시작할 수 없으므로, 배포 작업 중 재발행을 완료하고 목록·시작 동작을 확인해요.

생성 실패나 미실행 시 목록 API는 마지막 발행 묶음을 계속 반환해요. 처음부터 발행 기록이 없으면 홈의 추천 영역이 숨겨져요. 문제 주제를 발견하면 아래 명령으로 보관해요. 보관 후 새 목록에서 빠지고 기존 앱 캐시의 해당 ID도 대화 시작 시 서버가 거절해요.

```bash
uv run python -m scripts.archive_weekly_topic TOPIC_UUID
```

백업·복구에서는 API와 생성 CLI를 중지하고 `weekly_topic_batches`, `weekly_topics`, `suggested_starts`를 함께 다뤄요. `alembic downgrade 20261001_0001`은 이 세 테이블과 발행·멱등성 이력을 삭제하므로 운영 데이터 롤백에는 사전 DB 백업을 사용해요. 실제 LLM 출력은 자동 검사 후에도 의미·어조 오류가 남을 수 있으므로 첫 발행 표본을 확인해요.

## 변경 기록

- 2026-10-05: API Uvicorn worker를 2개로 설정하고 전체 Compose 중단 없이 API만 재생성하는 절차를 명시했어요.
- 2026-10-04: 재발행 후보를 12쌍으로 늘리고 실패 코드·검증 개수를 CLI 결과에 추가했어요.
- 2026-10-04: 주간 주제 첫 질문 생성과 `--republish` 재발행 절차를 추가했어요.
- 2026-10-03: 수동 주간 대화 추천 발행·보관·마지막 묶음 복구 절차를 추가했어요.
- 2026-10-01: 기본 비활성화 대화 권한 설정, 기존 슬롯 스냅샷 CLI와 향후 활성화·롤백 절차를 추가했어요.
- 2026-09-19: 바구니 리셋 API·추가 테이블 마이그레이션·앱 복귀 확인·구버전/오프라인 제한을 추가했어요.

- 2026-09-13: README의 Swagger·스낵 배포/복구 절차를 이관하고 Docker의 DB·포트·초기 nginx 전제를 명시했어요.

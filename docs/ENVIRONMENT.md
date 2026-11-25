# 환경변수

> 최종 갱신: 2026-11-25 · 환경변수 설명의 단일 기준 문서

[빠른 시작](../README.md#실행-준비) · [운영 가이드](OPERATIONS.md)

## 설정 방식

백엔드는 [config.py](../backend/config.py)의 Settings로 저장소 루트 `.env`를 읽어요. 실행 프로세스의 환경변수가 `.env`보다 우선하며 설정 변경 후에는 프로세스를 재시작해야 해요. [.env.example](../.env.example)은 시작용 예시이고 아래 기본값은 코드 기준이에요. 예를 들어 예시 파일의 MAX_TOKENS는 2000, 코드 기본값은 4000이에요.

`DATABASE_URL`을 반드시 지정해요. SQLite 상대 경로는 현재 작업 디렉터리를 기준으로 해석하므로 로컬 백엔드·CLI는 모두 `backend/`에서 실행해요. 운영과 Docker 작업에서는 같은 외부 PostgreSQL을 사용해요. Compose에는 DB 서비스나 SQLite 공유 볼륨이 없어요.

현재 `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `JWT_SECRET_KEY`는 provider와 무관하게 Settings 로드 시 필수예요. Ollama를 선택해도 이 항목을 삭제하면 설정 검증이 실패해요. Supabase URL·publishable key는 인증 기능 사용 시 필요해요.

실제 secret과 DB 접속 문자열은 Git에 커밋하지 않아요. Flutter에는 OpenRouter/OpenAI 키·스낵 운영 키·Supabase service role key를 전달하지 않아요. 앱에 필요한 공개 설정은 [모바일 실행 설정](../mobile/README.md#실행-설정)에서 관리해요.

## 백엔드 설정

| 변수 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `DATABASE_URL` | 실행 시 필수 | 코드 기본값 없음 | DB 연결 문자열. `.env.example`은 로컬 SQLite 예시를 제공해요 |
| `OPENROUTER_API_KEY` | 예 | 없음 | OpenRouter API 키 |
| `OPENAI_API_KEY` | OpenAI direct 음성 기능 사용 시 | 없음 | OpenAI STT/TTS API 키. Flutter 앱에는 노출하지 않음 |
| `LLM_PROVIDER` | 아니오 | `openrouter` | 기본 LLM provider. `ollama`는 로컬 Ollama 서버를 의도적으로 사용할 때만 설정 |
| `OLLAMA_BASE_URL` | Ollama 사용 시 | 없음 | Ollama 서버 URL |
| `OPENROUTER_MODEL` | 설정 로드 시 필수 | 없음 | 기본 OpenRouter 모델. 다른 provider를 사용해도 현재 Settings에는 값이 필요해요 |
| `OLLAMA_MODEL` | Ollama 사용 시 | 없음 | 대화용 Ollama 모델 |
| `GRAMMAR_MODEL_PROVIDER` | 아니오 | `LLM_PROVIDER` | 문법 체크 전용 provider. 기본 권장은 `openrouter` |
| `GRAMMAR_OPENROUTER_MODEL` | 아니오 | `OPENROUTER_MODEL` | 문법 체크 전용 OpenRouter 모델 |
| `GRAMMAR_OLLAMA_MODEL` | 아니오 | `OLLAMA_MODEL` | 문법 체크 전용 Ollama 모델 |
| `SUPABASE_URL` | 예 | 없음 | Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | 예 | 없음 | 원격 Supabase Auth `/user` 검증에 사용하는 publishable key |
| `SUPABASE_AUTH_VERIFY_MODE` | 아니오 | `auto` | ES256 token을 JWKS 공개 키로 검증하고 그 외 token은 `/user`로 검증해요. `remote`는 모든 token을 `/user`로 검증해요 |
| `SUPABASE_AUTH_TIMEOUT_SECONDS` | 아니오 | `5` | Supabase Auth `/user`와 JWKS 조회 timeout |
| `PRIVACY_POLICY_VERSION` | 아니오 | `2026-11-25` | 현재 개인정보처리방침 동의 버전. 값을 바꾸면 게스트와 회원 모두 새 버전에 다시 동의해야 해요 |
| `AI_DATA_PROCESSING_VERSION` | 아니오 | `2026-11-23` | 현재 AI 데이터 처리 고지 동의 버전. 값을 바꾸면 AI 기능 전에 다시 동의해야 해요 |
| `PRIVACY_POLICY_URL` | 아니오 | `https://www.curitalk.app/privacy` | 한국어 앱의 동의·상점 화면에서 여는 공개 개인정보처리방침 URL |
| `PRIVACY_POLICY_URL_EN` | 아니오 | `https://www.curitalk.app/en/privacy` | 영어 앱의 동의·상점 화면에서 여는 공개 개인정보처리방침 URL |
| `AI_CONSENT_REQUIRED` | 아니오 | `true` | `true`이면 현재 두 고지에 동의하기 전 AI 요청을 HTTP 403으로 차단해요. 테스트 외 운영 비활성화를 권장하지 않아요 |
| `GUEST_TRANSFER_RECEIPT_TTL_MINUTES` | 아니오 | `10` | 기존 회원 계정으로 게스트 데이터를 이전하는 일회용 영수증 유효 시간(분) |
| `GUEST_RETENTION_DAYS` | 아니오 | `30` | 회원으로 전환하지 않은 게스트를 마지막 bootstrap 또는 AI 활동 뒤 삭제 후보로 삼는 기간(일) |
| `ADMIN_PUBLIC_ORIGIN` | 아니오 | `https://api.curitalk.app` | 관리자 웹 쓰기 요청의 Origin 검사 기준. 로컬에서는 `http://localhost:8010`으로 설정해요 |
| `ADMIN_ACCESS_CODE` | 관리자 웹 사용 시 | 없음 | 관리자 웹·API 공유 입장 코드. 길이 제한은 없고 앞뒤 공백은 허용하지 않아요. 빈 값은 미설정으로 처리해요. 서버 환경변수에만 저장하며 변경 후 API를 재시작하면 기존 관리자 세션이 무효화돼요 |
| `SWAGGER_TOKEN_ISSUER_ENABLED` | 아니오 | `false` | `ENV`가 dev가 아닐 때 Swagger token helper를 명시적으로 활성화 |
| `SWAGGER_TOKEN_ISSUER_SECRET` | 운영 helper 활성화 시 | 없음 | dev 외 환경에서 `/api/auth/swagger/token` 요청 body의 `secret`과 비교할 shared secret |
| `LANGUAGE_SNACKS_OPERATIONS_KEY` | 운영 API 사용 시 | 없음 | v2 POST/PATCH의 X-Operations-Key와 비교. Flutter에 포함 금지. CLI는 DB 직접 접근 |
| `LANGUAGE_SNACKS_PROVIDER` | 아니오 | LLM_PROVIDER | 스낵 생성·중복/품질 검사 provider |
| `LANGUAGE_SNACKS_MODEL` | 아니오 | 해당 provider 기본 모델 | 스낵 전용 모델 override |
| `LANGUAGE_SNACKS_LOCK_DATABASE_URL` | transaction pooling 사용 시 | DATABASE_URL | 같은 DB의 direct/session 연결. API와 job에서 동일하게 사용 |
| `LANGUAGE_SNACKS_PER_TYPE` | 아니오 | 3 | 언어별 유형별 목표 수량, 1..6 |
| `LANGUAGE_SNACKS_MAX_CALLS` | 아니오 | 100 | 언어별 run의 누적 LLM 호출 상한 |
| `LANGUAGE_SNACKS_MAX_TOKENS` | 아니오 | 250000 | 입력 UTF-8 바이트+출력 최대 토큰을 누적한 보수적 예산, 금액 상한이 아님 |
| `LANGUAGE_SNACKS_HISTORY_BYTES` | 아니오 | 40000 | 전체 지식 이력 UTF-8 바이트 상한 |
| `LANGUAGE_SNACKS_RUN_SECONDS` | 아니오 | 600 | 언어별 실행 시도 시간 상한(초), 각 LLM 요청은 최대 65초 |
| `AUTO_CREATE_TABLES` | 아니오 | `false` | Alembic 대신 SQLAlchemy `create_all`을 실행할지 여부. 로컬 임시 실행 외에는 `false` 권장 |
| `JWT_SECRET_KEY` | 설정 로드 시 필수 | 없음 | 레거시 JWT용 secret. Supabase 로그인에는 쓰지 않지만 현재 Settings에는 값이 필요해요 |
| `ENV` | 아니오 | `prod` | 실행 환경. `dev`/`development`/`local`이면 개발 전용 API 활성화 |
| `DEBUG` | 아니오 | `false` | 디버그 모드 |
| `CORS_ORIGINS` | 아니오 | `[]` | CORS 허용 origin 목록 |
| `HTTP_MAX_CONNECTIONS` | 아니오 | `100` | 워커 내 각 외부 HTTP 풀의 최대 연결 수. 1 이상 |
| `HTTP_MAX_KEEPALIVE_CONNECTIONS` | 아니오 | `20` | 각 풀의 최대 유휴 연결 수. 0 이상이고 MAX_CONNECTIONS 이하 |
| `HTTP_KEEPALIVE_EXPIRY_SECONDS` | 아니오 | `30` | 재사용할 유휴 연결의 만료 시간(초). 유한한 양수 |
| `BACKGROUND_SHUTDOWN_GRACE_SECONDS` | 아니오 | `5` | 종료 시 문법 task 완료 대기 시간(초). 이후 취소하고 정리 완료를 기다림. 유한한 0 이상 |
| `MAX_TOKENS` | 아니오 | `4000` | LLM 최대 토큰 |
| `TEMPERATURE` | 아니오 | `0.7` | LLM temperature |
| `STT_PROVIDER` | 아니오 | `openrouter` | STT provider. `openrouter` 또는 `openai` |
| `STT_MODEL` | 아니오 | `openai/gpt-4o-mini-transcribe` | 음성 파일을 텍스트로 변환할 STT 모델. OpenAI direct 사용 시 `gpt-4o-mini-transcribe`처럼 provider prefix 없이 설정 |
| `TTS_PROVIDER` | 아니오 | `openrouter` | TTS provider. `openrouter` 또는 `openai` |
| `TTS_MODEL` | 아니오 | `microsoft/mai-voice-2-flash` | AI 응답을 음성으로 변환할 TTS 모델. OpenAI direct 사용 시 `gpt-4o-mini-tts`처럼 provider prefix 없이 설정 |
| `TTS_VOICE` | 아니오 | `en-US-Harper:MAI-Voice-2-Flash` | TTS 음성 preset. provider/model별 지원 voice가 다름 |
| `TTS_RESPONSE_FORMAT` | 아니오 | `mp3` | TTS 응답 오디오 포맷. OpenRouter 기본 권장은 `mp3` 또는 `pcm` |
| `TTS_MAX_INPUT_CHARS` | 아니오 | `4000` | TTS로 보낼 최대 텍스트 길이 |
| `TTS_MAX_OUTPUT_MB` | 아니오 | `5` | base64 인코딩 전 TTS 응답 오디오 최대 크기 |
| `VOICE_MAX_UPLOAD_MB` | 아니오 | `10` | STT 업로드 음성 파일 최대 크기 |
| `VOICE_PROVIDER_TIMEOUT_SECONDS` | 아니오 | `60` | STT/TTS provider 요청 timeout |
| `AUDIO_CACHE_DIR` | 아니오 | 없음 | 호스트 음성 캐시의 컨테이너 내부 절대 경로. Compose는 `/var/lib/curitalk/audio`를 주입해요. 운영에서 설정하면 기존 쓰기 가능한 마운트여야 해요. |
| `AUDIO_CACHE_RETENTION_DAYS` | 아니오 | `30` | 마지막 생성 후 만료시킬 파일 보관 기간. 정리 작업을 주기적으로 실행해야 해요. |
| `CURITALK_AUDIO_HOST_DIR` | Compose 전용 | `/var/lib/curitalk/audio` | 호스트 bind mount 원본. API와 정리 작업이 같은 디렉터리를 사용해요. |
| `SEARCH_SUMMARY_MAX_TOKENS` | 아니오 | `600` | 검색 요약 최대 토큰 |
| `SEARCH_QUERY_ANALYSIS_MAX_TOKENS` | 아니오 | `500` | 검색어 분석 LLM 최대 토큰 |
| `SEARCH_QUALITY_JUDGE_MAX_TOKENS` | 아니오 | `1000` | 검색 품질 판정 LLM 최대 토큰 |
| `SEARCH_QUALITY_JUDGE_MODEL` | 아니오 | `google/gemini-3.1-flash-lite` | 검색 출처 품질 판정 전용 OpenRouter 모델. 검색어 분석·카드 생성·대화 모델에는 적용하지 않아요. |
| `SEARCH_REGION` | 아니오 | `kr-kr` | ddgs 검색 지역 |
| `SEARCH_SAFESEARCH` | 아니오 | `moderate` | ddgs safe search 옵션 |
| `SEARCH_RECENT_TIMELIMIT` | 아니오 | `m` | 최신성 의도 쿼리에 적용할 ddgs 기간 옵션 |
| `SEARCH_BACKEND` | 아니오 | `auto` | ddgs 검색 backend |
| `SEARCH_MAX_RESULTS` | 아니오 | `6` | 필터링 전 수집할 검색 결과 수. 최소 관련 출처 2개를 확보하지 못할 수 있어 품질 지표를 함께 확인해요. |
| `SEARCH_MIN_RELEVANT_RESULTS` | 아니오 | `2` | LLM judge가 accept해야 하는 최소 출처 수 |
| `MAX_HISTORY_TURNS` | 아니오 | `10` | 대화 기록 최대 턴 |
| `CONVERSATION_ACCESS_ENABLED` | 아니오 | `false` | 회원의 기본 대화창 슬롯 1개·계정 최초 체험 대화권 10회와 일회성 추가 구매 잔액의 제한 적용 여부. 게스트의 활성 슬롯 1개·누적 체험 5회는 항상 집행해요. Sandbox와 PostgreSQL 검증 후 활성화해요 |
| `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_KEY_ID`, `APPLE_IAP_PRIVATE_KEY` | 아니오 | 없음 | 이전 배포 환경과의 호환을 위해 읽기만 허용해요. 새 검증 경로에서는 사용하지 않아요 |
| `BILLING_HMAC_KEYS` | 필수 | 없음 | 버전 → 독립 비밀 키 JSON. 각 키 최소 32바이트. 서버 전용 비밀 저장소·백업에 보관하고 기존 tombstone의 버전 키를 유지해요 |
| `BILLING_HMAC_CURRENT_KEY` | 필수 | 없음 | 새 tombstone에 쓰는 키 버전. 키 누락·보관 중인 버전 누락 시 서버 시작을 거부해요 |
| `APPLE_IAP_ENVIRONMENT` | Apple 결제 시 필수 | 없음 | `sandbox` 또는 `production`; 거래 서명과 서버 환경이 일치해야 함 |
| `SUPABASE_SECRET_KEY` | 계정 삭제 시 필수 | 없음 | 서버 전용 Supabase 관리자 키. Auth 사용자 삭제에 사용하며 모바일 환경에 전달하지 않음 |
| `APPLE_SIGNIN_TEAM_ID` | Apple 로그인 연결 해제 시 필수 | 없음 | Apple Developer Team ID |
| `APPLE_SIGNIN_KEY_ID` | Apple 로그인 연결 해제 시 필수 | 없음 | Sign in with Apple 키 ID |
| `APPLE_SIGNIN_CLIENT_ID` | Apple 로그인 연결 해제 시 필수 | 없음 | 네이티브 앱의 Bundle ID |
| `APPLE_SIGNIN_PRIVATE_KEY` | Apple 로그인 연결 해제 시 필수 | 없음 | Sign in with Apple `.p8` 키 본문; 서버 비밀 저장소에서 주입 |
| `APPLE_IAP_BUNDLE_ID` | Apple 결제 시 필수 | 없음 | App Store Connect 앱의 Bundle ID |
| `APPLE_IAP_APP_ID` | 운영 결제 시 필수 | 없음 | App Store Connect의 숫자 Apple 앱 ID |

## 외부 HTTP 연결 풀 v1

AI(LLM·STT·TTS·문법·검색·스낵)와 Supabase 인증은 워커마다 별도의 풀을 가져요. 기본 한도는 각각 100개라 워커 4개면 전체 상한은 최대 800개예요. 미리 연결을 열지는 않아요. 위 설정은 HTTP/1.1 연결 수이며 요청당 timeout(OpenRouter LLM 30초·Ollama 60초·음성/인증 개별 설정)을 바꾸지 않아요. 유휴 만료 전에 upstream이 연결을 닫을 수도 있어요. 실제 동시성에 맞춰 조절하고 변경 후 재시작해요. 내부 수명은 [아키텍처](../.agent/architecture.md#외부-http-연결-풀-v1--구현-결정-2026-09-13)를 참조해요.

## 추가 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `JWT_ALGORITHM` | `HS256` | 레거시 JWT 알고리즘 |
| `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` | `1440` | 레거시 access token 수명(분), Supabase 세션 수명과 별개 |
| `JWT_REFRESH_TOKEN_EXPIRE_DAYS` | `15` | 레거시 refresh token 수명(일) |
| `GOOGLE_CLIENT_ID` | 없음 | 백엔드의 레거시 Google OAuth 설정. Flutter의 동명 dart-define과는 별개 |
| `GOOGLE_CLIENT_SECRET` | 없음 | 백엔드 전용 Google OAuth secret |
| `GOOGLE_REDIRECT_URI` | `http://localhost:8010/api/auth/google/callback` | 레거시 OAuth redirect URI. 현재 모바일 로그인 경로를 변경하지 않아요 |

## Compose 설정

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `CURITALK_ENV_FILE` | `.env` | Compose가 API·생성 컨테이너에 주입할 환경 파일 경로. 셸이나 cron 환경에서 지정하며 로컬 Python CLI의 .env 경로는 바꾸지 않아요 |

Compose의 `environment`는 API와 생성 컨테이너에서 ENV=prod, DEBUG=false, AUTO_CREATE_TABLES=false를 강제해요.

## 스낵 모델과 잠금

- provider: LANGUAGE_SNACKS_PROVIDER가 있으면 사용하고, 없으면 LLM_PROVIDER를 사용해요.
- model: LANGUAGE_SNACKS_MODEL이 있으면 사용하고, 없으면 선택한 provider의 OPENROUTER_MODEL 또는 OLLAMA_MODEL을 사용해요. 후보·중복·본문·품질 검사는 모두 이 설정을 사용해요.
- LANGUAGE_SNACKS_LOCK_DATABASE_URL은 DATABASE_URL과 **같은 DB의 direct 또는 session pooling 연결**이어야 해요. transaction pooling 연결로 session advisory lock을 사용하면 안 돼요.
- PER_TYPE은 1..6, 나머지 스낵 숫자 상한은 양수예요. CLI의 --per-type은 환경변수보다 우선해요.
- 호출·토큰 상한은 언어별 run에 누적되고 시간 제한은 실행 시도별로 적용돼요. 모델의 실제 금액 한도는 provider에서도 별도로 관리해요.

## 변경 기록

- 2026-11-25: 회원 제한 설정의 자원 명칭을 대화창 슬롯·체험 대화권으로 통일했어요.

- 2026-11-25: 소비성 결제 rollout, HMAC keyring/current 버전과 과거 키 보존 조건을 반영했어요.

- 2026-11-15: 관리자 입장 코드를 DB에서 서버 환경변수로 옮겼어요.
- 2026-11-15: 관리자 입장 코드의 길이 제한을 제거했어요.
- 2026-11-15: 관리자 웹 쓰기 요청의 Origin 검사 기준을 명확히 했어요.
- 2026-09-13: README에서 환경변수 설명을 이관하고 실제 Settings의 필수 항목·기본값과 Compose 설정을 구분했어요.

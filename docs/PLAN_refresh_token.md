# Refresh Token 도입 계획

> 범위: FastAPI 백엔드 API · 최종 갱신: 2026-05-26

## 0. 결정 완료(사용자 확정)

- Access token TTL: **유지** (`JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440`, 24시간)
- Refresh token TTL: **15일**
- Refresh token 정책: **Rotating refresh token(rotate)**
- 동시 refresh: **마지막 1개만 유효**(먼저 성공한 요청만 유효, 나머지는 401)
- Refresh token 전달: **JSON body로 반환/전송**
- Logout: **기본 로그아웃만 제공** (`POST /api/auth/logout`)
- Device ID: **요청에서 받기**(기기당 세션 1개만 허용)
- Refresh token 형식: **opaque 랜덤 문자열(권장안)**
- Refresh token 해시: **권장안(HMAC-SHA256, key=`JWT_SECRET_KEY`)**
- Pepper: **미사용** (별도 `REFRESH_TOKEN_PEPPER` 없음)

## 1. 목표

모바일(향후 Flutter) 앱에서 **장기 세션을 안정적으로 유지**할 수 있도록 refresh token 기반 인증 플로우를 도입해요.

- access token이 만료되면 refresh token으로 재발급해요(현재 access TTL은 유지해요).
- 서버는 refresh token을 **저장·회전(rotate)·폐기(revoke)** 할 수 있어야 해요.
- refresh token 원문은 DB에 저장하지 않고, **해시만 저장**해요.

## 2. 현재 상태 요약

- 현재 Auth는 `access_token`(JWT)만 발급해요.
- 환경변수는 `JWT_SECRET_KEY`, `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`만 있어요.
- DB는 앱 시작 시 `Base.metadata.create_all()`로 테이블을 생성해요(마이그레이션 도구 전제 없음).

## 3. 설계 원칙(확정 사항)

### 3.1 토큰 수명(확정)

- Access token TTL: **24시간 유지** (`JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440`)
- Refresh token TTL: **15일** (`JWT_REFRESH_TOKEN_EXPIRE_DAYS=15`)

> 참고: 추후 보안 강화를 위해 access token TTL을 줄일 수 있어요. 그 경우 클라이언트(Flutter)도 “자동 refresh → 원 요청 재시도”가 필수가 돼요.

### 3.2 Refresh token 정책(확정)

- **Rotating refresh token(rotate)**: `POST /api/auth/refresh` 호출 시 refresh token도 매번 새로 발급하고, 기존 refresh token은 즉시 revoke 처리해요.
- 재사용 공격 방지: revoke된 refresh token이 다시 제출되면 401로 거부해요.

### 3.3 동시성(확정)

모바일에서 네트워크 재시도/중복 요청으로 refresh가 동시에 2번 날 수 있어요. **“마지막 1개만 유효”** 정책으로 처리해요.

### 3.4 `device_id` 규칙(확정)

`device_id`는 “기기 ID”가 아니라 **설치(installation) ID**로 정의해요.

- 생성/보관: Flutter 앱이 **최초 실행 시 UUIDv4 생성** → **secure storage**에 저장해요.
- 변경 가능성: 앱 삭제/데이터 초기화/기기 변경 시 `device_id`가 바뀔 수 있어요(정상 동작으로 간주).
- 기기당 세션: `(user_id, device_id)` 조합 기준으로 **활성 refresh token은 1개만 허용**해요.

## 4. 데이터 모델(새 테이블 추가 권장)

기존 `users` 테이블 변경 없이 새 테이블을 추가해요(현재 `create_all` 기반 운영과 충돌이 적어요).

### 4.1 `refresh_tokens` 테이블(초안)

- `id`: UUID (PK)
- `user_id`: UUID (FK → users.id)
- `token_hash`: STRING(고정 길이 권장) (refresh token 원문 해시)
- `expires_at`: DATETIME (만료 시각)
- `revoked_at`: DATETIME? (폐기 시각)
- `created_at`: DATETIME
- `last_used_at`: DATETIME? (감사/운영용)

선택 컬럼(추가 시 운영 편의 ↑)

- `device_id`: STRING? (클라이언트가 생성하는 기기 식별자)
- `user_agent`: STRING?
- `ip`: STRING?

### 4.2 해시 방식(확정)

- 서버가 refresh token 원문을 발급(랜덤/opaque)하고 DB에는 `token_hash`만 저장해요.
- 비교 시에도 원문을 해시해서 DB의 해시와 비교해요.
- 해시 알고리즘: `HMAC-SHA256(token, key=JWT_SECRET_KEY)`로 고정해요(pepper 미사용).
- 별도 pepper는 사용하지 않아요.

## 5. API 계약(추가/변경)

### 5.1 응답 스키마

현재 `TokenResponse`는 `access_token`만 포함해요. refresh token을 내려주려면 아래 중 하나를 선택해요.

- 옵션 A: `TokenResponse`를 확장해 `refresh_token`을 추가해요.
- 옵션 B: 새 스키마 `TokenPairResponse`를 만들고 register/login/google 콜백에서 이를 반환해요.

확정: 옵션 A(간단하고 모바일 연동이 직관적이에요)

### 5.2 신규 엔드포인트

- `POST /api/auth/refresh`
  - Request: `{ refresh_token: string, device_id: string }`
  - Response: `{ access_token: string, refresh_token: string, token_type: "bearer" }`
  - 동작: refresh 검증 → access 재발급 → refresh rotate → 기존 refresh revoke

- `POST /api/auth/logout`
  - Request: `{ refresh_token: string, device_id: string }`
  - Response: success
  - 동작: 해당 refresh token revoke

### 5.3 기존 엔드포인트 영향

- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/google/callback`
  - 기존처럼 access만 주면 모바일 장기 세션이 불가능하므로, **refresh token도 함께 반환**하도록 바꿔요.
  - Request에 `device_id`를 **필수**로 받아 “기기당 세션 1개” 정책을 적용해요.

### 5.4 Google OAuth에서 `device_id` 전달(필수)

`GET /api/auth/google/callback`은 body를 받을 수 없어서, Google OAuth에서도 `device_id` 정책을 유지하려면 **OAuth `state`에 `device_id`를 실어** 왕복해야 해요.

- `GET /api/auth/google/login?device_id=...`로 서버에 `device_id`를 전달해요.
- 서버는 `state`에 `device_id`를 넣고(서명/무결성 보장), Google 인증 URL에 포함해요.
- `GET /api/auth/google/callback`에서 `state`를 검증하고 `device_id`를 복원해 refresh token 발급에 사용해요.

## 6. 환경변수 / 설정 변경(N-way sync 필수)

추가 확정(예시)

- `JWT_REFRESH_TOKEN_EXPIRE_DAYS=15`
- `JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440` (현재 유지)

환경변수 변경 시 아래 표면을 같은 작업 단위로 갱신해요(SSoT 규칙).

- `.env.example`
- `README.md`
- `backend/config.py`

## 7. 구현 작업 순서(권장)

1. 문서 스펙 확정: `docs/DSL.md`, `README.md`에 반영(계약 먼저 고정)
2. 데이터 모델 추가: `refresh_tokens` SQLAlchemy 모델 + 관계(필요 시)
3. Repository 추가: 토큰 저장/조회/revoke/정리 메서드
4. Service 구현: refresh 발급/검증/rotate 로직 + 오류 처리(401/409 등 정책 확정)
5. Router 추가: `/refresh`, `/logout` 엔드포인트 구현
6. 의존성 적용: 인증이 필요한 API 영향 확인(특히 SSE 사용 플로우)
7. 테스트/검증 시나리오 실행(아래 8장)
8. 문서 동기화 최종 점검(아래 9장)

## 8. 검증 시나리오(최소)

- 정상 로그인 → access/refresh 수신
- access 만료(또는 강제) → refresh로 재발급 성공
- rotate 후 이전 refresh로 재요청 → 실패(재사용 공격 방지)
- revoke된 refresh로 refresh 시도 → 실패
- (동시성) refresh 2번 동시 호출 → 정책대로 1개만 성공(또는 grace window 동작 확인)
- (device_id) 동일 사용자/동일 `device_id`로 재로그인 → 기존 refresh 폐기 + 새 refresh 1개만 활성
- (OAuth) Google 로그인에서 `state`로 전달한 `device_id`가 콜백에서 복원되는지 확인

## 9. 문서/DSL 동기화 체크리스트(필수)

API 변경 시 아래를 함께 갱신해요.

- `README.md`
- `docs/DSL.md`
- `backend/domains/auth/router.py`

DB 스키마가 늘면 `docs/DSL.md`의 `database Schema`에도 반영해요.

## 10. 리스크 / 운영 고려

- Refresh token 유출 시 장기 세션 탈취 위험이 있어요 → rotate + 해시 저장 + revoke 지원이 필요해요.
- Access TTL을 향후 짧게 바꾸면 모바일에서 refresh 호출이 늘어요 → rate limit/재시도 정책을 문서로 명시해요(선택).
- 현재 `create_all` 기반이라 스키마 변경 관리가 어려워요 → “새 테이블 추가” 우선으로 설계하고, 추후 Alembic 도입은 별도 태스크로 분리해요.
- `device_id`는 비밀값이 아니어서 스푸핑될 수 있어요 → `device_id`는 “세션 분기 키”로만 사용하고, **인증은 refresh token 검증이 본체**가 되도록 유지해요.
- “기기당 세션 1개” + “동시 refresh는 마지막 1개만 유효” 조합에서는 드물게 refresh가 401로 실패할 수 있어요 → 앱은 아래 UX 규칙을 따라야 해요.

### 10.1 모바일 앱 UX 규칙(권장)

- refresh 401이 발생하면 무한 루프를 피하기 위해 **refresh를 1회만 재시도**해요.
- 재시도에도 실패하면 “로그아웃 처리 + 재로그인 유도”로 전환해요.

## 11. 구현 계획(상세)

이 섹션은 실제 구현을 시작할 때의 작업 순서와 “완료 정의(DoD)”를 정리해요.

### 11.1 완료 정의(DoD)

- `register/login/google`에서 `{ access_token, refresh_token }`가 함께 반환돼요.
- `POST /api/auth/refresh`가 동작하고, rotate 정책에 따라 이전 refresh token은 즉시 무효가 돼요.
- `(user_id, device_id)` 조합당 활성 refresh token은 1개만 존재해요(기기당 세션 1개).
- `POST /api/auth/logout`이 refresh token을 revoke하고, 이후 refresh가 401로 실패해요.
- Google OAuth 플로우에서 `device_id`가 `state`를 통해 콜백까지 전달돼요.
- `README.md`/`docs/DSL.md`/라우터가 동일 계약으로 동기화돼요.

### 11.2 작업 단계(권장 순서)

1. 계약 확정(문서)
   - `docs/DSL.md`: 신규 테이블(`refresh_tokens`), 신규 API(`/refresh`, `/logout`), 요청/응답 스키마 반영
   - `README.md`: 모바일 토큰 저장소/refresh 재시도 UX/Google OAuth의 `device_id` 전달(state) 설명 추가

2. 환경변수/설정 추가(N-way sync)
   - `backend/config.py`: `jwt_refresh_token_expire_days`(15) 추가
   - `.env.example`/`README.md`: `JWT_REFRESH_TOKEN_EXPIRE_DAYS` 추가

3. DB 모델 추가
   - `backend/domains/auth/models.py`: `RefreshTokenModel` 추가(새 테이블)
   - 컬럼: `id`, `user_id`, `device_id`, `token_hash`, `expires_at`, `revoked_at`, `created_at`, `last_used_at`
   - 인덱스: `(user_id, device_id)` 또는 `token_hash` 인덱스(조회 성능)

4. Repository 구현(Auth)
   - `backend/domains/auth/repository.py`:
     - 저장: refresh token hash 저장
     - 조회: `token_hash`로 유효 토큰 조회(만료/폐기 제외)
     - 정책: `(user_id, device_id)` 기존 refresh 토큰 revoke(기기당 1개 유지)
     - 폐기: 단건 revoke, user+device revoke

5. Service 구현(Auth)
   - `backend/domains/auth/service.py`:
     - refresh token 발급: opaque 랜덤 문자열 생성 + `HMAC-SHA256(token, key=JWT_SECRET_KEY)` 해시
     - rotate: refresh 성공 시 새 refresh 발급 + 기존 refresh 즉시 revoke
     - 동시성: “먼저 성공한 요청만 유효”, 나머지는 401
     - device_id 필수 검증: token에 저장된 `device_id`와 불일치 시 401
     - register/login/google 콜백에서 `(user_id, device_id)` 기존 세션 revoke 후 새 refresh 1개 발급

6. Schemas/Router 구현
   - `backend/domains/auth/schemas.py`:
     - `RegisterRequest`, `LoginRequest`에 `device_id: str` 추가
     - `TokenResponse`에 `refresh_token: str` 추가
     - `RefreshRequest`, `LogoutRequest` 스키마 추가(권장)
   - `backend/domains/auth/router.py`:
     - `POST /api/auth/refresh`, `POST /api/auth/logout` 추가
     - 기존 register/login/google 콜백 응답 스키마 갱신
   - `backend/domains/auth/dependencies.py`: 변경 필요 여부 점검(대부분은 access JWT 검증만 유지)

7. Google OAuth `state` 확장
   - `backend/domains/auth/service.py`:
     - `get_google_login_url(device_id)` 형태로 변경(또는 별도 메서드 추가)
     - `state`에 `device_id`를 넣고 서명/검증 로직 추가
   - `backend/domains/auth/router.py`:
     - `GET /api/auth/google/login`에서 `device_id` 쿼리 파라미터 받기
     - `GET /api/auth/google/callback`에서 `state` 검증 후 `device_id` 복원

8. 검증/회귀 점검
   - 본 문서의 “검증 시나리오(최소)”를 순서대로 확인해요.
   - (선택) 단위 테스트 추가 위치가 명확하면 `backend/domains/auth/`에 최소 테스트를 추가해요.

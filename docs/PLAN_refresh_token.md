# Refresh Token 도입 계획

> 범위: FastAPI 백엔드 API · 최종 갱신: 2026-05-25

## 1. 목표

모바일(향후 Flutter) 앱에서 **장기 세션을 안정적으로 유지**할 수 있도록 refresh token 기반 인증 플로우를 도입해요.

- access token은 짧게(권장) 가져가고, 만료 시 refresh token으로 재발급해요.
- 서버는 refresh token을 **저장·회전(rotate)·폐기(revoke)** 할 수 있어야 해요.
- refresh token 원문은 DB에 저장하지 않고, **해시만 저장**해요.

## 2. 현재 상태 요약

- 현재 Auth는 `access_token`(JWT)만 발급해요.
- 환경변수는 `JWT_SECRET_KEY`, `JWT_ACCESS_TOKEN_EXPIRE_MINUTES`만 있어요.
- DB는 앱 시작 시 `Base.metadata.create_all()`로 테이블을 생성해요(마이그레이션 도구 전제 없음).

## 3. 설계 원칙(결정해야 하는 것)

### 3.1 토큰 수명(권장안)

- Access token TTL: 15\~30분 권장 (현재는 `JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440` = 24시간)
- Refresh token TTL: 14\~30일 권장

> 주의: Access token TTL을 짧게 바꾸면 클라이언트(Flutter)에서도 “자동 refresh → 원 요청 재시도” 구현이 필수예요.

### 3.2 Refresh token 정책(권장안)

- **Rotating refresh token**: `POST /api/auth/refresh` 호출 시 refresh token도 매번 새로 발급하고, 기존 refresh token은 즉시 revoke 처리해요.
- 재사용 공격 방지: revoke된 refresh token이 다시 제출되면 401로 거부해요.

### 3.3 동시성(모바일 환경 고려)

모바일에서 네트워크 재시도/중복 요청으로 refresh가 동시에 2번 날 수 있어요. 아래 중 하나를 선택해요.

- 옵션 A(간단): “마지막 1개만 유효”로 두고, 동시 요청 중 하나는 실패하도록 해요.
- 옵션 B(안정): 짧은 grace window(예: 5\~10초) 허용 또는 token family/jti 기반으로 동시성 처리해요.

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

### 4.2 해시 방식(권장)

- 서버가 refresh token 원문을 발급(랜덤/opaque)하고 DB에는 `token_hash`만 저장해요.
- 비교 시에도 원문을 해시해서 DB의 해시와 비교해요.
- 해시에 사용하는 서버 secret(pepper)이 필요하면 환경변수로 분리해요(선택).

## 5. API 계약(추가/변경)

### 5.1 응답 스키마

현재 `TokenResponse`는 `access_token`만 포함해요. refresh token을 내려주려면 아래 중 하나를 선택해요.

- 옵션 A: `TokenResponse`를 확장해 `refresh_token`을 추가해요.
- 옵션 B: 새 스키마 `TokenPairResponse`를 만들고 register/login/google 콜백에서 이를 반환해요.

권장: 옵션 A(간단하고 모바일 연동이 직관적이에요)

### 5.2 신규 엔드포인트

- `POST /api/auth/refresh`
  - Request: `{ refresh_token: string }`
  - Response: `{ access_token: string, refresh_token: string, token_type: "bearer" }`
  - 동작: refresh 검증 → access 재발급 → refresh rotate(권장) → 기존 refresh revoke

- `POST /api/auth/logout`
  - Request: `{ refresh_token: string }` (또는 `Authorization` + “현재 세션 revoke” 규칙)
  - Response: success
  - 동작: 해당 refresh token revoke

선택(추가 시 UX 개선)

- `POST /api/auth/logout-all`
  - Response: success
  - 동작: 사용자 refresh token 전부 revoke(기기 전체 로그아웃)

### 5.3 기존 엔드포인트 영향

- `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/google/callback`
  - 기존처럼 access만 주면 모바일 장기 세션이 불가능하므로, **refresh token도 함께 반환**하도록 바꿔요.

## 6. 환경변수 / 설정 변경(N-way sync 필수)

추가 후보(예시)

- `JWT_REFRESH_TOKEN_EXPIRE_DAYS` (예: 30)
- `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` (권장: 15\~30으로 조정)
- (선택) `REFRESH_TOKEN_PEPPER` (token_hash 계산용 추가 secret)

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

## 9. 문서/DSL 동기화 체크리스트(필수)

API 변경 시 아래를 함께 갱신해요.

- `README.md`
- `docs/DSL.md`
- `backend/domains/auth/router.py`

DB 스키마가 늘면 `docs/DSL.md`의 `database Schema`에도 반영해요.

## 10. 리스크 / 운영 고려

- Refresh token 유출 시 장기 세션 탈취 위험이 있어요 → rotate + 해시 저장 + revoke 지원이 필요해요.
- Access TTL을 짧게 바꾸면 모바일에서 refresh 호출이 늘어요 → rate limit/재시도 정책을 문서로 명시해요(선택).
- 현재 `create_all` 기반이라 스키마 변경 관리가 어려워요 → “새 테이블 추가” 우선으로 설계하고, 추후 Alembic 도입은 별도 태스크로 분리해요.


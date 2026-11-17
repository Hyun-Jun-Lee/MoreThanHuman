# 관리자와 수동 구독 권한 — REVIEW

> 2026-11-15 결정 · 외부 API 명세는 [DSL](../../docs/DSL.md#관리자와-수동-구독-권한)에 있어요.

## 권한

- `profiles.is_admin`은 기본 false예요. 첫 관리자는 운영자가 DB에서 직접 지정해요. API로 관리자 여부를 변경하지 않아요.
- 관리자 웹과 API는 공유 입장 코드로 발급한 접근 세션을 매 요청 확인해요. 관리자 웹 입장에는 Supabase 계정이 필요하지 않아요. `is_admin`은 모바일 계정의 구독 기능 우회에만 사용해요.
- 관리자는 구독 플랜과 관계없이 모든 구독 기능을 사용하고 대화 슬롯·발화 한도가 없어요. 스낵 무제한 반복도 허용해요. 업로드 크기와 외부 제공자 제한은 구독 권한이 아니에요.
- 일반 사용자의 유효 플랜은 Apple과 수동 부여 중 높은 등급이에요. 둘 다 없으면 Free예요. 수동 부여는 Apple 구매 기록을 변경하지 않아요.
- 예약 철회 시각 `revoke_at`에 도달하면 수동 부여는 자동으로 효력을 잃어요. 즉시 철회는 `revoked_at`을 기록해요. 모두 UTC로 저장하고 비교해요.
- 관리자 변경과 대화 생성·발화는 대상 프로필 행 잠금으로 직렬화해요. 한도 하향 시 기존 슬롯을 현재 한도로 재조정해요.

## 관리자 API

- `GET /api/admin/users/`: `q`는 이메일·닉네임 부분 일치 또는 정확한 UUID, `plan`, `source`, `is_admin`, `limit=50`(1..100), `offset=0`을 지원해요. `results`, `total_count`, `limit`, `offset`을 반환해요.
- `GET /api/admin/users/{user_id}/`: 계정 기본 정보와 적용 중인 권한 요약을 반환해요.
- `GET /api/admin/users/{user_id}/entitlement/`: 현재 Apple·수동·최종 권한을 따로 반환해요. Apple 원거래 ID와 결제 비밀은 노출하지 않아요.
- `GET /api/admin/users/{user_id}/manual-entitlement/history/`: 부여 기록을 최신순으로 페이지 조회해요. 교체·즉시 철회 기록을 보존해요.
- `PUT /api/admin/users/{user_id}/manual-entitlement/`: `plan=advance|plus`, `revoke_at`은 미래 ISO 8601 시각 또는 null이에요. 같은 값의 반복 요청은 이력을 늘리지 않아요. 변경 시 이전 부여를 철회하고 새 부여를 저장해요.
- `DELETE /api/admin/users/{user_id}/manual-entitlement/`: 유효 수동 부여를 즉시 철회해요. 이미 없으면 그대로 현재 권한을 반환해요.
- 두 변경 API는 변경된 최종 권한을 반환해요. 대상이 없으면 404, 잘못된 플랜·시각은 422예요.

## 기존 API와 모바일

- `/api/auth/me`와 `/api/auth/bootstrap`의 프로필에 `is_admin`을 추가해요.
- `/api/billing/entitlement/`의 기존 `plan`, `status`, `expires_at`, `slot_limit`, `turn_limit`을 유지하고 `is_admin`, `source`, `unlimited`를 추가해요. 관리자는 `plan=plus`, `source=admin`, 한도 null이에요.
- 관리자 화면은 `api.curitalk.app/admin`에서 제공해요. 기존 모바일 앱은 관리자·수동 권한 표시를 구별하고 서버 접근 응답을 따라요.

## 관리자 웹 접근

- 관리자 웹은 공유 입장 코드 하나로 로그인해요. 같은 코드를 모든 관리자가 사용하며 원본 코드는 `ADMIN_ACCESS_CODE` 환경변수에만 저장해요. 개인별 관리자 계정 확인이 없으므로 수동 부여 이력의 `granted_by`·`revoked_by`는 null이에요.
- PostgreSQL 마이그레이션은 `profiles`, 수동 부여, 관리자 세션·시도 표에 RLS를 켜고 Data API의 `anon`·`authenticated` 직접 권한을 회수해요. 관리자 접근 표는 `service_role`의 직접 표 권한도 회수해요. FastAPI DB 연결은 해당 표의 소유자 또는 RLS 우회 권한이 있는 역할이어야 해요.
- 코드 미설정 시 접근은 닫혀 있어요. 운영자는 환경변수를 설정하고 API를 재시작해 처음 설정하거나 교체해요. 코드 변경 시 서버 세션 조회 키가 바뀌어 기존 접근 세션이 무효화돼요. 코드 자체는 DB·응답·로그·웹 정적 자산에 포함하지 않아요.
- 브라우저에는 서버가 발급한 HttpOnly 쿠키만 저장해요. DB에는 코드가 아닌 무작위 세션 토큰의 코드 기반 HMAC과 만료 시각만 저장해요.
- 관리자 세션은 30분 비활동 또는 발급 후 8시간이 지나면 만료해요. 로그아웃과 코드 교체도 즉시 접근을 막아요. 코드 오류 5회/15분은 요청 IP를 15분 잠가요.
- `POST /api/admin/access/verify/`는 공유 코드를 받아 확인 세션 쿠키와 쓰기 요청용 CSRF 토큰을 발급해요. `GET /api/admin/access/status/`는 세션 상태와 CSRF 토큰을, `POST /api/admin/access/logout/`은 세션 무효화를 처리해요. 인증된 모바일 계정의 Bearer 토큰은 관리자 웹 접근 권한이 아니에요.
- 기존 관리자 API 6개는 모두 확인된 세션 쿠키가 필요해요. PUT·DELETE는 CSRF 토큰도 요구해요. 로그인·코드 확인·세션 상태 이외 관리자 데이터는 확인 전 내려주지 않아요.
- 화면은 사용자 목록 검색·필터·페이지 이동, 사용자 상세의 Apple·수동·최종 권한, 부여·예약 철회·즉시 철회 확인, 부여 이력을 제공해요. 예약 철회 시각은 브라우저 현지 시각으로 입력하고 서버에 시간대를 포함해 전달해요.

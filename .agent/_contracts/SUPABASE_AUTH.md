# Supabase Auth 검증 — ACTIVE

2026-10-15 결정: `auto`가 기본 모드예요. 이 모드에서는 ES256 access token의 서명과 표준 claim을 Supabase JWKS 공개 키로 서버에서 검증해요. JWT 헤더의 `alg`·`kid`를 신뢰하지 않고 ES256과 JWKS 키 유형·알고리즘·용도를 제한해요. `role=authenticated`, `iss`, `aud`, 만료 시각을 확인하고 기존 profile 연결을 유지해요. JWKS는 워커 메모리에서 5분 보관하며 키 ID가 없고 마지막 조회 후 10초가 지났으면 새로 조회해요. JWKS 조회나 서명 검증이 실패하면 인증을 거절하고, 검증되지 않은 token을 profile 조회에 사용하지 않아요.

ES256 외 토큰은 기존 Supabase `/auth/v1/user` 검증을 사용해 기존 세션과 호환해요. `remote` 모드는 모든 토큰을 원격 검증해 롤백에 사용해요. 로컬 검증은 token 만료 전에 발생한 Supabase의 사용자 차단·로그아웃·토큰 폐기를 즉시 확인하지 못할 수 있어요. 해당 즉시성 요구가 있으면 `remote` 모드를 사용해요.

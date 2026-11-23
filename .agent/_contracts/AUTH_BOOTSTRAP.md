# 인증 초기화와 프로필 조회 — REVIEW

2026-11-23 갱신: Supabase 로그인 또는 저장된 세션 복원 후 모바일은 `POST /api/auth/bootstrap`을 한 번 호출해요. Bearer 토큰의 사용자 ID로 프로필을 조회하거나 생성하고, 요청에 `language` 또는 `app_locale`이 있을 때만 각 프로필 기본값을 함께 적용한 최종 `UserProfile`을 반환해요. 요청을 재시도해도 프로필이 중복 생성되지 않고 같은 pending 값이 적용돼요. 성공한 뒤에만 모바일의 pending 학습 언어와 앱 언어를 지워요.

앱 언어는 온보딩에서 한국어 또는 영어로 선택해요. system locale이 `ko`이면 한국어, 그 밖에는 영어를 초기값으로 사용하고 선택 즉시 인증 전 앱 chrome에 반영해요. 이미 온보딩을 마친 설치에 `app_locale` 저장값이 없으면 system locale fallback을 유지해요. 빈 bootstrap 요청은 기존 학습 언어와 앱 언어를 덮어쓰지 않아요.

일반 보호 요청은 토큰을 검증해 사용자 ID만 전달해요. 프로필 필드가 필요한 요청은 기존 프로필을 별도로 조회해요. `is_active`는 인증 차단 정책에서 제외하며 저장 필드와 응답 필드는 기존 클라이언트 호환을 위해 유지해요.

구버전 모바일은 `GET /api/auth/me` 또는 로그인 직후 `PUT /api/auth/me/language-preferences`를 먼저 호출하므로, 이 두 엔드포인트의 프로필 생성은 전환 기간에 유지해요. 신규 클라이언트의 초기화는 bootstrap으로 통합해요.

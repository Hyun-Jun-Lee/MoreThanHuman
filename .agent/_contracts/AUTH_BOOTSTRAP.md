# 인증 초기화와 프로필 조회 — REVIEW

2026-11-23 갱신: Supabase 로그인 또는 저장된 세션 복원 후 모바일은 `POST /api/auth/bootstrap`을 한 번 호출해요. Bearer 토큰의 사용자 ID로 프로필을 조회하거나 생성하고, 요청에 `language` 또는 `app_locale`이 있을 때만 각 프로필 기본값을 함께 적용한 최종 `UserProfile`을 반환해요. 요청을 재시도해도 프로필이 중복 생성되지 않고 같은 pending 값이 적용돼요. 성공한 뒤에만 모바일의 pending 학습 언어와 앱 언어를 지워요.

앱 언어는 온보딩에서 한국어 또는 영어로 선택해요. system locale이 `ko`이면 한국어, 그 밖에는 영어를 초기값으로 사용하고 선택 즉시 인증 전 앱 chrome에 반영해요. 이미 온보딩을 마친 설치에 `app_locale` 저장값이 없으면 system locale fallback을 유지해요. 빈 bootstrap 요청은 기존 학습 언어와 앱 언어를 덮어쓰지 않아요.

일반 보호 요청은 토큰을 검증해 사용자 ID만 전달해요. 프로필 필드가 필요한 요청은 기존 프로필을 별도로 조회해요. `is_active`는 인증 차단 정책에서 제외하며 저장 필드와 응답 필드는 기존 클라이언트 호환을 위해 유지해요.

구버전 모바일은 `GET /api/auth/me` 또는 로그인 직후 `PUT /api/auth/me/language-preferences`를 먼저 호출하므로, 이 두 엔드포인트의 프로필 생성은 전환 기간에 유지해요. 신규 클라이언트의 초기화는 bootstrap으로 통합해요.

2026-11-23 게스트 확장: 온보딩을 마친 기기에 정식 회원 세션이 없으면 모바일은 Supabase 익명 세션을 만들거나 복원한 뒤 같은 bootstrap을 호출해요. 익명 토큰은 이메일 없이 `is_anonymous=true`여야 하며 서버는 `email=null`, `is_guest=true`, 마지막 활동 시각이 있는 프로필을 멱등 생성해요. 응답의 `UserProfile`은 `email`, `is_guest`, `last_active_at`을 포함해요. 명시적 계정 삭제 직후에는 자동 익명 로그인을 보류하고 사용자가 `게스트로 계속`을 선택할 때만 새 익명 세션을 만들어요.

게스트가 아직 다른 계정에 연결되지 않은 신원으로 가입하면 같은 Supabase 사용자 ID를 유지해 프로필과 데이터를 이어가요. 이미 존재하는 계정으로 로그인할 때는 게스트 JWT로 발급한 만료형 일회용 이전 영수증을 회원 JWT로 claim한 뒤 canonical 데이터를 이전해요. 이전 완료 전후의 삭제 tombstone은 옛 게스트 토큰이 프로필을 다시 만들지 못하게 해요.

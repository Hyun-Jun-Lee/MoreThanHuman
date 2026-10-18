# 닉네임 설정 계약

> 상태: ACTIVE · 최종 갱신: 2026-10-18

- `profiles.name`은 Supabase에서 받은 기존 이름으로 유지해요. `profiles.nickname`은 별도 nullable 필드예요.
- migration 시 기존 프로필의 닉네임을 현재 이름으로 채워요. 새 프로필은 null로 만들어요.
- `GET /api/auth/me`의 `nickname: null`은 첫 설정이 완료되지 않은 상태예요. 앱은 로그인 또는 세션 복원 후 필수 팝업을 띄우고 저장 성공 전에는 닫지 않아요.
- `PUT /api/auth/me/nickname`은 인증된 본인의 닉네임만 저장하고 전체 `UserProfile`을 반환해요. 앞뒤 공백 제거와 NFC 정규화 후 1~20자이고 제어 문자는 허용하지 않아요. 다른 계정과 같은 값은 허용해요.
- 앱의 표시 이름과 아바타 이니셜에는 `nickname`을 우선 사용하고, 값이 없을 때만 `name`을 사용해요. 내 정보의 수정 팝업은 취소할 수 있어요.

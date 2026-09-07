# Language Snacks API Contract

> Status: ACTIVE · Updated: 2026-09-06

## Scope

- Home에 표시하는 언어 스낵은 사용자 언어쌍과 무관한 공통 발행 콘텐츠예요.
- v1 콘텐츠는 하나의 편집 언어로 관리하며, 번역·언어쌍별 variant·사용자별 추천은 포함하지 않아요.
- 생성은 운영 환경에서만 수행하며 Flutter 학습자 클라이언트에는 운영 키나 생성 UI를 두지 않아요.

## `GET /api/language-snacks/`

- `Authorization: Bearer <supabase_access_token>`이 필요해요.
- `published_at`이 있는 항목만 `published_at DESC, id DESC` 순서로 반환해요.
- 응답은 `SuccessResponse<List<LanguageSnack>>` envelope예요.

## `POST /api/language-snacks/`

- `X-Operations-Key: <LANGUAGE_SNACKS_OPERATIONS_KEY>`가 필요해요.
- 일반 Bearer 토큰은 이 생성 권한을 대신하지 않아요.
- 서버에 `LANGUAGE_SNACKS_OPERATIONS_KEY`가 설정되지 않았거나 값이 다르면 `403`을 반환하고 row를 만들지 않아요.
- 성공하면 HTTP `201`과 즉시 발행된 `SuccessResponse<LanguageSnack>`을 반환해요.

```json
{
  "category": "Vocabulary",
  "left_label": "British English",
  "left_word": "crisps",
  "right_label": "American English",
  "right_word": "chips",
  "meaning": "둘 다 감자칩을 뜻해요.",
  "example": "Would you like a bag of crisps?"
}
```

## `LanguageSnack`

| 필드 | 설명 |
|------|------|
| `id` | UUID 식별자 |
| `category` | 카드 분류 |
| `left_label`, `right_label` | 두 표현의 맥락 레이블 |
| `left_word`, `right_word` | 비교할 표현 |
| `meaning` | 짧은 설명 |
| `example` | 예문 |
| `published_at` | 학습자 목록에 노출되는 발행 시각 |
| `created_at`, `updated_at` | 서버 기록 시각 |

필수 문자열은 공백만 허용하지 않으며, 길이 제한을 넘으면 `422`로 거절해요.

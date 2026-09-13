# Language Snacks API Contract

> Status: ACTIVE · Version: 2 · Updated: 2026-09-13

외부 계약의 단일 기준은 [DSL Language Snack 모듈](../../docs/DSL.md#5-language-snack-모듈)이에요. CLI는 [README](../../README.md#스낵-콘텐츠-생성), 배포는 [운영 가이드](../../docs/OPERATIONS.md#언어-스낵-운영), 설정은 [환경변수](../../docs/ENVIRONMENT.md), 내부 상태·중복 검사는 [아키텍처](../architecture.md)를 참고해요.

## Scope

- content_language는 학습 대상 언어, explanation_language는 설명 언어예요. 현재 영어 학습은 한국어 설명, 한국어 학습은 영어 설명을 제공해요.
- JSONB payload는 regional_variant, usage_contrast, homonym이며 schema_version은 1이에요. identity와 knowledge_key는 표시 데이터와 분리하며 학습자 API에 노출하지 않아요.
- GET v2는 Bearer profile.target_language 기준 published 최신 12개(최대 30개)를 반환해요.
- POST/PATCH v2는 서버 운영 키로 보호하며 일반 학습자 앱에는 생성 기능·키를 넣지 않아요.
- 정규화 identity UNIQUE와 전체 이력 기반 LLM 중복 검사, 자동 품질 검증을 통과해야 발행해요. 의미 중복 방지에 통계적 오차가 남아요.
- 구 API는 GET 빈 목록 / POST 410을 반환해요. 마이그레이션 시 기존 스낵 데이터는 모두 삭제해요.

## Client

- 학습 언어 변경 시 즉시 재조회하고 언어별 캐시 키를 분리해요. 실패 시 해당 언어의 마지막 성공 목록만 사용해요.
- Home 재진입·앱 복귀 후 5분 이상 경과했다면 재조회하며 슬라이드 타이머는 네트워크를 호출하지 않아요.
- 알려지지 않은 type/schema_version은 건너뛰고 손상된 기존 유형은 응답 실패로 취급해요.
- 오프라인에 이미 저장된 발행 취소 카드를 서버에서 즉시 삭제할 수는 없어요.

## Change Log

- 2026-09-13: 계약 변경 없이 실행·환경변수·운영 문서 링크를 분리.

- 2026-09-12: v1 공통 목록에서 v2 세 유형·학습 언어별 feed·예약 및 주간 생성 계약으로 전환.
- 2026-09-06: 운영 생성 API와 공통 Home 카드 v1 도입.

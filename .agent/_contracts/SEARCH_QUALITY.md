# Search Quality API Contract

> Status: ACTIVE · Updated: 2026-06-05

## `/api/search/`

- 인증된 사용자의 관심 주제를 검색하고, LLM source judge가 accept한 sources만 요약해요.
- 검색 자체는 성공했지만 품질이 부족하면 HTTP 오류가 아니라 `success=true`, `data.ready=false`로 반환해요.
- 외부 검색 provider 장애는 기존처럼 502 계열 오류로 반환해요.

## Response data

| 필드 | 설명 |
|------|------|
| `query` | 사용자가 입력한 원문 |
| `enhanced_query` | 검색 provider에 전달한 보강 쿼리 |
| `ready` | 요약/대화 컨텍스트로 사용할 품질 충족 여부 |
| `summary` | `ready=true`일 때만 생성되는 영어 요약 |
| `sources` | LLM source judge가 accept한 출처 |
| `quality` | LLM source judge 결과를 서버 finalizer가 정규화한 품질 상태 |
| `retry_guidance` | `ready=false`일 때 주제 재입력 안내 |
| `example_queries` | `ready=false`일 때 재입력 예시 |

## Quality rules

- `source_count`는 LLM judge에 전달한 검색 결과 수예요.
- `relevant_source_count`는 LLM judge가 accept한 결과 수예요.
- `dropped_source_count`는 LLM judge가 accept하지 않은 결과 수예요.
- `is_sufficient=true`는 accepted sources가 최소 기준과 품질 플래그 정규화를 통과했다는 뜻이에요.

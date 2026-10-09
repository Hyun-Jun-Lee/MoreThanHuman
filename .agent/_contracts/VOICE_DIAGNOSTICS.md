# Voice Diagnostics Contract

> Status: ACTIVE · Updated: 2026-10-09 · 진단 헤더 v2 (로컬 계약·회귀 검증 완료)

대화 시작·이어 말하기를 포함한 모든 `/api/` 요청과 `/health`에 선택 `X-Request-ID` 헤더와 FastAPI 응답 헤더를 적용해요. 기존 JSON 본문과 인증·저장 동작은 유지해요. 활성 계약의 단일 기준은 [DSL의 API 진단 헤더](../../docs/DSL.md#api-진단-헤더-v2-2026-10-09)예요.

검증 범위는 잘못된 식별자 대체, 동시 요청의 ContextVar 분리, 오류·취소 전파, 음성 서비스 stage 연결, 앱 응답부터 첫 재생까지의 로컬 trace 전달이에요. JSON 필드와 조회는 [API 로그 문서](../../docs/OBSERVABILITY.md), 반복 실험은 [음성 지연 문서](../../docs/VOICE_LATENCY.md)에 있어요. 스트리밍 계약은 아직 제안 상태이며 이 계약에 포함하지 않아요.

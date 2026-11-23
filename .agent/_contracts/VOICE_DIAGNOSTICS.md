# Voice Diagnostics Contract

> Status: ACTIVE · Updated: 2026-10-09 · 진단 헤더 v2 (로컬 계약·회귀 검증 완료)

대화 시작·이어 말하기를 포함한 모든 `/api/` 요청과 `/health`에 선택 `X-Request-ID` 헤더와 FastAPI 응답 헤더를 적용해요. 기존 JSON 본문과 인증·저장 동작은 유지해요. 활성 계약의 단일 기준은 [DSL의 API 진단 헤더](../../docs/DSL.md#api-진단-헤더-v2-2026-10-09)예요.

검증 범위는 잘못된 식별자 대체, 동시 요청의 ContextVar 분리, 오류·취소 전파, 음성 서비스 stage 연결, 앱 응답부터 첫 재생까지의 로컬 trace 전달이에요. JSON 필드·시간 경계·반복 측정 절차는 [API 로그 문서](../../docs/OBSERVABILITY.md)에 있어요. 스트리밍 상태 전이는 별도 [Voice Streaming 계약](VOICE_STREAMING.md)을 따라요.

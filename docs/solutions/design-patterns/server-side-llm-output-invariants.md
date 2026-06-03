---
title: "LLM 생성 ready 상태는 서버 invariant로 검증한다"
date: 2026-06-03
category: design-patterns
module: backend.domains.search
problem_type: design_pattern
component: service_object
severity: medium
applies_when:
  - "LLM 구조화 응답이 API 성공 상태를 결정할 때"
  - "fallback 정규화가 누락된 LLM 필드를 채울 수 있을 때"
  - "제품 흐름이 재시도 가능한 품질 실패와 ready 출력을 구분할 때"
tags: [llm-output-validation, topic-prep, server-side-invariants, ready-state]
---

# LLM 생성 ready 상태는 서버 invariant로 검증한다

## Context

Topic prep 흐름은 LLM에게 검색 결과가 충분한지 판단하게 하고, 영어 대화 시작에 쓸 준비 카드를 생성하게 한다. 코드 리뷰 과정에서 취약한 경로가 발견됐다. 서비스가 LLM의 `quality.is_sufficient: true`를 받아들이면, 실제 카드 구조가 빠져 있어도 성공 카드로 이어질 수 있었다.

이 흐름은 특히 위험했다. 정규화 로직이 누락된 directions와 questions를 기본 fallback 텍스트로 채워주기 때문에, LLM이 완성된 검색 기반 카드를 만들지 않았는데도 API는 `ready=true`를 반환할 수 있었다.

## Guidance

LLM의 자기 평가는 입력값으로만 취급하고, 최종 제품 상태는 서버 invariant가 결정해야 한다.

Topic prep에서 ready로 인정할 최소 invariant는 아래와 같다.

- summary가 비어 있지 않아야 한다.
- 예상한 conversation direction이 모두 정확히 한 번씩 있어야 한다.
- 각 direction은 비어 있지 않은 first question 3개를 가져야 한다.
- quality flag는 실제 JSON boolean `true`일 때만 true로 인정한다.

서비스는 LLM의 품질 판단과 결정적 구조 검증을 함께 통과할 때만 충분한 카드로 인정한다.

```python
llm_is_sufficient = self._as_json_bool(quality_data.get("is_sufficient", False))
has_complete_card = self._has_complete_topic_prep_payload(summary, raw_directions)
is_sufficient = llm_is_sufficient and has_complete_card
```

LLM은 충분하다고 했지만 payload가 불완전하면, 품질 결과를 낮추고 기존 재시도 흐름으로 보낸다.

```python
if llm_is_sufficient and not has_complete_card:
    reason = reason or INCOMPLETE_TOPIC_PREP_CARD_REASON
    retry_suggestion = retry_suggestion or self._build_retry_guidance(topic)
```

검증은 fallback 정규화가 누락된 데이터를 가리기 전에 수행한다.

```python
def _has_complete_topic_prep_payload(self, summary: str, raw_directions: object) -> bool:
    if not summary or not isinstance(raw_directions, list):
        return False
    if len(raw_directions) != len(ConversationDirection):
        return False

    expected_directions = {direction.value for direction in ConversationDirection}
    seen_directions = set()

    for item in raw_directions:
        if not isinstance(item, dict):
            return False

        direction = item.get("direction")
        if direction not in expected_directions or direction in seen_directions:
            return False
        seen_directions.add(direction)

        questions = item.get("first_questions")
        if not isinstance(questions, list) or len(questions) != 3:
            return False
        if any(not str(question).strip() for question in questions):
            return False

    return seen_directions == expected_directions
```

## Why This Matters

LLM은 구조적으로 불완전한 출력에도 높은 확신을 표현할 수 있다. 서비스가 그 확신을 그대로 믿으면 제품 상태와 실제 데이터 품질이 어긋난다. 클라이언트는 ready 카드를 받지만, 카드 안의 질문은 검색 결과에 근거한 질문이 아니라 fallback 질문일 수 있다.

이 invariant는 API 계약을 정직하게 유지한다. `ready=true`는 모델이 충분하다고 말했다는 뜻이 아니라, 백엔드가 완성된 카드를 검증했다는 뜻이어야 한다.

## When to Apply

- LLM 생성 JSON이 `ready`, `valid`, `approved`, `complete`, `is_sufficient` 같은 상태를 제어할 때 적용한다.
- fallback 또는 정규화 계층이 불완전한 모델 출력을 정상 형태처럼 보이게 만들 수 있을 때 적용한다.
- 사용자 경험에 retry guidance 같은 회복 가능한 low-quality path가 있을 때 적용한다.
- 같은 원칙을 request contract에도 적용한다. 문서가 enum을 정의한다면 임의 문자열을 받지 말고 Pydantic schema에서 enum으로 강제한다.

## Examples

이 guard 전에는 아래처럼 LLM이 충분하다고 표시한 불완전 응답도 기본값으로 채워진 ready 카드가 될 수 있었다.

```json
{
  "quality": {
    "is_sufficient": true,
    "relevance": true,
    "freshness": true,
    "specificity": true
  },
  "summary": "",
  "directions": []
}
```

guard 이후에는 같은 응답이 재시도 가능한 품질 실패로 변환된다.

```python
assert card.quality.is_sufficient is False
assert card.quality.retry_suggestion is not None
```

회귀 테스트는 misleading-positive payload를 직접 고정해야 한다.

- LLM은 충분하다고 했지만 summary가 비어 있는 경우
- LLM은 충분하다고 했지만 direction이 누락된 경우
- LLM은 충분하다고 했지만 direction의 질문이 3개보다 적은 경우

## Related

- `backend/domains/search/service.py` — topic prep 카드 생성과 invariant 검증
- `backend/tests/domains/search/test_topic_prep_service.py` — 불완전한 sufficient payload 회귀 테스트
- `backend/domains/conversation/enums.py`, `backend/domains/conversation/schemas.py` — topic prep handoff의 API enum 강제
- `docs/brainstorms/2026-05-27-topic-prep-card-requirements.md` — topic prep 카드의 제품 의도
- `docs/plans/2026-05-27-001-feat-topic-prep-card-plan.md` — 원래 topic prep 구현 계획
- `docs/plans/2026-06-03-001-feat-search-quality-pipeline-plan.md` — 관련 deterministic quality gate 계획

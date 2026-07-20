from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_user
from domains.search.router import get_search_service, router
from domains.search.schemas import (
    ConversationDirection,
    TopicPrepCard,
    TopicPrepDirection,
    TopicPrepQuality,
    TopicPrepResult,
)
from shared.language import LearningLanguageContext


def _app_with_overrides(service) -> FastAPI:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id="user-1",
        language=LearningLanguageContext(
            native_language="zh",
            target_language="ko",
            feedback_language="zh",
        ),
    )
    app.dependency_overrides[get_search_service] = lambda: service
    return app


def _ready_result(topic: str) -> TopicPrepResult:
    quality = TopicPrepQuality(
        is_sufficient=True,
        source_count=3,
        has_enough_sources=True,
        relevance=True,
        freshness=True,
        specificity=True,
    )
    card = TopicPrepCard(
        topic=topic,
        summary="A specific topic summary.",
        directions=[
            TopicPrepDirection(
                direction=direction,
                title=direction.value,
                description=f"{direction.value} description",
                first_questions=["Question one?", "Question two?", "Question three?"],
            )
            for direction in ConversationDirection
        ],
        sources=[],
        quality=quality,
        timestamp=datetime.now(UTC),
    )
    return TopicPrepResult(ready=True, card=card, quality=quality)


def test_prepare_topic_endpoint_returns_card_for_authenticated_user():
    class FakeService:
        async def prepare_topic(self, topic: str, language_context=None) -> TopicPrepResult:
            assert language_context.target_language.value == "ko"
            return _ready_result(topic)

    client = TestClient(_app_with_overrides(FakeService()))

    response = client.post("/api/search/topic-prep/", json={"topic": "recent Dodgers game"})

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["ready"] is True
    assert body["data"]["card"]["topic"] == "recent Dodgers game"
    assert len(body["data"]["card"]["directions"]) == 4


def test_prepare_topic_endpoint_returns_retry_guidance_for_low_quality_topic():
    class FakeService:
        async def prepare_topic(self, _topic: str, language_context=None) -> TopicPrepResult:
            quality = TopicPrepQuality(
                is_sufficient=False,
                source_count=1,
                has_enough_sources=False,
                relevance=False,
                freshness=False,
                specificity=False,
                reason="너무 넓은 주제예요.",
                retry_suggestion="날짜나 사건명을 포함해 다시 입력해보세요.",
            )
            return TopicPrepResult(
                ready=False,
                quality=quality,
                retry_guidance=quality.retry_suggestion,
                example_topics=["2026년 5월 Dodgers 경기 결과"],
            )

    client = TestClient(_app_with_overrides(FakeService()))

    response = client.post("/api/search/topic-prep/", json={"topic": "요즘 이슈"})

    assert response.status_code == 200
    body = response.json()
    assert body["data"]["ready"] is False
    assert body["data"]["card"] is None
    assert "날짜" in body["data"]["retry_guidance"]


def test_prepare_topic_endpoint_requires_authentication():
    app = FastAPI()
    app.include_router(router)
    client = TestClient(app)

    response = client.post("/api/search/topic-prep/", json={"topic": "recent Dodgers game"})

    assert response.status_code in {401, 403}

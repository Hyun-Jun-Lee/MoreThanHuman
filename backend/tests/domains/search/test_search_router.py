from datetime import UTC, datetime
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_user
from domains.search.router import get_search_service, router
from domains.search.schemas import SearchQuality, SearchResult, SearchResultItem
from shared.language import LearningLanguageContext


def _app_with_overrides(service) -> FastAPI:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id="user-1",
        language=LearningLanguageContext(
            native_language="zh",
            target_language="en",
            feedback_language="zh",
        ),
    )
    app.dependency_overrides[get_search_service] = lambda: service
    return app


def _quality(is_sufficient: bool) -> SearchQuality:
    return SearchQuality(
        is_sufficient=is_sufficient,
        source_count=3,
        relevant_source_count=2 if is_sufficient else 0,
        dropped_source_count=1 if is_sufficient else 3,
        relevance=is_sufficient,
        freshness=True,
        specificity=is_sufficient,
        reason=None if is_sufficient else "검색 결과가 주제와 충분히 관련되어 있지 않아요.",
        retry_suggestion=None if is_sufficient else "더 구체적인 주제로 다시 입력해보세요.",
    )


def test_search_endpoint_returns_llm_accepted_sources_for_authenticated_user():
    class FakeService:
        async def search(self, query: str, language_context=None) -> SearchResult:
            assert language_context.native_language.value == "zh"
            return SearchResult(
                query=query,
                enhanced_query="Osaka restaurants Dotonbori",
                ready=True,
                summary="Osaka has many food options around Dotonbori.",
                sources=[
                    SearchResultItem(
                        title="Dotonbori food guide",
                        url="https://example.com/1",
                        snippet="Takoyaki, okonomiyaki, and ramen spots.",
                    )
                ],
                quality=_quality(True),
                timestamp=datetime.now(UTC),
            )

    client = TestClient(_app_with_overrides(FakeService()))

    response = client.post("/api/search/", json={"query": "오사카 여행 맛집 추천"})

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert body["data"]["ready"] is True
    assert body["data"]["sources"][0]["title"] == "Dotonbori food guide"
    assert "relevance_score" not in body["data"]["sources"][0]


def test_search_endpoint_returns_low_quality_state_without_summary():
    class FakeService:
        async def search(self, query: str, language_context=None) -> SearchResult:
            return SearchResult(
                query=query,
                enhanced_query="요즘 최신 뉴스",
                ready=False,
                summary=None,
                sources=[],
                quality=_quality(False),
                retry_guidance="더 구체적인 주제로 다시 입력해보세요.",
                example_queries=["2026년 6월 AI 규제 뉴스"],
                timestamp=datetime.now(UTC),
            )

    client = TestClient(_app_with_overrides(FakeService()))

    response = client.post("/api/search/", json={"query": "요즘 이슈"})

    assert response.status_code == 200
    body = response.json()
    assert body["data"]["ready"] is False
    assert body["data"]["summary"] is None
    assert body["data"]["retry_guidance"] is not None

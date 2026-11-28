import json
from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_ai_profile
from domains.llm.schemas import LLMResponse
from domains.search.router import get_search_service, router
from domains.search.schemas import TopicPrepQuestionsResult
from domains.search.service import SearchService
from shared.exceptions import ExternalAPIException
from shared.language import LearningLanguageContext
from shared.language_prompt_policy import format_topic_prep_priorities


PAYLOAD = {
    "topic": "baseball",
    "focus": "DEBATE: pitching choices",
    "summary": "A close game.",
    "previous_questions": ["Old one?", "Old two?", "Old three?"],
}
RESULT = {
    "first_questions": ["New one?", "New two?", "New three?"],
    "first_question_translations": ["새 질문 하나?", "새 질문 둘?", "새 질문 셋?"],
}


def test_questions_endpoint_passes_context_and_returns_only_questions():
    class Service:
        async def regenerate_topic_prep_questions(self, topic, focus, summary, previous_questions, language_context):
            assert (topic, focus, summary, previous_questions) == tuple(PAYLOAD.values())
            assert language_context.target_language.value == "en"
            return TopicPrepQuestionsResult(**RESULT)

    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_ai_profile] = lambda: SimpleNamespace(language=LearningLanguageContext())
    app.dependency_overrides[get_search_service] = lambda: Service()
    client = TestClient(app)
    response = client.post("/api/search/topic-prep/questions/", json=PAYLOAD)
    assert response.status_code == 200
    assert response.json()["data"] == RESULT
    invalid = client.post("/api/search/topic-prep/questions/", json={**PAYLOAD, "previous_questions": []})
    assert invalid.status_code == 422


def test_questions_endpoint_requires_auth():
    app = FastAPI()
    app.include_router(router)
    response = TestClient(app).post("/api/search/topic-prep/questions/", json=PAYLOAD)
    assert response.status_code in {401, 403}


@pytest.mark.asyncio
@pytest.mark.parametrize("target,question_language,translation_language", [("en", "English", "Korean"), ("ko", "Korean", "English")])
async def test_questions_generation_uses_existing_context_without_search(monkeypatch, target, question_language, translation_language):
    class Provider:
        async def chat_completion(self, request):
            assert f"questions in {question_language}" in request.messages[0].content
            assert f"faithful {translation_language}" in request.messages[0].content
            prompt = request.messages[0].content
            assert format_topic_prep_priorities(target) in prompt
            other_language = "ko" if target == "en" else "en"
            assert format_topic_prep_priorities(other_language) not in prompt
            assert "Questions must be specific to the topic" in prompt
            assert 'must not be generic questions like "Do you like baseball?"' in prompt
            assert json.loads(request.messages[1].content) == PAYLOAD
            return LLMResponse(content=json.dumps(RESULT))

    service = SearchService()
    async def unexpected_search(*args, **kwargs):
        pytest.fail("Question regeneration must not run search")
    monkeypatch.setattr(service, "_prepare_search_results", unexpected_search)
    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: Provider())
    result = await service.regenerate_topic_prep_questions(**PAYLOAD, language_context=LearningLanguageContext(
        native_language="en" if target == "ko" else "ko", target_language=target,
    ))
    assert result.model_dump() == RESULT


@pytest.mark.asyncio
@pytest.mark.parametrize("invalid", [
    {**RESULT, "first_question_translations": ["Only one"]},
    {**RESULT, "first_questions": ["New one?", "New two?", " "]},
    {**RESULT, "first_questions": ["New one?", "New one?", "New three?"]},
    {**RESULT, "first_questions": [" old ONE? ", "New two?", "New three?"]},
])
async def test_questions_reject_incomplete_or_repeated_results(monkeypatch, invalid):
    class Provider:
        async def chat_completion(self, request):
            return LLMResponse(content=json.dumps(invalid))
    monkeypatch.setattr("domains.search.service.LLMProviderFactory.create_provider", lambda **kwargs: Provider())
    with pytest.raises(ExternalAPIException):
        await SearchService().regenerate_topic_prep_questions(**PAYLOAD)

from types import SimpleNamespace

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_user
from domains.conversation.enums import ConversationType, RoleplayDifficulty
from domains.conversation.router import get_conversation_service, router
from domains.conversation.service import ConversationService
from shared.language import LearningLanguageContext


def _conversation_app_with_overrides(service) -> FastAPI:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(
        id="user-1",
        language=LearningLanguageContext(
            native_language="en",
            target_language="ko",
            feedback_language="en",
        ),
    )
    app.dependency_overrides[get_conversation_service] = lambda: service
    return app


def test_free_chat_prompt_includes_topic_prep_handoff_context():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(
        search_context="The Dodgers won with a late home run.",
        topic="recent Dodgers game result",
        conversation_direction="DEBATE",
        selected_question="Was the manager's late-game decision right?",
    )

    assert "Topic Prep Handoff" in prompt
    assert "recent Dodgers game result" in prompt
    assert "DEBATE" in prompt
    assert "Was the manager's late-game decision right?" in prompt
    assert "counterarguments" in prompt


def test_free_chat_prompt_without_topic_prep_keeps_existing_shape():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(search_context=None)

    assert "Topic Prep Handoff" not in prompt
    assert "friendly and helpful English conversation learning assistant" in prompt


def test_free_chat_prompt_can_target_korean_with_english_feedback():
    service = ConversationService(repository=None, grammar_repository=None)
    context = LearningLanguageContext(
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    prompt = service.build_free_chat_prompt(search_context=None, language_context=context)

    assert "Korean conversation learning assistant" in prompt
    assert "Always communicate in Korean" in prompt
    assert "Use English only for brief explanations" in prompt
    assert "particles" in prompt
    assert "honorific" in prompt


def test_free_chat_prompt_includes_english_target_policy_by_default():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(search_context=None)

    assert "tense" in prompt
    assert "articles" in prompt
    assert "question formation" in prompt


def test_roleplay_prompt_uses_korean_target_examples():
    service = ConversationService(repository=None, grammar_repository=None)
    context = LearningLanguageContext(
        native_language="en",
        target_language="ko",
        feedback_language="en",
    )

    prompt = service.build_roleplay_prompt(
        "a front desk staff member helping with check-in",
        language_context=context,
    )

    assert "Korean Cafe Staff" in prompt
    assert "honorific level" in prompt
    assert "particles" in prompt
    assert "English Teacher" not in prompt
    assert "Always communicate in Korean" in prompt


def test_roleplay_prompt_uses_english_target_examples_without_teacher_frame():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_roleplay_prompt("a hotel front desk staff member")

    assert "Meeting Participant" in prompt
    assert "English Teacher" not in prompt
    assert "Always communicate in English" in prompt


def test_roleplay_prompt_includes_difficulty_guidance():
    service = ConversationService(repository=None, grammar_repository=None)

    easy_prompt = service.build_roleplay_prompt(
        "a cafe barista",
        roleplay_difficulty=RoleplayDifficulty.EASY,
    )
    challenge_prompt = service.build_roleplay_prompt(
        "a cafe barista",
        roleplay_difficulty=RoleplayDifficulty.CHALLENGE,
    )

    assert "gentle pace" in easy_prompt
    assert "unexpected follow-up questions" in challenge_prompt


@pytest.mark.asyncio
async def test_start_roleplay_stores_role_and_difficulty_separately():
    repository = _FakeConversationRepository()
    service = _FakeConversationService(repository)
    role_character = "a friendly cafe barista taking an order"

    response = await service.start_roleplay_conversation(
        role_character,
        user_id="user-1",
        roleplay_difficulty=RoleplayDifficulty.NORMAL,
    )

    saved = repository.conversation
    assert saved.conversation_type == ConversationType.ROLE_PLAYING
    assert saved.role_character == role_character
    assert saved.roleplay_difficulty == RoleplayDifficulty.NORMAL
    assert "keeps everyday pacing" not in saved.role_character
    assert response.roleplay_difficulty == RoleplayDifficulty.NORMAL
    assert "keeps everyday pacing" in service.generated_prompts[0]["system"]


@pytest.mark.asyncio
async def test_start_roleplay_defaults_difficulty_and_truncates_title():
    repository = _FakeConversationRepository()
    service = _FakeConversationService(repository)
    role_character = "a realistic counterpart " * 20

    await service.start_roleplay_conversation(role_character, user_id="user-1")

    saved = repository.conversation
    assert saved.roleplay_difficulty == RoleplayDifficulty.NORMAL
    assert len(saved.title) <= 200


def test_start_free_chat_rejects_invalid_topic_prep_direction():
    class FakeService:
        async def start_free_chat_conversation(self, *args, **kwargs):
            raise AssertionError("Service should not run when request validation fails")

    client = TestClient(_conversation_app_with_overrides(FakeService()))

    response = client.post(
        "/api/conversations/start/free-chat/",
        json={
            "first_message": "I think the decision was right.",
            "conversation_direction": "INVALID_DIRECTION",
        },
    )

    assert response.status_code == 422


class _FakeConversationRepository:
    def __init__(self):
        self.conversation = None
        self.messages = []
        self.message_count_updates = []

    def save(self, conversation):
        self.conversation = conversation
        return conversation

    def save_message(self, message):
        self.messages.append(message)
        return message

    def update_message_count(self, conversation_id, user_id, count):
        self.message_count_updates.append(
            {
                "conversation_id": conversation_id,
                "user_id": user_id,
                "count": count,
            }
        )


class _FakeConversationService(ConversationService):
    def __init__(self, repository):
        super().__init__(repository=repository, grammar_repository=None)
        self.generated_prompts = []

    async def generate_response(self, system_prompt, messages, user_message):
        self.generated_prompts.append(
            {
                "system": system_prompt,
                "messages": messages,
                "user": user_message,
            }
        )
        return "Welcome in. What would you like to practice?"

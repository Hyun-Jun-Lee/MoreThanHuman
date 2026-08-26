from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from domains.auth.dependencies import get_current_user
from domains.conversation.enums import ConversationType, RoleplayDifficulty
from domains.conversation.router import (
    _enforce_voice_content_length_limit,
    get_conversation_service,
    get_voice_service,
    router,
)
from domains.conversation.schemas import ConversationResponse, MessageResponse
from domains.voice.schemas import VoiceAudioResponse, VoiceInputMode
from shared.language import LearningLanguageContext
from shared.exceptions import ExternalAPIException, ValidationException


class FakeConversationService:
    def __init__(self):
        self.started = []
        self.continued = []

    async def start_free_chat_conversation(
        self,
        first_message,
        search_context=None,
        user_id="",
        topic=None,
        conversation_direction=None,
        selected_question=None,
        language_context=None,
    ):
        self.started.append(
            {
                "first_message": first_message,
                "search_context": search_context,
                "user_id": user_id,
                "topic": topic,
                "conversation_direction": conversation_direction,
                "selected_question": selected_question,
                "language_context": language_context,
            }
        )
        return ConversationResponse(
            conversation_id=uuid4(),
            message_id=uuid4(),
            conversation_type=ConversationType.FREE_CHAT,
            response="Where would you like to travel first?",
            grammar_feedback=None,
        )

    async def start_roleplay_conversation(
        self,
        role_character,
        search_context=None,
        user_id="",
        roleplay_difficulty=RoleplayDifficulty.NORMAL,
        language_context=None,
    ):
        self.started.append(
            {
                "role_character": role_character,
                "search_context": search_context,
                "user_id": user_id,
                "roleplay_difficulty": roleplay_difficulty,
                "language_context": language_context,
            }
        )
        return ConversationResponse(
            conversation_id=uuid4(),
            message_id=uuid4(),
            conversation_type=ConversationType.ROLE_PLAYING,
            role_character=role_character,
            roleplay_difficulty=roleplay_difficulty,
            response="Welcome in. What would you like to practice?",
            grammar_feedback=None,
        )

    async def continue_conversation(self, conversation_id, user_message, user_id=""):
        self.continued.append(
            {
                "conversation_id": conversation_id,
                "user_message": user_message,
                "user_id": user_id,
            }
        )
        return MessageResponse(
            message_id=uuid4(),
            response="That sounds useful. Let's practice it.",
            grammar_feedback=None,
            turn_count=2,
        )


class FakeVoiceProvider:
    def get_provider_name(self):
        return "fake"


class FakeVoiceService:
    def __init__(self, *, fail_tts=False, fail_stt=False):
        self.provider = FakeVoiceProvider()
        self.fail_tts = fail_tts
        self.fail_stt = fail_stt
        self.resolved_inputs = []
        self.synthesized = []

    async def resolve_input_text(self, *, text, audio_file):
        self.resolved_inputs.append({"text": text, "audio_file": audio_file})
        if text and audio_file is not None:
            raise AssertionError("ambiguous input should be rejected before fake service")
        if audio_file is not None:
            if self.fail_stt:
                raise ExternalAPIException("STT failed")
            return VoiceInputMode.AUDIO, "transcribed travel answer"
        if text and text.strip():
            return VoiceInputMode.TEXT, text.strip()
        from shared.exceptions import ValidationException

        raise ValidationException("Either text or audio_file is required.")

    async def synthesize_response(self, text):
        self.synthesized.append(text)
        if self.fail_tts:
            raise ExternalAPIException("TTS failed")
        return VoiceAudioResponse(
            content_type="audio/mpeg",
            base64="YXVkaW8=",
            format="mp3",
        )


def _conversation_app_with_overrides(conversation_service, voice_service) -> FastAPI:
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
    app.dependency_overrides[get_conversation_service] = lambda: conversation_service
    app.dependency_overrides[get_voice_service] = lambda: voice_service
    return app


def test_multimodal_turn_accepts_text_input_without_stt_or_tts():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))
    conversation_id = uuid4()

    response = client.post(
        f"/api/conversations/{conversation_id}/turn/",
        json={"text": "I want to practice travel English."},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["input_mode"] == "text"
    assert data["transcript"] == "I want to practice travel English."
    assert data["audio"] is None
    assert conversation_service.continued[0]["user_message"] == "I want to practice travel English."
    assert voice_service.synthesized == []


def test_multimodal_turn_accepts_audio_input_and_returns_tts_audio():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))
    conversation_id = uuid4()

    response = client.post(
        f"/api/conversations/{conversation_id}/turn/",
        data={"include_audio_response": "true"},
        files={"audio_file": ("speech.webm", b"fake audio", "audio/webm")},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["input_mode"] == "audio"
    assert data["transcript"] == "transcribed travel answer"
    assert data["audio"]["base64"] == "YXVkaW8="
    assert data["audio_error"] is None
    assert conversation_service.continued[0]["user_message"] == "transcribed travel answer"
    assert voice_service.synthesized == ["That sounds useful. Let's practice it."]


def test_multimodal_turn_returns_audio_error_without_second_turn_when_tts_fails():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService(fail_tts=True)
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        f"/api/conversations/{uuid4()}/turn/",
        data={"text": "Hello", "include_audio_response": "true"},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["response"] == "That sounds useful. Let's practice it."
    assert data["audio"] is None
    assert data["audio_error"]["message"] == "TTS failed"
    assert len(conversation_service.continued) == 1


def test_multimodal_turn_rejects_missing_input_before_services_run():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(f"/api/conversations/{uuid4()}/turn/", json={})

    assert response.status_code == 400
    assert conversation_service.continued == []
    assert voice_service.synthesized == []


def test_multimodal_turn_rejects_unsupported_content_type():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        f"/api/conversations/{uuid4()}/turn/",
        content="hello",
        headers={"content-type": "text/plain"},
    )

    assert response.status_code == 415
    assert conversation_service.continued == []


def test_multimodal_turn_rejects_malformed_json():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        f"/api/conversations/{uuid4()}/turn/",
        content="{",
        headers={"content-type": "application/json"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Malformed JSON body."
    assert conversation_service.continued == []


def test_multimodal_turn_maps_stt_external_failure_to_502():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService(fail_stt=True)
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        f"/api/conversations/{uuid4()}/turn/",
        files={"audio_file": ("speech.webm", b"fake audio", "audio/webm")},
    )

    assert response.status_code == 502
    assert response.json()["detail"] == "STT failed"
    assert conversation_service.continued == []


def test_free_chat_start_accepts_audio_input_with_topic_prep_fields():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        "/api/conversations/start/free-chat/",
        data={
            "topic": "travel plans",
            "conversation_direction": "DEBATE",
            "selected_question": "Is slow travel better?",
            "search_context": "Slow travel is trending.",
        },
        files={"audio_file": ("speech.webm", b"fake audio", "audio/webm")},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["input_mode"] == "audio"
    assert data["transcript"] == "transcribed travel answer"
    assert conversation_service.started[0]["first_message"] == "transcribed travel answer"
    assert conversation_service.started[0]["topic"] == "travel plans"
    assert conversation_service.started[0]["conversation_direction"] == "DEBATE"
    assert conversation_service.started[0]["selected_question"] == "Is slow travel better?"
    assert conversation_service.started[0]["language_context"].target_language.value == "ko"


def test_free_chat_start_keeps_existing_json_text_contract():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        "/api/conversations/start/free-chat/",
        json={"first_message": "Let's talk about food."},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["input_mode"] == "text"
    assert data["transcript"] == "Let's talk about food."
    assert conversation_service.started[0]["first_message"] == "Let's talk about food."


def test_roleplay_start_returns_tts_audio_when_requested():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        "/api/conversations/start/roleplay/",
        json={
            "role_character": "A cafe customer who asks follow-ups.",
            "roleplay_difficulty": "CHALLENGE",
            "include_audio_response": True,
        },
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["conversation_type"] == "ROLE_PLAYING"
    assert data["roleplay_difficulty"] == "CHALLENGE"
    assert data["input_mode"] == "text"
    assert data["audio"]["base64"] == "YXVkaW8="
    assert data["audio_error"] is None
    assert conversation_service.started[0]["role_character"] == "A cafe customer who asks follow-ups."
    assert conversation_service.started[0]["roleplay_difficulty"] == RoleplayDifficulty.CHALLENGE
    assert voice_service.synthesized == ["Welcome in. What would you like to practice?"]


def test_roleplay_start_defaults_difficulty_to_normal():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    response = client.post(
        "/api/conversations/start/roleplay/",
        json={"role_character": "A cafe customer."},
    )

    assert response.status_code == 200
    data = response.json()["data"]
    assert data["roleplay_difficulty"] == "NORMAL"
    assert conversation_service.started[0]["roleplay_difficulty"] == RoleplayDifficulty.NORMAL


def test_multimodal_routes_publish_request_body_contracts():
    conversation_service = FakeConversationService()
    voice_service = FakeVoiceService()
    client = TestClient(_conversation_app_with_overrides(conversation_service, voice_service))

    schema = client.get("/openapi.json").json()

    free_chat_body = schema["paths"]["/api/conversations/start/free-chat/"]["post"]["requestBody"]
    roleplay_body = schema["paths"]["/api/conversations/start/roleplay/"]["post"]["requestBody"]
    turn_body = schema["paths"]["/api/conversations/{conversation_id}/turn/"]["post"]["requestBody"]
    assert "application/json" in free_chat_body["content"]
    assert "multipart/form-data" in free_chat_body["content"]
    roleplay_schema = roleplay_body["content"]["application/json"]["schema"]
    roleplay_ref = roleplay_schema["$ref"].rsplit("/", 1)[-1]
    roleplay_properties = schema["components"]["schemas"][roleplay_ref]["properties"]
    assert "roleplay_difficulty" in roleplay_properties
    assert "application/json" in turn_body["content"]
    assert "multipart/form-data" in turn_body["content"]


def test_content_length_limit_rejects_oversized_form_before_parse():
    request = SimpleNamespace(headers={"content-length": str(12 * 1024 * 1024)})

    with pytest.raises(ValidationException, match="request body exceeds"):
        _enforce_voice_content_length_limit(request)

from types import SimpleNamespace

import pytest
from fastapi import HTTPException
from domains.conversation.router import ACCENT_VOICES, _start_accent, _use_accent
from domains.voice.service import VoiceService


@pytest.mark.parametrize('accent', ['us', 'gb', 'au'])
def test_saved_accent_and_explicit_request_override(accent):
    voice = VoiceService()
    assert _start_accent(SimpleNamespace(tts_accent=accent), voice) == accent
    assert voice.audio_profile['voice'] == ACCENT_VOICES[accent]
    _use_accent(voice, 'gb')
    assert voice.audio_profile['voice'] == ACCENT_VOICES['gb']
    voice.request_accent = 'au'
    voice.tts_voice = ACCENT_VOICES['au']
    _use_accent(voice, 'gb')
    assert voice.audio_profile['voice'] == ACCENT_VOICES['au']


def test_conflicting_start_options_rejected():
    voice = VoiceService()
    voice.request_accent = 'au'
    with pytest.raises(HTTPException) as exc:
        _start_accent(SimpleNamespace(tts_accent='gb'), voice)
    assert exc.value.status_code == 422

@pytest.mark.parametrize('as_form', [False, True])
def test_json_and_audio_form_select_same_accent(as_form):
    from fastapi import Depends, FastAPI, Request
    from fastapi.testclient import TestClient
    from domains.conversation.router import _parse_free_chat_input, get_voice_service
    from shared.http_clients import get_ai_http_client
    app = FastAPI()
    app.dependency_overrides[get_ai_http_client] = lambda: object()

    @app.post('/start')
    async def start(request: Request, voice=Depends(get_voice_service)):
        body, _, _ = await _parse_free_chat_input(request)
        return {'accent': _start_accent(body, voice), 'profile': voice.audio_profile}

    client = TestClient(app)
    payload = {'first_message': 'Hello', 'tts_accent': 'gb'}
    response = client.post('/start', data=payload) if as_form else client.post('/start', json=payload)
    assert response.status_code == 200
    assert response.json()['profile']['voice'] == ACCENT_VOICES['gb']
    assert client.post('/start?tts_accent=au', json=payload).status_code == 422


def test_roleplay_retry_completion_and_followup_keep_accent(monkeypatch):
    from uuid import uuid4
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    from database import Base
    from domains.auth.models import ProfileModel
    from domains.conversation.models import ConversationModel
    from domains.conversation.stream_flow import prepare_generation, complete_generated_text
    from domains.conversation.stream_turns import StreamTurnStore

    class Tasks:
        def start(self, coroutine):
            coroutine.close()

    engine = create_engine('sqlite://')
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine)
    monkeypatch.setattr('domains.conversation.stream_flow.SessionLocal', sessions)
    user_id = str(uuid4())
    with sessions() as db:
        db.add(ProfileModel(id=user_id, email='accent@example.com', name='Learner'))
        db.commit()
    common = dict(user_id=user_id, http_client=None, background_tasks=Tasks())
    prepared = prepare_generation(**common, request_id=str(uuid4()), kind='roleplay_start', input_data={
        'role_character': 'a barista', 'tts_accent': 'au',
        'language': {'native_language': 'ko', 'target_language': 'en', 'feedback_language': 'ko'},
    })
    assert prepared.tts_accent == 'au'
    with sessions() as db:
        StreamTurnStore(db).fail(prepared.turn_id, 'TEST_FAILURE')
    retried = prepare_generation(**common, request_id=str(uuid4()), kind=None, input_data=None,
                                 retry_turn_id=prepared.turn_id)
    assert retried.tts_accent == 'au'
    conversation_id, _ = complete_generated_text(user_id, retried, 'Welcome!')
    with sessions() as db:
        assert db.get(ConversationModel, conversation_id).tts_accent == 'au'
    followup = prepare_generation(**common, request_id=str(uuid4()), kind='turn', input_data={
        'conversation_id': conversation_id, 'text': 'Coffee please.', 'input_mode': 'text',
    })
    assert followup.tts_accent == 'au'
    engine.dispose()

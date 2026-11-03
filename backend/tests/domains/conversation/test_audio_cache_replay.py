"""재생 API가 저장 파일을 우선하고, 파일이 사라지면 다시 생성하는지 확인해요."""

import json
from datetime import datetime, timedelta
from uuid import UUID, uuid4

import pytest
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation import audio_cache_flow, router
from domains.conversation.audio_cache import AudioCacheFiles, AudioCacheWriter
from domains.conversation.audio_cache_store import AudioCacheStore
from domains.conversation.enums import MessageRole
from domains.conversation.models import ConversationModel, MessageModel, StreamTurnModel
from domains.voice.schemas import VoiceAudioResponse


@pytest.mark.asyncio
async def test_cached_replay_and_missing_file_regeneration(tmp_path, monkeypatch):
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine, expire_on_commit=False)
    monkeypatch.setattr(router, "SessionLocal", sessions)
    monkeypatch.setattr(audio_cache_flow, "SessionLocal", sessions)
    files = AudioCacheFiles(tmp_path)
    monkeypatch.setattr(router, "cache_files", lambda: files)
    monkeypatch.setattr(router, "new_writer", lambda: files.writer(str(uuid4())))

    user_id, conversation_id, message_id = (str(uuid4()) for _ in range(3))
    with sessions() as db:
        user = ProfileModel(id=user_id, email="cache@example.com", name="Learner")
        db.add(user)
        db.add(ConversationModel(id=conversation_id, user_id=user_id))
        db.flush()
        db.add(MessageModel(id=message_id, conversation_id=conversation_id,
                            role=MessageRole.ASSISTANT, content="Hello."))
        db.add(StreamTurnModel(id=str(uuid4()), user_id=user_id, request_id=str(uuid4()),
                               kind="turn", input_json="{}", conversation_id=conversation_id,
                               assistant_message_id=message_id, status="completed", audio_status="completed",
                               attempt_id=str(uuid4()), deadline_at=datetime.utcnow() + timedelta(minutes=5)))
        db.commit()

    original = VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="aGVsbG8=")
    writer = files.writer(str(uuid4()))
    await writer.add(0, "Hello.", original)
    manifest = await writer.publish(message_id, "Hello.")
    with sessions() as db:
        store = AudioCacheStore(db)
        lease_id = store.claim(message_id)
        assert lease_id
        assert store.publish(message_id, lease_id, manifest)
        competing_lease = store.claim(message_id, expected_manifest=manifest)
        assert competing_lease
        with sessions() as another_worker:
            assert AudioCacheStore(another_worker).claim(message_id) is None
        assert store.publish(message_id, competing_lease, manifest)
        assert store.claim(message_id) is None

    class FakeVoice:
        calls = 0

        async def synthesize_response(self, text):
            self.calls += 1
            return original

    voice = FakeVoice()

    with pytest.raises(HTTPException) as unauthorized:
        await router.retry_stream_audio(UUID(message_id), current_user=ProfileModel(id=str(uuid4())),
                                        voice_service=voice)
    assert unauthorized.value.status_code == 404

    async def read_events():
        with sessions() as db:
            current_user = db.get(ProfileModel, user_id)
            response = await router.retry_stream_audio(UUID(message_id), current_user=current_user, voice_service=voice)
        return [json.loads(chunk) async for chunk in response.body_iterator]

    cached = await read_events()
    assert [item["event"] for item in cached] == ["audio_started", "audio_segment", "audio_completed"]
    assert cached[1]["base64"] == original.base64
    assert voice.calls == 0

    with sessions() as db:
        turn = db.query(StreamTurnModel).filter_by(assistant_message_id=message_id).one()
        turn.audio_status = "pending"
        turn.deadline_at = datetime.utcnow() - timedelta(seconds=1)
        db.commit()
    assert [item["event"] for item in await read_events()] == ["audio_started", "audio_segment", "audio_completed"]
    with sessions() as db:
        turn = db.query(StreamTurnModel).filter_by(assistant_message_id=message_id).one()
        assert turn.audio_status == "failed"
        assert turn.error_code == "AUDIO_EXPIRED"

    (tmp_path / message_id / manifest["generation_id"] / "0000.mp3").unlink()
    with sessions() as db:
        current_user = db.get(ProfileModel, user_id)
        first_response = await router.retry_stream_audio(UUID(message_id), current_user=current_user,
                                                         voice_service=voice)
        with pytest.raises(HTTPException) as concurrent:
            await router.retry_stream_audio(UUID(message_id), current_user=current_user, voice_service=voice)
    assert concurrent.value.status_code == 409
    regenerated = [json.loads(chunk) async for chunk in first_response.body_iterator]
    assert [item["event"] for item in regenerated] == ["audio_started", "audio_segment", "audio_completed"]
    assert voice.calls == 1
    assert await read_events() and voice.calls == 1
    with sessions() as db:
        store = AudioCacheStore(db)
        assert store.claim(message_id, expected_manifest=manifest) is None

    with sessions() as db:
        latest_manifest = AudioCacheStore(db).manifest(message_id)
    (tmp_path / message_id / latest_manifest["generation_id"] / "0000.mp3").unlink()

    async def reject_write(*_args):
        raise OSError("disk full")

    monkeypatch.setattr(AudioCacheWriter, "add", reject_write)
    events_after_write_failure = await read_events()
    assert [item["event"] for item in events_after_write_failure] == [
        "audio_started", "audio_segment", "audio_completed"]
    with sessions() as db:
        turn = db.query(StreamTurnModel).filter_by(assistant_message_id=message_id).one()
        assert turn.audio_status == "completed"
        assert AudioCacheStore(db).manifest(message_id) is None
    engine.dispose()

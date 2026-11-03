"""스트림 음성 파일 캐시의 저장·만료 경계를 확인해요."""

from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.conversation import audio_cache
from domains.conversation.audio_cache import AudioCacheFiles
from domains.conversation.models import ConversationModel, MessageModel
from domains.conversation.enums import MessageRole
from domains.voice.schemas import VoiceAudioResponse
from scripts import cleanup_conversation_audio


@pytest.mark.asyncio
async def test_writer_publishes_ordered_segments_and_loads_after_reopen(tmp_path: Path):
    message_id = str(uuid4())
    cache = AudioCacheFiles(tmp_path)
    writer = cache.writer(str(uuid4()))
    await writer.add(0, "Hello.", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="aGVsbG8="))
    await writer.add(1, "How are you?", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="d29ybGQ="))

    assert not (tmp_path / message_id).exists()
    manifest = await writer.publish(message_id, "Hello. How are you?")
    assert manifest["segment_count"] == 2
    assert [part["index"] for part in manifest["segments"]] == [0, 1]

    reopened = AudioCacheFiles(tmp_path)
    audio = await reopened.load(message_id, manifest, "Hello. How are you?")
    assert [item[1].base64 for item in audio] == ["aGVsbG8=", "d29ybGQ="]


@pytest.mark.asyncio
async def test_missing_segment_is_cache_miss_and_abort_removes_staging(tmp_path: Path):
    message_id = str(uuid4())
    cache = AudioCacheFiles(tmp_path)
    writer = cache.writer(str(uuid4()))
    await writer.add(0, "Hello.", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="aGVsbG8="))
    manifest = await writer.publish(message_id, "Hello.")
    segment = manifest["segments"][0]
    (tmp_path / message_id / manifest["generation_id"] / segment["file"]).unlink()

    assert await cache.load(message_id, manifest, "Hello.") is None

    interrupted = cache.writer(str(uuid4()))
    await interrupted.add(0, "Retry.", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="cmV0cnk="))
    await interrupted.abort()
    assert not interrupted.staging_dir.exists()


@pytest.mark.asyncio
async def test_read_io_error_is_not_a_cache_miss(tmp_path: Path, monkeypatch):
    message_id = str(uuid4())
    cache = AudioCacheFiles(tmp_path)
    writer = cache.writer(str(uuid4()))
    await writer.add(0, "Hello.", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="aGVsbG8="))
    manifest = await writer.publish(message_id, "Hello.")

    def deny_read(_path):
        raise PermissionError("disk unavailable")

    monkeypatch.setattr(Path, "read_bytes", deny_read)
    with pytest.raises(PermissionError):
        await cache.load(message_id, manifest, "Hello.")


@pytest.mark.asyncio
async def test_provider_mp3_media_type_is_preserved(tmp_path: Path):
    message_id = str(uuid4())
    cache = AudioCacheFiles(tmp_path)
    writer = cache.writer(str(uuid4()))
    await writer.add(0, "Hello.", VoiceAudioResponse(content_type="audio/mp3", format="mp3", base64="aGVsbG8="))
    manifest = await writer.publish(message_id, "Hello.")

    audio = await cache.load(message_id, manifest, "Hello.")
    assert audio[0][1].content_type == "audio/mp3"


@pytest.mark.asyncio
async def test_cleanup_expires_old_generation_but_keeps_recent(tmp_path: Path):
    cache = AudioCacheFiles(tmp_path)
    old_message = str(uuid4())
    recent_message = str(uuid4())
    for message_id in (old_message, recent_message):
        writer = cache.writer(str(uuid4()))
        await writer.add(0, "Hello.", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="aGVsbG8="))
        await writer.publish(message_id, "Hello.")
    old_generation = next((tmp_path / old_message).iterdir())
    old_time = (datetime.now() - timedelta(days=31)).timestamp()
    import os
    os.utime(old_generation, (old_time, old_time))

    removed = await cache.cleanup(retention_days=30)

    assert removed == 1
    assert not old_generation.exists()
    assert next((tmp_path / recent_message).iterdir()).exists()


@pytest.mark.asyncio
async def test_cleanup_continues_after_one_deletion_failure(tmp_path: Path, monkeypatch):
    cache = AudioCacheFiles(tmp_path)
    generations = []
    old_time = (datetime.now() - timedelta(days=31)).timestamp()
    for _ in range(2):
        message_id = str(uuid4())
        writer = cache.writer(str(uuid4()))
        await writer.add(0, "Hello.", VoiceAudioResponse(content_type="audio/mpeg", format="mp3", base64="aGVsbG8="))
        await writer.publish(message_id, "Hello.")
        generation = next((tmp_path / message_id).iterdir())
        import os
        os.utime(generation, (old_time, old_time))
        generations.append(generation)

    remove = audio_cache.shutil.rmtree

    def reject_one(path, *args, **kwargs):
        if Path(path) in {generations[0], generations[0].parent}:
            raise PermissionError("deletion denied")
        return remove(path, *args, **kwargs)

    monkeypatch.setattr(audio_cache.shutil, "rmtree", reject_one)
    with pytest.raises(OSError, match="Failed to remove 1"):
        await cache.cleanup(retention_days=30)
    assert generations[0].exists()
    assert not generations[1].exists()
    with pytest.raises(PermissionError):
        cache.delete_message(generations[0].parent.name)


def test_orphan_cleanup_retries_failed_conversation_deletion(tmp_path: Path, monkeypatch):
    engine = create_engine(f"sqlite:///{tmp_path / 'cache.sqlite'}")
    Base.metadata.create_all(engine)
    sessions = sessionmaker(bind=engine)
    monkeypatch.setattr(cleanup_conversation_audio, "SessionLocal", sessions)
    live_id, orphan_id = str(uuid4()), str(uuid4())
    with sessions() as db:
        conversation_id = str(uuid4())
        db.add(ConversationModel(id=conversation_id, user_id=str(uuid4())))
        db.add(MessageModel(id=live_id, conversation_id=conversation_id,
                            role=MessageRole.ASSISTANT, content="Hello."))
        db.commit()
    cache = AudioCacheFiles(tmp_path)
    (tmp_path / live_id).mkdir()
    (tmp_path / orphan_id).mkdir()
    remove = cache.delete_message
    failed = False

    def fail_once(message_id):
        nonlocal failed
        if message_id == orphan_id and not failed:
            failed = True
            raise PermissionError("temporary deletion failure")
        remove(message_id)

    monkeypatch.setattr(cache, "delete_message", fail_once)
    with pytest.raises(OSError, match="orphaned audio"):
        cleanup_conversation_audio.delete_orphaned_audio(cache)
    assert (tmp_path / orphan_id).exists()
    assert cleanup_conversation_audio.delete_orphaned_audio(cache) == 1
    assert not (tmp_path / orphan_id).exists()
    assert (tmp_path / live_id).exists()
    engine.dispose()

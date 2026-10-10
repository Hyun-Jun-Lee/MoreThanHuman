"""스트림 파일의 확정과 DB manifest를 함께 처리해요."""

import logging
from uuid import uuid4

from config import get_settings
from database import SessionLocal
from domains.conversation.audio_cache import AudioCacheFiles, AudioCacheWriter
from domains.conversation.audio_cache_store import AudioCacheStore

logger = logging.getLogger(__name__)


def cache_files() -> AudioCacheFiles | None:
    directory = get_settings().audio_cache_dir
    return AudioCacheFiles(directory) if directory else None


def new_writer() -> AudioCacheWriter | None:
    cache = cache_files()
    return cache.writer(str(uuid4())) if cache else None


async def persist_writer(writer: AudioCacheWriter, message_id: str, text: str, *, lease_id: str | None = None) -> None:
    """생성 완료 시에만 manifest를 공개해요. 실패한 파일은 제거해요."""
    try:
        if lease_id is None:
            with SessionLocal() as db:
                lease_id = AudioCacheStore(db).claim(message_id)
        if lease_id is None:
            await writer.abort()
            return
        manifest = await writer.publish(message_id, text)
        with SessionLocal() as db:
            if not AudioCacheStore(db).publish(message_id, lease_id, manifest):
                raise RuntimeError("Audio cache lease was replaced")
    except Exception:
        logger.exception("Audio cache publish failed", extra={"message_id": message_id})
        if lease_id:
            with SessionLocal() as db:
                AudioCacheStore(db).release(message_id, lease_id)
        await writer.abort()

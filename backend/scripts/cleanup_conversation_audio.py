"""운영 cron에서 호출하는 대화 음성 파일 만료 작업이에요."""

import asyncio
from itertools import batched

from config import get_settings
from database import SessionLocal
from domains.conversation.audio_cache import AudioCacheFiles
from domains.conversation.repository import ConversationRepository


def delete_orphaned_audio(cache: AudioCacheFiles) -> int:
    """삭제된 대화의 메시지 디렉터리를 다시 찾아 제거해요."""
    removed = 0
    failures: list[OSError] = []
    with SessionLocal() as db:
        repository = ConversationRepository(db)
        for message_ids in batched(cache.message_ids(), 500):
            live_ids = repository.existing_message_ids(list(message_ids))
            for message_id in message_ids:
                if message_id in live_ids:
                    continue
                try:
                    cache.delete_message(message_id)
                    removed += 1
                except OSError as error:
                    failures.append(error)
    if failures:
        raise OSError(f"Failed to remove {len(failures)} orphaned audio directories") from failures[0]
    return removed


def main() -> None:
    settings = get_settings()
    if not settings.audio_cache_dir:
        raise RuntimeError("AUDIO_CACHE_DIR is required")
    cache = AudioCacheFiles(settings.audio_cache_dir)
    errors: list[OSError] = []
    try:
        orphaned = delete_orphaned_audio(cache)
    except OSError as error:
        errors.append(error)
        orphaned = 0
    try:
        expired = asyncio.run(cache.cleanup(settings.audio_cache_retention_days))
    except OSError as error:
        errors.append(error)
        expired = 0
    print(f"orphaned_audio_messages_removed={orphaned} expired_audio_generations_removed={expired}")
    if errors:
        raise OSError("Conversation audio cleanup was incomplete") from errors[0]


if __name__ == "__main__":
    main()

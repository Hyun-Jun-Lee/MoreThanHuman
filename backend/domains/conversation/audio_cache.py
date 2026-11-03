"""문장별 MP3를 호스트 볼륨에 저장하는 작은 파일 저장소예요."""

import asyncio
import base64
import hashlib
import os
import shutil
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterator, Protocol
from uuid import UUID


class AudioSegment(Protocol):
    content_type: str
    format: str
    base64: str


@dataclass(frozen=True)
class CachedAudio:
    content_type: str
    format: str
    base64: str


def _uuid(value: str) -> str:
    return str(UUID(value))


class AudioCacheWriter:
    def __init__(self, cache: "AudioCacheFiles", generation_id: str):
        self.cache = cache
        self.generation_id = _uuid(generation_id)
        self.staging_dir = cache.root / ".staging" / self.generation_id
        self.segments: list[dict] = []
        self.published_dir: Path | None = None

    async def add(self, index: int, text: str, audio: AudioSegment) -> None:
        if index != len(self.segments) or audio.format != "mp3" or not audio.content_type:
            raise ValueError("Expected ordered MP3 segments")
        data = base64.b64decode(audio.base64, validate=True)
        if not data:
            raise ValueError("Empty audio segment")
        filename = f"{index:04d}.mp3"

        def write():
            self.staging_dir.mkdir(parents=True, exist_ok=True)
            path = self.staging_dir / filename
            with path.open("xb") as output:
                output.write(data)
                output.flush()
                os.fsync(output.fileno())

        await asyncio.to_thread(write)
        self.segments.append({"index": index, "text": text, "file": filename,
                              "content_type": audio.content_type, "bytes": len(data),
                              "sha256": hashlib.sha256(data).hexdigest()})

    async def publish(self, message_id: str, text: str) -> dict:
        message_id = _uuid(message_id)
        if not self.segments:
            raise ValueError("Cannot publish empty audio")
        destination = self.cache.root / message_id / self.generation_id

        def move():
            destination.parent.mkdir(parents=True, exist_ok=True)
            self.staging_dir.rename(destination)

        await asyncio.to_thread(move)
        self.published_dir = destination
        return {"generation_id": self.generation_id, "format": "mp3",
                "text_sha256": hashlib.sha256(text.encode()).hexdigest(),
                "segment_count": len(self.segments), "segments": self.segments.copy()}

    async def abort(self) -> None:
        await asyncio.to_thread(shutil.rmtree, self.staging_dir, True)
        if self.published_dir is not None:
            await asyncio.to_thread(shutil.rmtree, self.published_dir, True)


class AudioCacheFiles:
    def __init__(self, root: str | Path):
        self.root = Path(root)

    def writer(self, generation_id: str) -> AudioCacheWriter:
        return AudioCacheWriter(self, generation_id)

    async def load(self, message_id: str, manifest: dict, text: str) -> list[tuple[str, CachedAudio]] | None:
        try:
            message_id = _uuid(message_id)
            generation_id = _uuid(manifest["generation_id"])
            segments = manifest["segments"]
            if (manifest["format"] != "mp3"
                    or manifest["text_sha256"] != hashlib.sha256(text.encode()).hexdigest()
                    or manifest["segment_count"] != len(segments) or not segments):
                return None

            def read():
                result = []
                for index, segment in enumerate(segments):
                    if segment["index"] != index or segment["file"] != f"{index:04d}.mp3":
                        return None
                    data = (self.root / message_id / generation_id / segment["file"]).read_bytes()
                    if len(data) != segment["bytes"] or hashlib.sha256(data).hexdigest() != segment["sha256"]:
                        return None
                    result.append((segment["text"], CachedAudio(
                        content_type=segment["content_type"], format="mp3",
                        base64=base64.b64encode(data).decode())))
                return result

            return await asyncio.to_thread(read)
        except (KeyError, TypeError, ValueError, FileNotFoundError):
            return None

    def delete_message(self, message_id: str) -> None:
        try:
            shutil.rmtree(self.root / _uuid(message_id))
        except FileNotFoundError:
            pass

    def message_ids(self) -> Iterator[str]:
        if not self.root.exists():
            return
        for directory in self.root.iterdir():
            if directory.is_symlink() or not directory.is_dir():
                continue
            try:
                yield _uuid(directory.name)
            except ValueError:
                continue

    async def cleanup(self, retention_days: int) -> int:
        cutoff = (datetime.now() - timedelta(days=retention_days)).timestamp()

        def remove_old():
            removed = 0
            failures: list[OSError] = []
            if not self.root.exists():
                return 0
            for message_dir in self.root.iterdir():
                if message_dir.name != ".staging":
                    try:
                        _uuid(message_dir.name)
                    except ValueError:
                        continue
                if message_dir.is_symlink() or not message_dir.is_dir():
                    continue
                for generation_dir in message_dir.iterdir():
                    try:
                        if (not generation_dir.is_symlink() and generation_dir.is_dir()
                                and generation_dir.stat().st_mtime < cutoff):
                            shutil.rmtree(generation_dir)
                            removed += 1
                    except FileNotFoundError:
                        continue
                    except OSError as error:
                        failures.append(error)
                if message_dir.name != ".staging" and not any(message_dir.iterdir()):
                    try:
                        message_dir.rmdir()
                    except OSError:
                        pass
            if failures:
                raise OSError(f"Failed to remove {len(failures)} expired audio directories") from failures[0]
            return removed

        return await asyncio.to_thread(remove_old)

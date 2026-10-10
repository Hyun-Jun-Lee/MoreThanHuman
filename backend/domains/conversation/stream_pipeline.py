"""LLM delta와 문장별 TTS를 제한된 큐로 연결해요."""

import asyncio
import logging
from collections.abc import AsyncIterator, Callable

from domains.conversation.stream_audio import SentenceBuffer, event_line
from domains.conversation.audio_cache_flow import new_writer, persist_writer
from domains.voice.service import VoiceService

logger = logging.getLogger(__name__)
_DONE = object()


async def stream_answer(
    *,
    turn_id: str,
    attempt_id: str,
    trace_id: str | None,
    deltas: AsyncIterator[str],
    voice_service: VoiceService,
    conversation_id: str | None,
    user_message_id: str | None,
    input_mode: str | None,
    user_text: str | None,
    save_answer: Callable[[str], tuple[str, str]],
    mark_audio: Callable[[str | None], None],
    mark_failed: Callable[[str], None],
) -> AsyncIterator[bytes]:
    """두 문장과 두 결과를 넘지 않도록 생산자를 역압박해요."""
    sentences: asyncio.Queue[object] = asyncio.Queue(maxsize=2)
    results: asyncio.Queue[tuple[str, object]] = asyncio.Queue(maxsize=2)

    async def read_llm() -> None:
        buffer = SentenceBuffer()
        parts: list[str] = []
        try:
            iterator = deltas.__aiter__()
            first_token = True
            while True:
                try:
                    async with asyncio.timeout(45 if first_token else 60):
                        delta = await anext(iterator)
                except StopAsyncIteration:
                    break
                first_token = False
                parts.append(delta)
                await results.put(("text_delta", delta))
                for sentence in buffer.feed(delta):
                    await sentences.put(sentence)
            for sentence in buffer.finish():
                await sentences.put(sentence)
            answer = "".join(parts).strip()
            if not answer:
                raise ValueError("LLM returned empty text")
            await results.put(("text_done", answer))
        except Exception as error:
            logger.exception("Conversation LLM stream failed", extra={"turn_id": turn_id})
            await results.put(("text_error", type(error).__name__))
        finally:
            if not asyncio.current_task().cancelling():
                await sentences.put(_DONE)

    async def synthesize() -> None:
        index = 0
        failed = False
        try:
            while True:
                item = await sentences.get()
                if item is _DONE:
                    break
                if failed:
                    continue
                try:
                    audio = await asyncio.wait_for(voice_service.synthesize_response(item), timeout=60)
                    await results.put(("audio_segment", (index, item, audio)))
                except Exception:
                    failed = True
                    logger.exception("Conversation sentence audio failed", extra={"turn_id": turn_id})
                    await results.put(("audio_error", "AUDIO_FAILED"))
                index += 1
        finally:
            if not asyncio.current_task().cancelling():
                await results.put(("audio_done", failed))

    reader = asyncio.create_task(read_llm())
    worker = asyncio.create_task(synthesize())
    seq = 0
    text_saved = False
    audio_finished = False
    audio_failed = False
    completed = False
    assistant_message_id: str | None = None
    final_text: str | None = None
    cache_writer = new_writer()
    try:
        yield event_line("turn_started", seq, turn_id, attempt_id,
                         trace_id=trace_id, **({"conversation_id": conversation_id} if conversation_id else {}))
        seq += 1
        if user_message_id and user_text:
            yield event_line("user_message_committed", seq, turn_id, attempt_id,
                             conversation_id=conversation_id, user_message_id=user_message_id,
                             text=user_text, input_mode=input_mode)
            seq += 1
        async with asyncio.timeout(300):
            while not (text_saved and audio_finished):
                kind, payload = await asyncio.wait_for(results.get(), timeout=60)
                if kind == "text_delta":
                    yield event_line(kind, seq, turn_id, attempt_id, delta=payload)
                    seq += 1
                elif kind == "audio_segment":
                    index, sentence, audio = payload
                    yield event_line(kind, seq, turn_id, attempt_id,
                                     segment_index=index, text=sentence,
                                     content_type=audio.content_type, format=audio.format,
                                     base64=audio.base64)
                    seq += 1
                    if cache_writer is not None:
                        try:
                            await cache_writer.add(index, sentence, audio)
                        except Exception:
                            logger.exception("Conversation audio cache write failed", extra={"turn_id": turn_id})
                            await cache_writer.abort()
                            cache_writer = None
                elif kind == "audio_error":
                    audio_failed = True
                    yield event_line(kind, seq, turn_id, attempt_id, code=payload)
                    seq += 1
                elif kind == "text_error":
                    mark_failed("LLM_FAILED")
                    completed = True
                    yield event_line("turn_error", seq, turn_id, attempt_id,
                                     code="LLM_FAILED", retryable=True,
                                     conversation_id=conversation_id, user_message_id=user_message_id)
                    return
                elif kind == "text_done":
                    final_text = payload
                    conversation_id, assistant_message_id = save_answer(final_text)
                    text_saved = True
                elif kind == "audio_done":
                    audio_finished = True
                    audio_failed = audio_failed or payload
            if cache_writer is not None:
                if not audio_failed and assistant_message_id and final_text:
                    await persist_writer(cache_writer, assistant_message_id, final_text)
                else:
                    await cache_writer.abort()
                cache_writer = None
            mark_audio("AUDIO_FAILED" if audio_failed else None)
            completed = True
            yield event_line("turn_completed", seq, turn_id, attempt_id,
                             conversation_id=conversation_id,
                             assistant_message_id=assistant_message_id,
                             text=final_text, audio_status="failed" if audio_failed else "completed")
    except Exception:
        logger.exception("Conversation stream ended unexpectedly", extra={"turn_id": turn_id})
        if not completed:
            if text_saved:
                mark_audio("STREAM_FAILED")
                completed = True
                yield event_line("audio_error", seq, turn_id, attempt_id, code="STREAM_FAILED")
                seq += 1
                yield event_line("turn_completed", seq, turn_id, attempt_id,
                                 conversation_id=conversation_id,
                                 assistant_message_id=assistant_message_id,
                                 text=final_text, audio_status="failed")
            else:
                mark_failed("STREAM_FAILED")
                completed = True
                yield event_line("turn_error", seq, turn_id, attempt_id,
                                 code="STREAM_FAILED", retryable=True,
                                 conversation_id=conversation_id, user_message_id=user_message_id)
    finally:
        if cache_writer is not None:
            await cache_writer.abort()
        reader.cancel()
        worker.cancel()
        await asyncio.gather(reader, worker, return_exceptions=True)
        if not completed:
            if text_saved:
                mark_audio("STREAM_DISCONNECTED")
            else:
                mark_failed("STREAM_DISCONNECTED")

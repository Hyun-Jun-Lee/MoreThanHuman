import asyncio
import json
from collections.abc import AsyncIterator
from types import SimpleNamespace

import pytest

from domains.conversation.stream_pipeline import stream_answer


@pytest.mark.asyncio
async def test_first_audio_can_arrive_before_the_remaining_llm_text(monkeypatch) -> None:
    continue_llm = asyncio.Event()
    synthesized: list[str] = []
    milestones: list[dict] = []
    monkeypatch.setattr(
        "domains.conversation.stream_pipeline.log_event",
        lambda _event, **fields: milestones.append(fields),
        raising=False,
    )

    async def deltas() -> AsyncIterator[str]:
        yield "Hello. "
        await continue_llm.wait()
        yield "How are you?"

    class Voice:
        async def synthesize_response(self, sentence: str):
            synthesized.append(sentence)
            return SimpleNamespace(content_type="audio/mpeg", format="mp3", base64="AQID")

    events = stream_answer(
        turn_id="turn-id",
        attempt_id="attempt-id",
        trace_id="trace-id",
        deltas=deltas(),
        voice_service=Voice(),
        conversation_id=None,
        user_message_id=None,
        input_mode=None,
        user_text=None,
        save_answer=lambda text: ("conversation-id", "message-id"),
        mark_audio=lambda _: None,
        mark_failed=lambda _: None,
    )
    seen = []
    try:
        async with asyncio.timeout(1):
            while True:
                event = json.loads(await anext(events))
                seen.append(event["event"])
                if event["event"] == "audio_segment":
                    assert event["text"] == "Hello."
                    assert seen == ["turn_started", "text_delta", "audio_segment"]
                    break
            continue_llm.set()
            async for event_line in events:
                seen.append(json.loads(event_line)["event"])
    finally:
        continue_llm.set()
        await events.aclose()

    assert synthesized == ["Hello.", "How are you?"]
    assert seen == [
        "turn_started",
        "text_delta",
        "audio_segment",
        "text_delta",
        "audio_segment",
        "turn_completed",
    ]
    stages = [item["stage"] for item in milestones]
    assert stages.index("first_sentence_ready") < stages.index("llm_text_done")
    assert stages.index("first_audio_segment") < stages.index("llm_text_done")
    assert stages.index("llm_delta") < stages.index("text_delta_sent")
    assert [item["delta_chars"] for item in milestones if item["stage"] == "llm_delta"] == [7, 12]
    assert all("delta" not in item for item in milestones)

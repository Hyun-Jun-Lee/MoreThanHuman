import asyncio
import json
from io import BytesIO

import httpx
import pytest
from fastapi import FastAPI
from starlette.responses import JSONResponse

from shared.latency import LatencyMiddleware, latency_span
from domains.voice.service import VoiceService
from domains.voice.schemas import VoiceSynthesisResult, VoiceTranscriptionResult
from starlette.datastructures import Headers, UploadFile


def events(capsys):
    return [
        json.loads(line.split("[latency] ", 1)[1])
        for line in capsys.readouterr().out.splitlines()
        if line.startswith("[latency] ")
    ]


@pytest.mark.asyncio
async def test_concurrent_requests_keep_trace_and_body_private(capsys):
    app = FastAPI()
    app.add_middleware(LatencyMiddleware)

    @app.post("/api/conversations/start/free-chat/")
    async def turn():
        with latency_span("llm"):
            await asyncio.sleep(0)
        return {"response": "private transcript"}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        responses = await asyncio.gather(*[
            client.post("/api/conversations/start/free-chat/", headers={"X-Request-ID": trace})
            for trace in ("a" * 32, "b" * 32)
        ])

    rows = events(capsys)
    assert [response.headers["x-request-id"] for response in responses] == ["a" * 32, "b" * 32]
    for trace in ("a" * 32, "b" * 32):
        matching = [row for row in rows if row["trace_id"] == trace]
        assert {row["stage"] for row in matching} >= {"llm", "server_total"}
        assert len({row["request_id"] for row in matching}) == 1
        assert all(row["elapsed_ms"] >= 0 for row in matching)
    assert "private transcript" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_failed_span_preserves_exception_and_http_status(capsys):
    app = FastAPI()
    app.add_middleware(LatencyMiddleware)

    @app.post("/api/conversations/start/roleplay/")
    async def turn():
        try:
            with latency_span("tts"):
                raise ValueError("secret provider payload")
        except ValueError:
            return JSONResponse({"error": "unavailable"}, status_code=502)

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        response = await client.post("/api/conversations/start/roleplay/", headers={"X-Request-ID": "bad input"})
    rows = events(capsys)
    assert response.status_code == 502
    assert len(response.headers["x-request-id"]) == 32
    assert next(row for row in rows if row["stage"] == "tts")["status"] == "error"
    assert next(row for row in rows if row["stage"] == "server_total")["status_code"] == 502
    assert "secret provider payload" not in json.dumps(rows)
    with latency_span("outside_request"):
        pass
    assert events(capsys) == []


@pytest.mark.asyncio
async def test_unrelated_requests_are_not_instrumented(capsys):
    app = FastAPI()
    app.add_middleware(LatencyMiddleware)

    @app.get("/health")
    async def health():
        return {"ok": True}

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        response = await client.get("/health")
    assert "x-request-id" not in response.headers
    assert events(capsys) == []


@pytest.mark.asyncio
async def test_voice_service_spans_reach_request_context(capsys):
    class Provider:
        def get_provider_name(self):
            return "fake"

        async def transcribe_audio(self, **kwargs):
            return VoiceTranscriptionResult(text="private words")

        async def synthesize_speech(self, **kwargs):
            return VoiceSynthesisResult(audio_bytes=b"audio", content_type="audio/mpeg", format="mp3")

    voice = VoiceService(provider=Provider())
    app = FastAPI()
    app.add_middleware(LatencyMiddleware)

    @app.post("/api/conversations/start/free-chat/")
    async def turn():
        upload = UploadFile(
            BytesIO(b"RIFF\x00\x00\x00\x00WAVEfmt " + b"x" * 2048),
            filename="test.wav", headers=Headers({"content-type": "audio/wav"}),
        )
        try:
            _, text = await voice.resolve_input_text(text=None, audio_file=upload)
            audio = await voice.synthesize_response(text)
            return audio.model_dump()
        finally:
            await upload.close()

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        response = await client.post("/api/conversations/start/free-chat/")
    assert response.status_code == 200
    rows = events(capsys)
    assert {row["stage"] for row in rows} == {"stt", "tts", "audio_encode", "server_total"}
    assert len({row["trace_id"] for row in rows}) == 1
    assert "private words" not in json.dumps(rows)


@pytest.mark.asyncio
async def test_cancellation_is_preserved_and_context_is_reset(capsys):
    async def cancelled_app(scope, receive, send):
        with latency_span("llm"):
            raise asyncio.CancelledError()

    app = LatencyMiddleware(cancelled_app)
    with pytest.raises(asyncio.CancelledError):
        await app({"type": "http", "method": "POST", "path": "/api/conversations/id/turn/"}, None, None)
    rows = events(capsys)
    assert all(row["status"] == "error" for row in rows)
    assert rows[-1]["response_complete"] is False
    with latency_span("outside"):
        pass
    assert events(capsys) == []

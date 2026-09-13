import asyncio
from contextlib import asynccontextmanager

import pytest
import httpx
from pydantic import ValidationError

from config import Settings, get_settings
from shared.background_tasks import BackgroundTaskRegistry
from shared.http_clients import create_http_client, http_clients


@asynccontextmanager
async def local_http_server(response_ready=None, request_seen=None):
    """요청마다 닫지 않는 HTTP/1.1 서버로 실제 TCP 연결 수를 확인해요."""
    connections = []
    handlers = set()

    async def serve(reader, writer):
        task = asyncio.current_task()
        handlers.add(task)
        connections.append(writer)
        try:
            while True:
                try:
                    await reader.readuntil(b"\r\n\r\n")
                except asyncio.IncompleteReadError:
                    break
                if request_seen is not None:
                    request_seen.set()
                if response_ready is not None:
                    await response_ready.wait()
                writer.write(b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
                await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()
            handlers.discard(task)

    server = await asyncio.start_server(serve, "127.0.0.1", 0)
    try:
        yield f"http://127.0.0.1:{server.sockets[0].getsockname()[1]}", connections
    finally:
        server.close()
        await server.wait_closed()
        for writer in connections:
            writer.close()
        if handlers:
            await asyncio.gather(*handlers)


@pytest.mark.asyncio
async def test_sequential_requests_reuse_actual_tcp_connection(monkeypatch):
    monkeypatch.setenv("NO_PROXY", "127.0.0.1")
    async with local_http_server() as (url, connections):
        async with create_http_client(get_settings()) as client:
            for _ in range(3):
                assert (await client.get(url)).text == "ok"
            assert len(connections) == 1
        assert client.is_closed


@pytest.mark.asyncio
async def test_lifespan_pools_are_separate_and_close_on_failure():
    with pytest.raises(ValueError, match="failure"):
        async with http_clients(get_settings()) as clients:
            assert clients.ai is not clients.auth
            assert not clients.ai.is_closed
            assert not clients.auth.is_closed
            raise ValueError("failure")
    assert clients.ai.is_closed and clients.auth.is_closed


@pytest.mark.asyncio
async def test_background_shutdown_cancels_and_awaits_before_clients_close():
    registry = BackgroundTaskRegistry()
    started = asyncio.Event()
    cleanup = []
    async with http_clients(get_settings()) as clients:
        async def work():
            started.set()
            try:
                await asyncio.Event().wait()
            finally:
                await asyncio.sleep(0)
                cleanup.append(not clients.ai.is_closed)

        task = registry.start(work())
        await started.wait()
        await registry.aclose(grace_seconds=0)
        assert task.cancelled()
        assert cleanup == [True]
    assert clients.ai.is_closed


@pytest.mark.asyncio
async def test_pool_limit_times_out_waiter_and_recovers(monkeypatch):
    monkeypatch.setenv("NO_PROXY", "127.0.0.1")
    settings = get_settings().model_copy(update={
        "http_max_connections": 1, "http_max_keepalive_connections": 1,
    })
    ready, seen = asyncio.Event(), asyncio.Event()
    async with local_http_server(ready, seen) as (url, connections):
        async with create_http_client(settings) as client:
            first = asyncio.create_task(client.get(url))
            try:
                await asyncio.wait_for(seen.wait(), 1)
                with pytest.raises(httpx.PoolTimeout):
                    await client.get(url, timeout=httpx.Timeout(1, pool=0.02))
                assert len(connections) == 1
            finally:
                ready.set()
                await first
            assert (await client.get(url)).status_code == 200
            assert len(connections) == 1


@pytest.mark.asyncio
async def test_expired_idle_connection_is_replaced(monkeypatch):
    monkeypatch.setenv("NO_PROXY", "127.0.0.1")
    settings = get_settings().model_copy(update={"http_keepalive_expiry_seconds": 0.01})
    async with local_http_server() as (url, connections):
        async with create_http_client(settings) as client:
            await client.get(url)
            await asyncio.sleep(0.03)
            await client.get(url)
            assert len(connections) == 2


@pytest.mark.asyncio
async def test_background_shutdown_allows_completion_and_rejects_new_work():
    registry = BackgroundTaskRegistry()
    finished = []

    async def work():
        await asyncio.sleep(0)
        finished.append(True)

    task = registry.start(work())
    await registry.aclose(grace_seconds=1)
    assert task.done() and not task.cancelled()
    assert finished == [True]
    with pytest.raises(RuntimeError, match="shutting down"):
        registry.start(work())
    await registry.aclose(grace_seconds=0)


@pytest.mark.parametrize("values", [
    {"http_max_connections": 0},
    {"http_max_keepalive_connections": -1},
    {"http_max_connections": 1, "http_max_keepalive_connections": 2},
    {"http_keepalive_expiry_seconds": 0},
    {"http_keepalive_expiry_seconds": float("inf")},
    {"background_shutdown_grace_seconds": -1},
])
def test_invalid_pool_settings_fail_at_startup(values):
    with pytest.raises(ValidationError):
        Settings(**{**get_settings().model_dump(), **values})

"""응답 밖에서 실행되는 task를 추적하고 공유 자원보다 먼저 종료해요."""

import asyncio
import logging
from collections.abc import Coroutine
from typing import Any

from fastapi import Request
from shared.logging_config import log_event, safe_stack_frames


class BackgroundTaskRegistry:
    def __init__(self) -> None:
        self._tasks: set[asyncio.Task[None]] = set()
        self._closing = False

    def start(self, coroutine: Coroutine[Any, Any, None]) -> asyncio.Task[None]:
        if self._closing:
            coroutine.close()
            raise RuntimeError("Background tasks are shutting down")
        task = asyncio.create_task(coroutine)
        self._tasks.add(task)
        task.add_done_callback(self._finished)
        return task

    def _finished(self, task: asyncio.Task[None]) -> None:
        self._tasks.discard(task)
        if not task.cancelled() and (error := task.exception()) is not None:
            log_event("background_task.failed", level=logging.ERROR,
                      exception_type=type(error).__name__, stack_frames=safe_stack_frames(error))

    async def aclose(self, *, grace_seconds: float) -> None:
        self._closing = True
        tasks = set(self._tasks)
        if not tasks:
            return
        try:
            await asyncio.wait(tasks, timeout=grace_seconds)
        finally:
            for task in tasks:
                if not task.done():
                    task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)


async def get_background_tasks(request: Request) -> BackgroundTaskRegistry:
    return request.app.state.background_tasks

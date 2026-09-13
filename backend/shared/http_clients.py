"""외부 API client의 생성·종료는 앱/CLI가 소유하고 provider는 빌려 써요."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from dataclasses import dataclass
from http.cookiejar import Cookie, CookieJar, DefaultCookiePolicy
from typing import Any

import httpx
from fastapi import Request

from config import Settings


class _RejectCookies(DefaultCookiePolicy):
    """공유 client에 upstream의 사용자별 쿠키가 쌓이지 않도록 해요."""

    def set_ok(self, cookie: Cookie, request: Any) -> bool:
        return False


def create_http_client(settings: Settings) -> httpx.AsyncClient:
    """호출자가 async with/aclose로 종료해야 하는 client를 만들어요."""
    return httpx.AsyncClient(
        limits=httpx.Limits(
            max_connections=settings.http_max_connections,
            max_keepalive_connections=settings.http_max_keepalive_connections,
            keepalive_expiry=settings.http_keepalive_expiry_seconds,
        ),
        cookies=CookieJar(policy=_RejectCookies()),
    )


@dataclass(frozen=True)
class HTTPClients:
    ai: httpx.AsyncClient
    auth: httpx.AsyncClient


@asynccontextmanager
async def http_clients(settings: Settings) -> AsyncIterator[HTTPClients]:
    """긴 AI 요청이 인증 풀을 점유하지 않도록 별도 client를 소유해요."""
    async with create_http_client(settings) as ai, create_http_client(settings) as auth:
        yield HTTPClients(ai=ai, auth=auth)


async def get_ai_http_client(request: Request) -> httpx.AsyncClient:
    return request.app.state.http_clients.ai


async def get_auth_http_client(request: Request) -> httpx.AsyncClient:
    return request.app.state.http_clients.auth

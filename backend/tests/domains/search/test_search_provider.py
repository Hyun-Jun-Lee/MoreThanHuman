import asyncio
import json
from types import SimpleNamespace

import pytest

from domains.search import provider as provider_module
from domains.search.provider import DuckDuckGoSearchProvider
from shared.exceptions import ExternalAPIException
from shared import latency
from shared.logging_config import request_context


class FakeDDGS:
    calls = []

    def __enter__(self):
        return self

    def __exit__(self, _exc_type, _exc, _traceback):
        return False

    def text(self, query: str, **options):
        self.calls.append((query, options))
        return [
            {
                "title": "롯데 자이언츠 경기 결과",
                "href": "https://example.com/lotte",
                "body": "롯데 자이언츠가 최근 KBO 경기에서 승리했다.",
            }
        ]


def _settings():
    return SimpleNamespace(
        search_region="kr-kr",
        search_safesearch="moderate",
        search_recent_timelimit="m",
        search_backend="auto",
        search_max_results=6,
    )


def test_provider_passes_ddgs_options_and_normalizes_results(monkeypatch):
    FakeDDGS.calls = []
    monkeypatch.setattr(provider_module, "_load_ddgs_class", lambda: FakeDDGS)

    provider = DuckDuckGoSearchProvider(_settings())
    results = provider.text("롯데 자이언츠 경기 결과", use_recency_timelimit=True)

    assert FakeDDGS.calls[0][1] == {
        "region": "kr-kr",
        "safesearch": "moderate",
        "backend": "auto",
        "max_results": 6,
        "timelimit": "m",
    }
    assert results == [
        {
            "title": "롯데 자이언츠 경기 결과",
            "href": "https://example.com/lotte",
            "body": "롯데 자이언츠가 최근 KBO 경기에서 승리했다.",
        }
    ]


def test_provider_raises_external_api_exception_when_ddgs_missing(monkeypatch):
    def fail_load():
        raise ExternalAPIException("ddgs package is not installed")

    monkeypatch.setattr(provider_module, "_load_ddgs_class", fail_load)
    provider = DuckDuckGoSearchProvider(_settings())

    with pytest.raises(ExternalAPIException):
        provider.text("query", use_recency_timelimit=False)


def test_provider_logs_search_substages_without_query_or_results(monkeypatch):
    monkeypatch.setattr(provider_module, "_load_ddgs_class", lambda: FakeDDGS)
    stages = []
    monkeypatch.setattr(latency, "_emit_stage", lambda stage, started, status, **fields: stages.append((stage, status, fields)))

    DuckDuckGoSearchProvider(_settings()).text("private topic", use_recency_timelimit=True)

    assert [stage for stage, _, _ in stages] == [
        "search.provider_load", "search.provider_client",
        "search.provider_request", "search.provider_normalize",
    ]
    request_fields = stages[2][2]
    assert stages[2][1] == "ok"
    assert request_fields == {
        "provider": "ddgs", "backend": "auto", "region": "kr-kr",
        "requested_results": 6, "recency_intent": True, "result_count": 1,
    }
    assert "private topic" not in str(stages)
    assert "example.com" not in str(stages)


def test_provider_logs_request_error_type_without_query(monkeypatch):
    class FailingDDGS:
        def text(self, _query: str, **_options):
            raise TimeoutError("private topic")

    monkeypatch.setattr(provider_module, "_load_ddgs_class", lambda: FailingDDGS)
    stages = []
    monkeypatch.setattr(latency, "_emit_stage", lambda stage, started, status, **fields: stages.append((stage, status, fields)))

    with pytest.raises(ExternalAPIException):
        DuckDuckGoSearchProvider(_settings()).text("private topic", use_recency_timelimit=False)

    assert stages[-1][0:2] == ("search.provider_request", "error")
    assert stages[-1][2]["exception_type"] == "TimeoutError"
    assert "private topic" not in str(stages)


@pytest.mark.asyncio
async def test_provider_thread_logs_keep_trace_id_and_safe_metadata(monkeypatch, capsys):
    monkeypatch.setattr(provider_module, "_load_ddgs_class", lambda: FakeDDGS)
    token = request_context.set({"trace_id": "a" * 32, "request_id": "b" * 32})
    try:
        await asyncio.to_thread(
            DuckDuckGoSearchProvider(_settings()).text,
            "private topic", use_recency_timelimit=False,
        )
    finally:
        request_context.reset(token)

    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    request_log = next(row for row in rows if row.get("stage") == "search.provider_request")
    assert request_log["trace_id"] == "a" * 32
    assert request_log["backend"] == "auto"
    assert request_log["requested_results"] == 6
    assert request_log["result_count"] == 1
    assert "private topic" not in str(rows)
    assert "example.com" not in str(rows)

from types import SimpleNamespace

import pytest

from domains.search import provider as provider_module
from domains.search.provider import DuckDuckGoSearchProvider
from shared.exceptions import ExternalAPIException


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
        search_max_results=12,
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
        "max_results": 12,
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

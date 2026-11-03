import httpx
import pytest

from scripts import benchmark_conversation_list as benchmark


def test_benchmark_uses_one_token_for_warmup_and_samples(monkeypatch, capsys):
    calls = []

    def respond(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        if request.url.path == "/api/auth/swagger/token":
            assert request.method == "POST"
            assert request.content == b'{"email": "test@example.com", "password": "private-password"}'
            return httpx.Response(200, json={"data": {"access_token": "private-token"}})
        assert request.url.path == "/api/conversations/"
        assert request.headers["Authorization"] == "Bearer private-token"
        assert len(request.headers["X-Request-ID"]) == 32
        return httpx.Response(200, json={"success": True, "data": {"items": []}})

    clock = iter([0, 0.1, 1, 1.2, 2, 2.3, 3, 3.9])
    monkeypatch.setattr(benchmark, "perf_counter", lambda: next(clock))
    with httpx.Client(base_url="http://127.0.0.1:8010", transport=httpx.MockTransport(respond)) as client:
        token = benchmark.issue_token(client, "test@example.com", "private-password")
        results = benchmark.run_benchmark(client, token, samples=3, warmup=1)

    assert len(calls) == 5
    assert [sample.duration_ms for sample in results] == pytest.approx([200, 300, 900])
    assert len({sample.request_id for sample in results}) == 3
    benchmark.print_report(results, warmup=1)
    output = capsys.readouterr().out
    assert "median=300.0" in output
    assert "p95=900.0" in output
    assert "private-token" not in output
    assert "private-password" not in output


def test_token_failure_does_not_expose_credentials():
    def respond(request: httpx.Request) -> httpx.Response:
        return httpx.Response(401, json={"detail": "private-password"})

    with httpx.Client(base_url="http://127.0.0.1:8010", transport=httpx.MockTransport(respond)) as client:
        with pytest.raises(benchmark.BenchmarkError, match="HTTP 401") as caught:
            benchmark.issue_token(client, "test@example.com", "private-password")
    assert "private-password" not in str(caught.value)


def test_p95_uses_nearest_rank_for_twenty_samples(capsys):
    samples = [benchmark.Sample(number, float(number), f"request-{number}") for number in range(1, 21)]
    benchmark.print_report(samples, warmup=0)
    output = capsys.readouterr().out
    assert "median=10.5" in output
    assert "p95=19.0" in output
    assert "max=20.0" in output


@pytest.mark.parametrize(
    "url",
    ["https://127.0.0.1:8010", "http://example.com", "http://user@localhost:8010", "http://localhost:bad"],
)
def test_benchmark_refuses_nonlocal_or_credentialed_base_url(url):
    with pytest.raises(benchmark.BenchmarkError):
        benchmark.validate_base_url(url)

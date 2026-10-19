import json

import httpx
import pytest

from scripts import benchmark_api_flows as benchmark


def _client(respond):
    return httpx.Client(base_url="http://127.0.0.1:8010", transport=httpx.MockTransport(respond))


def test_home_measures_profile_and_four_home_requests_without_outputting_data(capsys):
    paths = []

    def respond(request):
        paths.append(request.url.path)
        assert request.headers["Authorization"] == "Bearer secret-token"
        assert len(request.headers["X-Request-ID"]) == 32
        return httpx.Response(200, json={"success": True, "data": {"private": "secret-data"}})

    with _client(respond) as client:
        sample = benchmark._home(client, "secret-token", 1)
    assert paths[0] == "/api/auth/me"
    assert set(paths[1:]) == {path for path, _ in benchmark.HOME_REQUESTS.values()}
    assert set(sample.timings) == {"flow_total", "profile", *benchmark.HOME_REQUESTS}
    assert len(set(sample.request_ids.values())) == 5
    benchmark.print_report("home", [sample], 0)
    output = capsys.readouterr().out
    assert "secret-token" not in output
    assert "secret-data" not in output


def test_messages_fetches_latest_page_only_for_long_conversation():
    paths = []

    def respond(request):
        paths.append((request.url.path, dict(request.url.params)))
        if request.url.path.endswith("/messages/"):
            return httpx.Response(200, json={"success": True, "data": {
                "results": [], "pagination": {"total_count": 94},
            }})
        return httpx.Response(200, json={"success": True, "data": {}})

    with _client(respond) as client:
        sample = benchmark._messages(client, "token", 1, "conversation-id")
    assert paths[:2] == [
        ("/api/conversations/conversation-id/messages/", {"limit": "40", "offset": "0"}),
        ("/api/conversations/conversation-id/messages/", {"limit": "40", "offset": "54"}),
    ]
    assert paths[2][0].endswith("/turns/")
    assert paths[3][0].endswith("/access/")
    assert sample.timings["messages_latest"] is not None
    assert sample.metadata == {"total_messages": 94}


def test_topic_prep_reports_ready_state_without_topic_text(capsys):
    def respond(request):
        assert request.url.path == "/api/search/topic-prep/"
        assert json.loads(request.content) == {"topic": "private-topic"}
        return httpx.Response(200, json={"success": True, "data": {"ready": False}})

    with _client(respond) as client:
        sample = benchmark._topic_prep(client, "token", 1, "private-topic")
    benchmark.print_report("topic-prep", [sample], 0)
    output = capsys.readouterr().out
    assert "ready=False" in output
    assert "private-topic" not in output


def test_stream_measures_events_and_uses_fresh_idempotency_key():
    def respond(request):
        assert request.url.path == "/api/conversations/start/free-chat/stream/"
        assert request.headers["Idempotency-Key"]
        assert request.headers["X-Request-ID"]
        assert json.loads(request.content) == {"first_message": "Hello"}
        return httpx.Response(
            200,
            headers={"content-type": "application/x-ndjson; charset=utf-8"},
            text='{"event":"turn_started"}\n{"event":"text_delta"}\n'
                 '{"event":"audio_segment"}\n'
                 '{"event":"turn_completed","audio_status":"completed"}\n',
        )

    args = benchmark._parser().parse_args([
        "--email", "test@example.com", "stream", "--kind", "free-chat",
        "--text", "Hello", "--allow-writes",
    ])
    with _client(respond) as client:
        sample = benchmark._stream(client, "token", 1, args)
    assert sample.timings["headers"] is not None
    assert sample.timings["first_text"] is not None
    assert sample.timings["first_audio"] is not None
    assert sample.timings["completed"] is not None
    assert sample.timings["http_total"] >= sample.timings["completed"]
    assert sample.metadata == {"audio_status": "completed"}


def test_stream_rejects_incomplete_result_without_exposing_body():
    def respond(request):
        return httpx.Response(
            200, headers={"content-type": "application/x-ndjson"},
            text='{"event":"text_delta","text":"private-content"}\n',
        )

    args = benchmark._parser().parse_args([
        "--email", "test@example.com", "stream", "--kind", "free-chat",
        "--text", "Hello", "--allow-writes",
    ])
    with _client(respond) as client:
        with pytest.raises(benchmark.BenchmarkError, match="완료 이벤트 누락") as caught:
            benchmark._stream(client, "token", 1, args)
    assert "private-content" not in str(caught.value)


@pytest.mark.parametrize("argv", [
    ["topic-prep", "--topic", "coffee"],
    ["stream", "--kind", "free-chat", "--text", "Hello"],
])
def test_costly_flows_require_explicit_opt_in(argv):
    parser = benchmark._parser()
    args = parser.parse_args(["--email", "test@example.com", *argv])
    with pytest.raises(SystemExit):
        benchmark._validate_args(parser, args)

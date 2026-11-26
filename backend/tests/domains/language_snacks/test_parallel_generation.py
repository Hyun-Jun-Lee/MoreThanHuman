import asyncio
import json
from types import SimpleNamespace

import pytest

from domains.language_snacks.generation_service import SnackGenerator
from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import utcnow
from domains.language_snacks.schemas import Candidate, PAYLOAD_MODELS
from domains.llm.schemas import LLMResponse
from tests.domains.language_snacks.test_language_snack_schemas import new_snack


@pytest.mark.asyncio
async def test_all_six_candidates_are_in_flight_and_accounting_is_exact(repository):
    started = asyncio.Event()
    release = asyncio.Event()
    kinds = []
    active = 0
    peak = 0

    async def chat(request):
        nonlocal active, peak
        data = json.loads(request.messages[1].content)["data"]
        kinds.append(data["content_type"])
        active += 1
        peak = max(peak, active)
        assert not repository.db.in_transaction()
        if active == 6:
            started.set()
        try:
            await release.wait()
            return LLMResponse(content='{"candidates":[]}', usage={"total_tokens": 7})
        finally:
            active -= 1

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    run = repository.run("parallel:en", "en", 1)
    run.metrics = {"rounds": 5, "calls": 4, "reported_tokens": 10}
    repository.save(run)
    task = asyncio.create_task(generator.generate(run.run_key, "en", 1))
    try:
        await asyncio.wait_for(started.wait(), 2)
        assert generator.metrics["calls"] == 10
        release.set()
        result = await task
    finally:
        release.set()
        if not task.done():
            task.cancel()
        await asyncio.gather(task, return_exceptions=True)
    assert set(kinds) == set(PAYLOAD_MODELS)
    assert peak == 6 and active == 0
    assert result["metrics"]["reported_tokens"] == 52
    assert result["metrics"]["rounds"] == 6
    assert repository.guard is None


@pytest.mark.asyncio
async def test_call_limit_cancels_inflight_requests_before_releasing_guard(repository):
    entered = 0
    cancelled = 0
    gate = asyncio.Event()

    async def chat(request):
        nonlocal entered, cancelled
        entered += 1
        try:
            await gate.wait()
        finally:
            assert repository.guard is not None
            cancelled += 1

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    generator.settings = generator.settings.model_copy(
        update={"language_snacks_max_calls": 4}
    )
    result = await asyncio.wait_for(generator.generate("limit:en", "en", 1), 2)
    assert result["status"] == "failed"
    assert result["metrics"]["error"] == "generation_budget_exceeded"
    assert result["metrics"]["calls"] == 4
    assert entered == cancelled == 4
    assert repository.guard is None


@pytest.mark.asyncio
async def test_parent_cancellation_drains_children_before_releasing_guard(repository):
    ready = asyncio.Event()
    gate = asyncio.Event()
    entered = 0
    finished = 0

    async def chat(request):
        nonlocal entered, finished
        entered += 1
        if entered == 6:
            ready.set()
        try:
            await gate.wait()
        finally:
            assert repository.guard is not None
            finished += 1

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    task = asyncio.create_task(generator.generate("cancel:en", "en", 1))
    try:
        await asyncio.wait_for(ready.wait(), 2)
    finally:
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
    assert finished == 6
    assert repository.guard is None
    assert repository.run("cancel:en", "en", 1).metrics["calls"] == 6


@pytest.mark.asyncio
async def test_semantic_duplicate_check_and_reservation_are_serialized(repository):
    class Parallel(SnackGenerator):
        async def propose(self, language, kind, missing):
            raw = new_snack(kind, language)
            return [
                Candidate.model_validate(
                    {k: v for k, v in raw.items() if k in Candidate.model_fields}
                )
            ]

        async def ensure_new(self, candidate):
            history = self.history(candidate.content_language)
            # LLM 중복 판정이 대기하는 동안 다른 카테고리도 실행될 수 있어요.
            await asyncio.sleep(0)
            if history:
                raise SnackError("duplicate_knowledge", 409)

        async def finish_reservation(self, row):
            await asyncio.sleep(0)
            row.payload = new_snack(row.content_type)["payload"]
            row.status = "published"
            row.published_at = utcnow()
            self.repository.save(row)

    generator = Parallel(
        repository, provider=SimpleNamespace(get_provider_name=lambda: "fake")
    )
    run = repository.run("duplicates:en", "en", 1)
    run.content_types = ["collocation", "idiomatic_expression"]
    repository.save(run)
    result = await generator.generate(run.run_key, "en", 1)
    assert len(repository.run_snacks(run.id)) == 1
    assert sum(result["metrics"]["published_by_type"].values()) == 1
    assert result["metrics"]["duplicate_knowledge"] == 3


@pytest.mark.asyncio
async def test_failure_call_numbers_follow_requests_not_completion_order(repository):
    ready = asyncio.Event()
    release = {kind: asyncio.Event() for kind in PAYLOAD_MODELS}
    requests = []

    async def chat(request):
        kind = json.loads(request.messages[1].content)["data"]["content_type"]
        requests.append(kind)
        if len(requests) == 6:
            ready.set()
        await release[kind].wait()
        return LLMResponse(content='{"candidates":', finish_reason="length")

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    tasks = [
        asyncio.create_task(generator.propose("en", kind, 1)) for kind in PAYLOAD_MODELS
    ]
    try:
        await asyncio.wait_for(ready.wait(), 2)
        for index in reversed(range(6)):
            release[requests[index]].set()
            with pytest.raises(SnackError):
                await tasks[index]
        assert [failure["call"] for failure in generator.metrics["failures"]] == [
            6,
            5,
            4,
            3,
            2,
            1,
        ]
    finally:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)


@pytest.mark.asyncio
async def test_cancelled_author_preserves_reservation_attempts(repository):
    ready = asyncio.Event()
    gate = asyncio.Event()

    async def chat(request):
        ready.set()
        await gate.wait()

    raw = new_snack("collocation")
    candidate = Candidate.model_validate(
        {k: v for k, v in raw.items() if k in Candidate.model_fields}
    )
    run = repository.run("cancel-author:en", "en", 1)
    row = repository.reserve(candidate, run.id)
    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    task = asyncio.create_task(generator.generate(run.run_key, "en", 1))
    try:
        await asyncio.wait_for(ready.wait(), 2)
    finally:
        task.cancel()
        with pytest.raises(asyncio.CancelledError):
            await task
    repository.db.refresh(row)
    assert row.status == "reserved"
    assert row.generation_metadata["attempts"] == 0
    assert row.published_at is None
    assert repository.run(run.run_key, "en", 1).metrics["calls"] == 1


@pytest.mark.asyncio
async def test_authoring_overlaps_after_serialized_reservations(repository):
    ready = asyncio.Event()
    release = asyncio.Event()
    active = 0
    peak = 0
    samples = {
        kind: new_snack(kind)
        for kind in ("register_contrast", "collocation", "idiomatic_expression")
    }

    async def chat(request):
        nonlocal active, peak
        assert not repository.db.in_transaction()
        data = json.loads(request.messages[1].content)["data"]
        schema = request.extra_params["response_format"]["json_schema"]["name"]
        if schema == "CandidateBatch":
            raw = samples[data["content_type"]]
            content = {
                "candidates": [
                    {k: v for k, v in raw.items() if k in Candidate.model_fields}
                ]
            }
        elif schema == "DedupeResult":
            content = {"decision": "new", "existing_id": None}
        elif schema == "QualityResult":
            content = {"valid": True, "reason": "fixture"}
        else:
            active += 1
            peak = max(peak, active)
            if active == 3:
                ready.set()
            try:
                await release.wait()
            finally:
                active -= 1
            content = samples[data["content_type"]]["payload"]
        return LLMResponse(content=json.dumps(content))

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    run = repository.run("authors:en", "en", 1)
    run.content_types = list(samples)
    repository.save(run)
    task = asyncio.create_task(generator.generate(run.run_key, "en", 1))
    try:
        await asyncio.wait_for(ready.wait(), 2)
        assert len(repository.run_snacks(run.id)) == 3
        assert all(row.status == "reserved" for row in repository.run_snacks(run.id))
        release.set()
        result = await task
    finally:
        release.set()
        if not task.done():
            task.cancel()
        await asyncio.gather(task, return_exceptions=True)
    assert peak == 3 and active == 0
    assert result["status"] == "succeeded"
    assert result["metrics"]["published_by_type"] == dict.fromkeys(samples, 1)

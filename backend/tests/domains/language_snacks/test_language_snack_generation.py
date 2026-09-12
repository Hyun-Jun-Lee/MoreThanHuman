from copy import deepcopy
from datetime import UTC, datetime
from types import SimpleNamespace

import pytest

from domains.language_snacks.generation_schemas import (
    CandidateBatch,
    DedupeResult,
    QualityResult,
)
from domains.language_snacks.generation_service import SnackGenerator
from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import (
    LanguageSnackModel,
    LanguageSnackRunModel,
)
from domains.language_snacks.schemas import PAYLOAD_MODELS, Candidate
from domains.llm.schemas import LLMResponse
from scripts.generate_language_snacks import weekly_slot


def as_candidate(sample):
    return Candidate.model_validate(
        {k: v for k, v in sample.items() if k in Candidate.model_fields}
    )


class Generator(SnackGenerator):
    def __init__(self, repository, sample):
        super().__init__(
            repository, provider=SimpleNamespace(get_provider_name=lambda: "fake")
        )
        self.sample = sample
        self.author_calls = 0
        self.invalid = False
        self.snapshots = []

    async def ask(self, instruction, data, schema):
        self.snapshots.append(deepcopy(data))
        if schema is CandidateBatch:
            return CandidateBatch(candidates=[as_candidate(self.sample)])
        if schema is DedupeResult:
            return DedupeResult(decision="new")
        if schema is QualityResult:
            return QualityResult(valid=not self.invalid, reason="Checked.")
        self.author_calls += 1
        return schema.model_validate(self.sample["payload"])


@pytest.mark.asyncio
async def test_same_run_resumes_reservations_without_republishing(repository, sample):
    run = repository.run("weekly:2026-09-14:en", "en", 1)
    row = repository.reserve(as_candidate(sample), run.id)
    generator = Generator(repository, sample)
    result = await generator.generate(run.run_key, "en", 1)
    assert result["status"] == "partial"  # Only one of three types supplied.
    assert row.status == "published"
    assert generator.author_calls == 1
    published_at = row.published_at
    await Generator(repository, sample).generate(run.run_key, "en", 1)
    assert repository.db.query(LanguageSnackModel).count() == 1
    assert row.published_at == published_at
    assert any(
        x.get("history") and x["history"][0]["id"] == row.id
        for x in generator.snapshots
    )


@pytest.mark.asyncio
async def test_invalid_content_is_never_published_and_has_bounded_attempts(
    repository, sample
):
    generator = Generator(repository, sample)
    generator.invalid = True
    result = await generator.generate("invalid:en", "en", 1)
    row = repository.db.query(LanguageSnackModel).one()
    assert result["status"] == "partial"
    assert row.status == "archived"
    assert row.published_at is None
    assert row.generation_metadata["attempts"] == 2
    assert generator.author_calls == 2
    assert repository.list_published("en") == []


@pytest.mark.asyncio
async def test_dry_run_has_no_writes(repository, sample):
    result = await Generator(repository, sample).generate(
        "dry:en", "en", 1, dry_run=True
    )
    assert result["status"] == "dry_run"
    assert repository.db.query(LanguageSnackModel).count() == 0
    assert repository.db.query(LanguageSnackRunModel).count() == 0


@pytest.mark.asyncio
async def test_successful_run_is_noop_and_configuration_cannot_change(
    repository, sample
):
    run = repository.run("done:en", "en", 1)
    run.status = "succeeded"
    repository.save(run)
    generator = Generator(repository, sample)
    assert (await generator.generate("done:en", "en", 1))["status"] == "succeeded"
    assert generator.snapshots == []
    with pytest.raises(SnackError, match="configuration"):
        await generator.generate("done:en", "en", 2)


@pytest.mark.asyncio
async def test_unknown_duplicate_id_and_uncertainty_fail_closed(repository, sample):
    repository.reserve(as_candidate(sample))
    sample["identity"]["entries"][0]["sense"] = "an_alias"

    class Judge(Generator):
        decision = "duplicate"

        async def ask(self, *args):
            return DedupeResult(
                decision=self.decision,
                existing_id="missing" if self.decision == "duplicate" else None,
            )

    judge = Judge(repository, sample)
    with pytest.raises(SnackError, match="invalid_duplicate_reference"):
        await judge.ensure_new(as_candidate(sample))
    judge.decision = "uncertain"
    with pytest.raises(SnackError, match="uncertain"):
        await judge.ensure_new(as_candidate(sample))


@pytest.mark.asyncio
async def test_full_history_budget_and_real_prompt_envelope(repository, sample):
    row = repository.reserve(as_candidate(sample))
    row.status = "archived"
    repository.save(row)

    class Provider:
        request = None

        def get_provider_name(self):
            return "fake"

        async def chat_completion(self, request):
            self.request = request
            return LLMResponse(
                content='{"decision":"duplicate","existing_id":"' + row.id + '"}',
                usage={"total_tokens": 3},
            )

    provider = Provider()
    generator = SnackGenerator(repository, provider=provider)
    sample["identity"]["entries"][0]["sense"] = "alias"
    with pytest.raises(SnackError, match="duplicate_knowledge"):
        await generator.ensure_new(as_candidate(sample))
    assert row.id in provider.request.messages[1].content
    assert "response_schema" in provider.request.messages[1].content
    assert generator.metrics["calls"] == 1
    generator.settings = generator.settings.model_copy(
        update={"language_snacks_history_bytes": 1}
    )
    with pytest.raises(SnackError, match="history_budget"):
        generator.history("en")
    generator.settings = generator.settings.model_copy(
        update={"language_snacks_max_calls": 1}
    )
    with pytest.raises(SnackError, match="generation_budget"):
        await generator.ask("test", {}, QualityResult)


def test_weekly_slot_uses_monday_five_am_kst():
    assert (
        weekly_slot(datetime(2026, 9, 13, 19, 59, tzinfo=UTC)) == "2026-09-07"
    )
    assert (
        weekly_slot(datetime(2026, 9, 13, 20, 0, tzinfo=UTC)) == "2026-09-14"
    )


@pytest.mark.asyncio
@pytest.mark.parametrize("language", ["en", "ko"])
async def test_complete_three_type_run_and_repeat_are_idempotent(
    repository, sample, language
):
    candidates = []
    for kind, relation in [
        ("regional_variant", "regional_equivalent"),
        ("usage_contrast", "usage_difference"),
        ("homonym", "same_sound"),
    ]:
        identity = deepcopy(sample["identity"])
        identity["relation"] = relation
        for entry in identity["entries"]:
            entry["language"] = language
        if kind == "usage_contrast":
            identity["contrast"] = "register"
        if kind == "homonym":
            identity["pronunciation"] = "test"
            identity["pronunciation_standard"] = "fixture"
        candidates.append(
            Candidate(
                content_type=kind,
                content_language=language,
                identity=identity,
                knowledge_summary="Fixture knowledge",
            )
        )

    class Complete(Generator):
        async def ask(self, instruction, data, schema):
            self.snapshots.append(deepcopy(data))
            if schema is CandidateBatch:
                return CandidateBatch(candidates=candidates)
            if schema is DedupeResult:
                return DedupeResult(decision="new")
            if schema is QualityResult:
                return QualityResult(valid=True, reason="Fixture only")
            kind = data["content_type"]
            if kind == "regional_variant":
                return schema.model_validate(sample["payload"])
            return schema.model_validate(
                {
                    "items": [
                        {
                            "expression": entry["expression"],
                            "usage"
                            if kind == "usage_contrast"
                            else "meaning": "Explanation",
                            "example": "Example",
                        }
                        for entry in data["identity"]["entries"]
                    ]
                }
            )

    generator = Complete(repository, sample)
    result = await generator.generate("complete:" + language, language, 1)
    assert result["status"] == "succeeded"
    assert result["metrics"]["published_by_type"] == {
        kind: 1 for kind in PAYLOAD_MODELS
    }
    assert len(repository.list_published(language)) == 3
    assert repository.list_published("ko" if language == "en" else "en") == []
    calls = len(generator.snapshots)
    await generator.generate("complete:" + language, language, 1)
    assert len(generator.snapshots) == calls
    assert repository.db.query(LanguageSnackModel).count() == 3


@pytest.mark.asyncio
async def test_budget_stop_preserves_reserved_attempt_for_resume(repository, sample):
    run = repository.run("budget:en", "en", 1)
    row = repository.reserve(as_candidate(sample), run.id)

    class Exhausted(Generator):
        async def ask(self, *args):
            raise SnackError("generation_budget_exceeded")

    result = await Exhausted(repository, sample).generate(run.run_key, "en", 1)
    assert result["status"] == "failed"
    assert row.status == "reserved"
    assert row.generation_metadata["attempts"] == 0
    await Generator(repository, sample).generate(run.run_key, "en", 1)
    assert row.status == "published"

import json
from types import SimpleNamespace

import httpx
import pytest

from domains.language_snacks.generation_service import SnackGenerator
from domains.language_snacks.generation_schemas import (
    CandidateBatch,
    DedupeResult,
    QualityResult,
)
from domains.language_snacks.schemas import PAYLOAD_MODELS
from domains.language_snacks.structured_output import strict_schema
from domains.language_snacks.lock import SnackError
from domains.llm.schemas import LLMResponse, LLMRequest, LLMMessage
from domains.llm.openrouter import OpenRouterProvider
from domains.llm.ollama import OllamaProvider


@pytest.mark.parametrize(
    "model", [CandidateBatch, DedupeResult, QualityResult, *PAYLOAD_MODELS.values()]
)
def test_all_wire_schemas_require_every_field_and_forbid_extras(model):
    schema = strict_schema(model)

    def check(node):
        if isinstance(node, dict):
            assert "default" not in node
            if node.get("type") == "object":
                assert node["additionalProperties"] is False
                assert set(node["required"]) == set(node["properties"])
            for value in node.values():
                check(value)
        elif isinstance(node, list):
            for value in node:
                check(value)

    check(schema)
    if model is DedupeResult:
        assert {"type": "null"} in schema["properties"]["existing_id"]["anyOf"]


@pytest.mark.asyncio
@pytest.mark.parametrize("provider_name", ["openrouter", "ollama"])
@pytest.mark.parametrize(
    "schema", [CandidateBatch, DedupeResult, QualityResult, *PAYLOAD_MODELS.values()]
)
async def test_every_stage_sends_strict_schema(repository, provider_name, schema):
    async def chat(request):
        fmt = request.extra_params["response_format"]
        assert fmt == {
            "type": "json_schema",
            "json_schema": {
                "name": schema.__name__,
                "strict": True,
                "schema": strict_schema(schema),
            },
        }
        assert request.extra_params.get("provider") == (
            {"require_parameters": True} if provider_name == "openrouter" else None
        )
        return LLMResponse(content="{}")

    provider = SimpleNamespace(
        get_provider_name=lambda: provider_name, chat_completion=chat
    )
    generator = SnackGenerator(repository, provider=provider)
    with pytest.raises(SnackError, match="invalid_llm_response"):
        await generator.ask("test", {}, schema)


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "content,finish,refused,code",
    [
        ('{"valid":', "length", False, "llm_length"),
        ("", "stop", True, "llm_refusal"),
        (
            '{"valid":"PRIVATE","reason":"ok","SECRET_KEY":"secret"}',
            "stop",
            False,
            "schema_validation",
        ),
        ("PRIVATE INVALID JSON", "stop", False, "schema_validation"),
    ],
)
async def test_failure_diagnostics_are_persisted_bounded_and_redacted(
    repository, content, finish, refused, code
):
    async def chat(request):
        return LLMResponse(content=content, finish_reason=finish, refused=refused)

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    generator.run = repository.run("diagnostics:en", "en", 1)
    generator.metrics = {"failures": [{"code": "old"}] * 20}
    with pytest.raises(SnackError, match="invalid_llm_response"):
        await generator.ask("test", {}, QualityResult)
    repository.db.refresh(generator.run)
    failures = generator.run.metrics["failures"]
    assert len(failures) == 20
    assert failures[-1]["code"] == code
    assert failures[-1]["schema"] == "QualityResult"
    assert failures[-1]["finish_reason"] == finish
    serialized = json.dumps(failures)
    assert all(
        secret not in serialized for secret in ["PRIVATE", "SECRET_KEY", "secret"]
    )
    if code == "schema_validation":
        assert failures[-1]["issues"]


@pytest.mark.asyncio
@pytest.mark.parametrize("provider_class", [OpenRouterProvider, OllamaProvider])
async def test_provider_preserves_schema_and_refusal_metadata(provider_class):
    fmt = {
        "type": "json_schema",
        "json_schema": {
            "name": "QualityResult",
            "strict": True,
            "schema": strict_schema(QualityResult),
        },
    }

    async def upstream(request):
        assert json.loads(request.content)["response_format"] == fmt
        return httpx.Response(
            200,
            json={
                "choices": [
                    {
                        "finish_reason": "stop",
                        "message": {"content": None, "refusal": "private refusal"},
                    }
                ]
            },
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        response = await provider_class(client).chat_completion(
            LLMRequest(
                messages=[LLMMessage(role="user", content="test")],
                model="test",
                extra_params={"response_format": fmt},
            )
        )
    assert response.refused is True
    assert response.finish_reason == "stop"
    assert response.content == ""


@pytest.mark.asyncio
async def test_unsupported_schema_http_failure_does_not_fall_back(repository):
    requests = []

    async def upstream(request):
        requests.append(json.loads(request.content))
        return httpx.Response(
            400, json={"error": {"message": "PRIVATE unsupported schema"}}
        )

    async with httpx.AsyncClient(transport=httpx.MockTransport(upstream)) as client:
        generator = SnackGenerator(repository, provider=OpenRouterProvider(client))
        with pytest.raises(SnackError, match="llm_unavailable"):
            await generator.ask("test", {}, QualityResult)
    assert len(requests) == 2
    assert all(r["response_format"]["json_schema"]["strict"] for r in requests)
    assert all(r["provider"]["require_parameters"] for r in requests)
    assert generator.metrics["failures"][-1]["status_code"] == 400
    assert "PRIVATE" not in json.dumps(generator.metrics)


def test_domain_validation_reason_is_safe_and_actionable():
    from pydantic import ValidationError
    from domains.language_snacks.structured_output import validation_issues
    from tests.domains.language_snacks.test_language_snack_schemas import new_snack

    raw = new_snack("collocation")
    raw["identity"]["relation"] = "same_sound"
    from domains.language_snacks.schemas import Candidate

    candidate = {
        key: value for key, value in raw.items() if key in Candidate.model_fields
    }
    with pytest.raises(ValidationError) as error:
        CandidateBatch.model_validate({"candidates": [candidate]})
    issues = validation_issues(error.value, strict_schema(CandidateBatch))
    assert (
        issues[0]["reason"]
        == "Value error, Identity relation does not match content type."
    )


@pytest.mark.parametrize("kind", PAYLOAD_MODELS)
@pytest.mark.parametrize("language", ["en", "ko"])
def test_category_schema_contains_only_relevant_fields(kind, language):
    from domains.language_snacks.structured_output import (
        candidate_schema,
        CANDIDATE_FIELDS,
    )

    schema = candidate_schema(CandidateBatch, kind, language, 3)
    relation, identity_fields, entry_fields = CANDIDATE_FIELDS[kind]
    defs = schema["$defs"]
    assert defs["Candidate"]["properties"]["content_type"]["enum"] == [kind]
    assert defs["Candidate"]["properties"]["content_language"]["enum"] == [language]
    assert defs["KnowledgeIdentity"]["properties"]["relation"]["enum"] == [relation]
    assert set(defs["KnowledgeIdentity"]["properties"]) == {
        "relation",
        "entries",
        *identity_fields,
    }
    assert set(defs["IdentityEntry"]["properties"]) == {
        "language",
        "expression",
        "sense",
        *entry_fields,
    }
    assert schema["properties"]["candidates"]["maxItems"] == 3
    assert defs["KnowledgeIdentity"]["properties"]["entries"]["maxItems"] == (
        1 if kind == "idiomatic_expression" else 2
    )


@pytest.mark.asyncio
async def test_propose_uses_small_typed_wire_schema_and_compact_cross_type_history(
    repository,
):
    from tests.domains.language_snacks.test_language_snack_schemas import new_snack
    from domains.language_snacks.schemas import Candidate

    raw = new_snack("collocation")
    stored = repository.reserve(
        Candidate.model_validate(
            {k: v for k, v in raw.items() if k in Candidate.model_fields}
        )
    )
    stored.status = "archived"
    repository.save(stored)

    async def chat(request):
        data = json.loads(request.messages[1].content)["data"]
        assert data["content_type"] == "idiomatic_expression"
        assert data["count"] == 3
        assert data["history"] == [stored.identity]
        assert "response_schema" not in request.messages[1].content
        assert stored.id not in request.messages[1].content
        schema = request.extra_params["response_format"]["json_schema"]["schema"]
        assert schema["$defs"]["Candidate"]["properties"]["content_type"]["enum"] == [
            "idiomatic_expression"
        ]
        assert schema["properties"]["candidates"]["maxItems"] == 3
        return LLMResponse(content='{"candidates":[]}')

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "openrouter", chat_completion=chat
        ),
    )
    assert await generator.propose("en", "idiomatic_expression", 6) == []


@pytest.mark.asyncio
async def test_propose_rejects_different_category_even_when_provider_ignores_schema(
    repository,
):
    from tests.domains.language_snacks.test_language_snack_schemas import new_snack
    from domains.language_snacks.schemas import Candidate

    raw = new_snack("collocation")
    candidate = {k: v for k, v in raw.items() if k in Candidate.model_fields}

    async def chat(request):
        return LLMResponse(content=json.dumps({"candidates": [candidate]}))

    generator = SnackGenerator(
        repository,
        provider=SimpleNamespace(
            get_provider_name=lambda: "fake", chat_completion=chat
        ),
    )
    with pytest.raises(SnackError, match="invalid_llm_response"):
        await generator.propose("en", "idiomatic_expression", 3)
    assert generator.metrics["failures"][-1]["code"] == "candidate_request_mismatch"

"""이력 포함 프롬프트, 호출 제한, 예약 재개를 가진 생성 서비스."""

import asyncio
from collections import Counter

from pydantic import ValidationError

from config import get_model_for_provider, get_settings
from domains.language_snacks import prompts
from domains.language_snacks.structured_output import (
    candidate_schema,
    strict_schema,
    validation_issues,
)
from domains.language_snacks.generation_schemas import (
    CandidateBatch,
    DedupeResult,
    QualityResult,
)
from domains.language_snacks.identity import knowledge_key, stable_json
from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import utcnow
from domains.language_snacks.schemas import (
    PAYLOAD_MODELS,
    LanguageSnackCreate,
)
from domains.language_snacks.service import LanguageSnackService
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest
from shared.exceptions import ExternalAPIException, RateLimitException


class SnackGenerator:
    def __init__(self, repository, provider=None, settings=None, *, http_client=None):
        self.repository = repository
        self.settings = settings or get_settings()
        self.provider = provider or LLMProviderFactory.create_provider(
            self.settings.language_snacks_provider, http_client=http_client
        )
        self.model = self.settings.language_snacks_model or get_model_for_provider(
            self.settings.language_snacks_provider
        )
        self.run = None
        self.metrics = {}
        self.knowledge_lock = asyncio.Lock()

    def metadata(self):
        return {
            "provider": self.provider.get_provider_name(),
            "model": self.model,
            "prompt_version": prompts.PROMPT_VERSION,
        }

    def record(self, **values):
        self.metrics = {**self.metrics, **values}
        if self.run:
            self.run.metrics = dict(self.metrics)
            self.repository.save(self.run)

    def record_failure(
        self, schema, code, *, response=None, issues=None, status_code=None, call=None
    ):
        reason = response.finish_reason if response else None
        event = {
            "schema": schema.__name__,
            "code": code,
            "call": call if call is not None else self.metrics.get("calls", 0),
            "finish_reason": reason
            if reason in {"stop", "length", "content_filter", "tool_calls", "error"}
            else None,
        }
        if isinstance(status_code, int):
            event["status_code"] = status_code
        if issues:
            event["issues"] = issues
        self.record(failures=[*self.metrics.get("failures", []), event][-20:])

    async def ask(self, instruction, data, schema):
        output_schema = (
            candidate_schema(
                schema, data["content_type"], data["content_language"], data["count"]
            )
            if schema is CandidateBatch and "content_type" in data
            else strict_schema(schema)
        )
        extra_params = {
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": schema.__name__,
                    "strict": True,
                    "schema": output_schema,
                },
            }
        }
        if self.provider.get_provider_name() == "openrouter":
            extra_params["provider"] = {"require_parameters": True}
        content = stable_json({"data": data})
        messages = [
            LLMMessage(role="system", content=prompts.BASE + instruction),
            LLMMessage(role="user", content=content),
        ]
        for attempt in range(2):
            calls = self.metrics.get("calls", 0)
            if calls >= self.settings.language_snacks_max_calls:
                raise SnackError("generation_budget_exceeded")
            # 단일 이벤트 루프에서 await 전에 호출 번호를 예약해 한도 초과를 막아요.
            call = calls + 1
            self.record(calls=call)
            try:
                response = await asyncio.wait_for(
                    self.provider.chat_completion(
                        LLMRequest(
                            messages=messages,
                            model=self.model,
                            max_tokens=4000,
                            temperature=0.3,
                            extra_params=extra_params,
                        )
                    ),
                    timeout=65,
                )
                if self.repository.guard:
                    self.repository.guard.check()
                actual = (response.usage or {}).get("total_tokens", 0)
                self.record(
                    reported_tokens=self.metrics.get("reported_tokens", 0)
                    + (actual if isinstance(actual, int) else 0)
                )
                if response.refused or response.finish_reason in {
                    "length",
                    "content_filter",
                    "error",
                }:
                    code = (
                        "llm_refusal"
                        if response.refused
                        else "llm_" + response.finish_reason
                    )
                    self.record_failure(schema, code, response=response, call=call)
                    raise SnackError("invalid_llm_response")
                try:
                    return schema.model_validate_json(response.content)
                except ValidationError as error:
                    self.record_failure(
                        schema,
                        "schema_validation",
                        response=response,
                        issues=validation_issues(error, output_schema),
                        call=call,
                    )
                    raise SnackError("invalid_llm_response") from None
            except (TimeoutError, ExternalAPIException, RateLimitException) as error:
                self.record_failure(
                    schema,
                    type(error).__name__,
                    status_code=getattr(error, "details", {}).get("status_code"),
                    call=call,
                )
                if attempt:
                    raise SnackError("llm_unavailable") from None

    def history(self, language):
        history = self.repository.history(language)
        if (
            len(stable_json(history).encode("utf-8"))
            > self.settings.language_snacks_history_bytes
        ):
            raise SnackError("history_budget_exceeded")
        return history

    async def propose(self, language, kind, missing):
        count = min(3, missing)
        batch = await self.ask(
            prompts.CANDIDATES,
            {
                "content_language": language,
                "content_type": kind,
                "count": count,
                # 후보 단계에는 의미 식별 정보만, 최종 중복 검사에는 전체 이력을 써요.
                "history": [item["identity"] for item in self.history(language)],
            },
            CandidateBatch,
        )
        if len(batch.candidates) > count or any(
            candidate.content_type != kind or candidate.content_language != language
            for candidate in batch.candidates
        ):
            self.record_failure(CandidateBatch, "candidate_request_mismatch")
            raise SnackError("invalid_llm_response")
        return batch.candidates

    async def ensure_new(self, candidate):
        history = self.history(candidate.content_language)
        key = knowledge_key(candidate.identity.model_dump(exclude_none=True))
        if any(knowledge_key(item["identity"]) == key for item in history):
            raise SnackError("duplicate_knowledge", 409)
        if not history:
            return
        result = await self.ask(
            prompts.DEDUPE,
            {"candidate": candidate.model_dump(), "history": history},
            DedupeResult,
        )
        if result.decision == "duplicate":
            if result.existing_id not in {item["id"] for item in history}:
                raise SnackError("invalid_duplicate_reference")
            raise SnackError("duplicate_knowledge", 409)
        if result.decision != "new" or result.existing_id is not None:
            raise SnackError("uncertain_knowledge", 422)

    async def verify(self, request):
        result = await self.ask(prompts.VERIFY, request.model_dump(), QualityResult)
        if not result.valid:
            raise SnackError("content_validation_failed", 422)

    async def finish_reservation(self, row):
        attempts = row.generation_metadata.get("attempts", 0)
        while attempts < 2:
            attempts += 1
            row.generation_metadata = {**self.metadata(), "attempts": attempts}
            self.repository.save(row)
            try:
                payload = await self.ask(
                    prompts.AUTHOR,
                    {
                        "identity": row.identity,
                        "content_type": row.content_type,
                        "content_language": row.content_language,
                        "explanation_language": row.explanation_language,
                    },
                    PAYLOAD_MODELS[row.content_type],
                )
                request = LanguageSnackCreate(
                    content_type=row.content_type,
                    content_language=row.content_language,
                    explanation_language=row.explanation_language,
                    identity=row.identity,
                    knowledge_summary=row.knowledge_summary,
                    payload=payload.model_dump(exclude_none=True),
                )
                await self.verify(request)
                LanguageSnackService(self.repository).publish(
                    row, request, {**self.metadata(), "attempts": attempts}
                )
                return
            except asyncio.CancelledError:
                # 다른 카테고리의 중단으로 취소된 예약은 재개 기회를 보존해요.
                row.generation_metadata = {
                    **row.generation_metadata,
                    "attempts": attempts - 1,
                }
                self.repository.save(row)
                raise
            except (SnackError, ValidationError) as error:
                code = (
                    error.code if isinstance(error, SnackError) else "invalid_payload"
                )
                if isinstance(error, ValidationError):
                    self.record_failure(
                        LanguageSnackCreate,
                        "payload_identity_validation",
                        issues=validation_issues(
                            error, LanguageSnackCreate.model_json_schema()
                        ),
                    )
                row.generation_metadata = {**row.generation_metadata, "error": code}
                # 호출·이력 한도나 잠금 종료는 나머지 재시도 기회를 소비하지 않아요.
                if code in (
                    "generation_budget_exceeded",
                    "lock_connection_lost",
                    "history_budget_exceeded",
                ):
                    row.generation_metadata["attempts"] = attempts - 1
                    self.repository.save(row)
                    raise
                self.repository.save(row)
        row.status = "archived"
        self.repository.save(row)

    async def parallel_categories(self, coroutines):
        tasks = [asyncio.create_task(coroutine) for coroutine in coroutines]
        try:
            return await asyncio.gather(*tasks)
        except BaseException:
            # 실패·취소 시 모든 HTTP 작업을 회수한 다음 DB와 외부 쓰기 락을 해제해요.
            for task in tasks:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
            raise

    async def generate_category(self, language, kind, needed):
        try:
            candidates = await self.propose(language, kind, needed)
        except SnackError as error:
            if error.code not in ("invalid_llm_response", "llm_unavailable"):
                raise
            self.record(
                candidate_errors={
                    **self.metrics.get("candidate_errors", {}),
                    kind: error.code,
                }
            )
            return
        published = 0
        for candidate in candidates:
            if published >= needed:
                break
            try:
                # 다른 작업의 reserved 지식까지 보고 중복 판정과 예약을 한 단위로 수행해요.
                async with self.knowledge_lock:
                    await self.ensure_new(candidate)
                    row = self.repository.reserve(candidate, self.run.id)
            except SnackError as error:
                if error.code not in ("duplicate_knowledge", "uncertain_knowledge"):
                    raise
                self.record(**{error.code: self.metrics.get(error.code, 0) + 1})
                continue
            await self.finish_reservation(row)
            if row.published_at:
                published += 1

    async def generate(self, run_key, language, target=3, dry_run=False):
        if language not in ("en", "ko") or not 1 <= target <= 6 or len(run_key) > 150:
            raise SnackError("invalid_run_parameters", 422)
        self.run = None
        self.metrics = {}
        with self.repository.locked():
            if dry_run:
                batches = await self.parallel_categories(
                    self.propose(language, kind, target) for kind in PAYLOAD_MODELS
                )
                candidates = [candidate for batch in batches for candidate in batch]
                return {
                    "status": "dry_run",
                    "candidates": [candidate.model_dump() for candidate in candidates],
                }
            self.run = self.repository.run(run_key, language, target)
            self.metrics = dict(self.run.metrics)
            if self.run.status == "succeeded":
                return {
                    "run_id": self.run.id,
                    "status": "succeeded",
                    "metrics": self.metrics,
                }
            self.run.status = "running"
            self.run.finished_at = None
            self.metrics.pop("error", None)
            self.run.metrics = dict(self.metrics)
            self.repository.save(self.run)
            try:
                self.history(language)
                for row in self.repository.run_snacks(self.run.id):
                    if row.status == "reserved":
                        await self.finish_reservation(row)
                kinds = self.run.content_types
                max_rounds = 3 * ((len(kinds) + 2) // 3)
                while self.metrics.get("rounds", 0) < max_rounds:
                    rows = self.repository.run_snacks(self.run.id)
                    counts = Counter(
                        row.content_type for row in rows if row.published_at is not None
                    )
                    missing = {
                        kind: target - counts[kind]
                        for kind in kinds
                        if counts[kind] < target
                    }
                    if not missing:
                        break
                    self.record(rounds=self.metrics.get("rounds", 0) + 1)
                    await self.parallel_categories(
                        self.generate_category(language, kind, needed)
                        for kind, needed in missing.items()
                    )
                rows = self.repository.run_snacks(self.run.id)
                counts = Counter(
                    row.content_type for row in rows if row.published_at is not None
                )
                self.record(published_by_type=dict(counts))
                self.run.status = (
                    "succeeded"
                    if all(counts[k] >= target for k in kinds)
                    else "partial"
                )
            except SnackError as error:
                if error.code == "lock_connection_lost":
                    raise
                counts = Counter(
                    row.content_type
                    for row in self.repository.run_snacks(self.run.id)
                    if row.published_at is not None
                )
                self.record(error=error.code, published_by_type=dict(counts))
                self.run.status = "partial" if counts else "failed"
            self.run.finished_at = utcnow()
            self.repository.save(self.run)
            return {
                "run_id": self.run.id,
                "status": self.run.status,
                "metrics": self.metrics,
            }

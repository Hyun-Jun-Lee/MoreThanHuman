from typing import Literal

from pydantic import Field, StrictBool

from domains.language_snacks.schemas import Candidate, StrictModel, Text240


class CandidateBatch(StrictModel):
    candidates: list[Candidate] = Field(max_length=12)


class DedupeResult(StrictModel):
    decision: Literal["new", "duplicate", "uncertain"]
    existing_id: str | None = None


class QualityResult(StrictModel):
    valid: StrictBool
    reason: Text240

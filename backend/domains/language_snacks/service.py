"""운영 API와 주기적 생성이 공유하는 생성 검증."""

from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import LanguageSnackModel, utcnow
from domains.language_snacks.repository import LanguageSnackRepository
from domains.language_snacks.schemas import Candidate, LanguageSnackCreate


class LanguageSnackService:
    def __init__(self, repository: LanguageSnackRepository):
        self.repository = repository

    async def create(self, request: LanguageSnackCreate, generator):
        with self.repository.locked():
            candidate = Candidate.model_validate(
                request.model_dump(include=set(Candidate.model_fields))
            )
            await generator.ensure_new(candidate)
            row = self.repository.reserve(candidate, origin="manual")
            try:
                await generator.verify(request)
                return self.publish(row, request, generator.metadata())
            except Exception:
                row.status = "archived"
                row.generation_metadata = {"error": "manual_validation_failed"}
                self.repository.save(row)
                raise

    def publish(self, row, request, metadata):
        row.payload = request.payload
        row.status = "published"
        row.published_at = utcnow()
        row.generation_metadata = metadata
        return self.repository.save(row)

    def archive(self, snack_id):
        row = self.repository.db.get(LanguageSnackModel, str(snack_id))
        if row is None:
            raise SnackError("snack_not_found", 404)
        row.status = "archived"
        self.repository.save(row)
        return {"id": row.id, "status": row.status}

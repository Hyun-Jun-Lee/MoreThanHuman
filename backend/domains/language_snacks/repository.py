"""지식 이력과 생성 상태의 짧은 트랜잭션."""

from contextlib import contextmanager
from uuid import uuid4

from sqlalchemy import desc, func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.language_snacks.identity import canonical_identity, knowledge_key
from domains.language_snacks.lock import SnackError, mutation_lock
from domains.language_snacks.models import LanguageSnackModel, LanguageSnackRunModel


class LanguageSnackRepository:
    def __init__(self, db: Session):
        self.db = db
        self.db.expire_on_commit = False
        self.guard = None

    @contextmanager
    def locked(self):
        with mutation_lock(self.db.get_bind()) as guard:
            self.guard = guard
            try:
                yield
            finally:
                self.guard = None

    def save(self, row):
        if self.guard:
            self.guard.check()
        self.db.add(row)
        try:
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            raise SnackError("duplicate_knowledge", 409) from None
        return row

    def list_published(self, language: str, limit: int = 12, *, order: str = "latest"):
        ordering = (
            (func.random(),)
            if order == "random"
            else (desc(LanguageSnackModel.published_at), desc(LanguageSnackModel.id))
        )
        return (
            self.db.query(LanguageSnackModel)
            .filter(
                LanguageSnackModel.content_language == language,
                LanguageSnackModel.status == "published",
            )
            .order_by(*ordering)
            .limit(limit)
            .all()
        )

    def history(self, language):
        rows = (
            self.db.query(
                LanguageSnackModel.id,
                LanguageSnackModel.identity,
                LanguageSnackModel.knowledge_summary,
            )
            .filter(LanguageSnackModel.content_language == language)
            .order_by(LanguageSnackModel.id)
            .all()
        )
        result = [
            {
                "id": row.id,
                "identity": row.identity,
                "knowledge_summary": row.knowledge_summary,
            }
            for row in rows
        ]
        self.db.commit()
        return result

    def reserve(self, candidate, run_id=None, origin="scheduled"):
        identity = canonical_identity(candidate.identity.model_dump(exclude_none=True))
        return self.save(
            LanguageSnackModel(
                id=str(uuid4()),
                content_type=candidate.content_type,
                content_language=candidate.content_language,
                explanation_language="ko"
                if candidate.content_language == "en"
                else "en",
                identity=identity,
                knowledge_key=knowledge_key(identity),
                knowledge_summary=candidate.knowledge_summary,
                generation_run_id=run_id,
                origin=origin,
                status="reserved",
                generation_metadata={},
            )
        )

    def run(self, key, language, target):
        row = self.db.query(LanguageSnackRunModel).filter_by(run_key=key).first()
        self.db.commit()
        if row:
            if row.content_language != language or row.target_per_type != target:
                raise SnackError("run_configuration_changed", 409)
            return row
        return self.save(
            LanguageSnackRunModel(
                id=str(uuid4()),
                run_key=key,
                content_language=language,
                target_per_type=target,
                status="running",
                metrics={},
            )
        )

    def run_snacks(self, run_id):
        rows = (
            self.db.query(LanguageSnackModel).filter_by(generation_run_id=run_id).all()
        )
        self.db.commit()
        return rows

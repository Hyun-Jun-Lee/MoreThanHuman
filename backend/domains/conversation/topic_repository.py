"""주간 공통 주제의 발행과 조회."""

from datetime import date, datetime
from uuid import uuid4

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from domains.conversation.models import WeeklyTopicBatchModel, WeeklyTopicModel


class WeeklyTopicRepository:
    def __init__(self, db: Session):
        self.db = db

    def latest(self, native: str, target: str) -> tuple[date | None, list[WeeklyTopicModel]]:
        batch = (
            self.db.query(WeeklyTopicBatchModel)
            .join(WeeklyTopicModel)
            .filter(
                WeeklyTopicBatchModel.native_language == native,
                WeeklyTopicBatchModel.target_language == target,
                WeeklyTopicModel.archived_at.is_(None),
            )
            .order_by(WeeklyTopicBatchModel.week_start.desc())
            .first()
        )
        if batch is None:
            return None, []
        topics = (
            self.db.query(WeeklyTopicModel)
            .filter_by(batch_id=batch.id, archived_at=None)
            .order_by(WeeklyTopicModel.position)
            .all()
        )
        return batch.week_start, topics

    def available(self, topic_id: str, native: str, target: str) -> WeeklyTopicModel | None:
        return (
            self.db.query(WeeklyTopicModel)
            .join(WeeklyTopicBatchModel)
            .filter(
                WeeklyTopicModel.id == topic_id,
                WeeklyTopicModel.archived_at.is_(None),
                WeeklyTopicBatchModel.native_language == native,
                WeeklyTopicBatchModel.target_language == target,
            )
            .one_or_none()
        )

    def publish(
        self, native: str, target: str, week_start: str,
        items: list[tuple[str, str]], *, republish: bool = False,
    ) -> list[WeeklyTopicModel]:
        week = date.fromisoformat(week_start)
        existing = self.db.query(WeeklyTopicBatchModel).filter_by(
            native_language=native, target_language=target, week_start=week
        ).one_or_none()
        if existing is not None:
            active = sorted((topic for topic in existing.topics if topic.archived_at is None), key=lambda topic: topic.position)
            if not republish:
                return active
            if len(items) < len(active):
                raise ValueError("not enough topics to preserve existing topic IDs")
            try:
                for index, (text, question) in enumerate(items):
                    if index < len(active):
                        active[index].text = text
                        active[index].first_question = question
                        active[index].position = index
                    else:
                        topic = WeeklyTopicModel(
                            id=str(uuid4()), batch_id=existing.id, text=text,
                            first_question=question, position=index,
                        )
                        self.db.add(topic)
                        active.append(topic)
                existing.published_at = datetime.utcnow()
                self.db.commit()
            except Exception:
                self.db.rollback()
                raise
            return active
        batch = WeeklyTopicBatchModel(
            id=str(uuid4()), native_language=native, target_language=target, week_start=week
        )
        topics = [WeeklyTopicModel(
            id=str(uuid4()), batch=batch, text=text, first_question=question, position=index
        ) for index, (text, question) in enumerate(items)]
        try:
            self.db.add(batch)
            self.db.commit()
        except IntegrityError:
            self.db.rollback()
            existing = self.db.query(WeeklyTopicBatchModel).filter_by(
                native_language=native, target_language=target, week_start=week
            ).one()
            return sorted(existing.topics, key=lambda topic: topic.position)
        return topics

    def archive(self, topic_id: str) -> bool:
        topic = self.db.query(WeeklyTopicModel).filter_by(id=topic_id).one_or_none()
        if topic is None:
            return False
        topic.archived_at = datetime.utcnow()
        self.db.commit()
        return True

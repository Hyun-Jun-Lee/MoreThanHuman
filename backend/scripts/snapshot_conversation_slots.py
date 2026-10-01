"""기존 계정의 동시 보유 슬롯을 캡처해요. 쓰기 중지 후 정책 활성화 전에 실행해요."""

from sqlalchemy import func

from config import get_settings
from database import SessionLocal
from domains.auth.models import ProfileModel
from domains.conversation.models import ConversationModel


def snapshot() -> int:
    if get_settings().conversation_access_enabled:
        raise RuntimeError("CONVERSATION_ACCESS_ENABLED must be false during the snapshot")
    with SessionLocal.begin() as db:
        counts = dict(
            db.query(ConversationModel.user_id, func.count(ConversationModel.id))
            .group_by(ConversationModel.user_id)
            .all()
        )
        profiles = db.query(ProfileModel).all()
        for profile in profiles:
            if profile.legacy_conversation_slots is None:
                profile.legacy_conversation_slots = max(1, counts.get(profile.id, 0))
        return len(profiles)


def main() -> None:
    count = snapshot()
    print(f"conversation slot snapshot completed for {count} profiles")


if __name__ == "__main__":
    main()

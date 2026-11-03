"""운영 정책 활성화 전에 기존 대화의 활성 슬롯을 이행해요."""
from config import get_settings
from database import SessionLocal
from domains.auth.models import ProfileModel
from domains.conversation.repository import ConversationRepository


def initialize() -> int:
    if get_settings().conversation_access_enabled:
        raise RuntimeError("CONVERSATION_ACCESS_ENABLED must be false during initialization")
    with SessionLocal() as db:
        user_ids = [user_id for (user_id,) in db.query(ProfileModel.id).all()]
        repository = ConversationRepository(db)
        for user_id in user_ids:
            repository._locked_entitlement(user_id)
            db.commit()
        return len(user_ids)


if __name__ == "__main__":
    print(f"conversation slots initialized for {initialize()} profiles")

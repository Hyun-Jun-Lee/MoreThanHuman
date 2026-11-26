"""서버 계정 원장에서 계산하는 대화 슬롯·AI 답변 권한."""
from sqlalchemy.orm import Session
from domains.auth.models import ProfileModel
from shared.credit_ledger import CreditLedger


def entitlement_for_user(db: Session, user_id: str, *, profile: ProfileModel | None = None) -> dict:
    ledger = CreditLedger(db)
    profile = ledger.lock(user_id)
    if profile.is_guest:
        return {'plan': 'guest', 'status': 'guest', 'slot_limit': 1, 'turn_limit': 5,
                'turn_scope': 'account', 'limit_action': 'login', 'source': 'guest',
                'is_admin': False, 'unlimited': False, 'expires_at': None}
    return {**ledger.balance(profile), 'plan': 'admin' if profile.is_admin else 'member',
            'status': 'active', 'expires_at': None, 'turn_limit': None,
            'turn_scope': 'account', 'limit_action': 'buy_turns',
            'source': 'admin' if profile.is_admin else 'account'}

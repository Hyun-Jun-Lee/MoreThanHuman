"""관리자의 계정 조회와 추가 슬롯·턴 지급 및 미사용분 회수."""
from datetime import datetime
from sqlalchemy import or_
from sqlalchemy.orm import Session

from domains.auth.models import ProfileModel
from shared.billing_models import CreditLotModel, ManualResourceGrantModel, PurchaseDeliveryModel, TurnReservationModel
from shared.credit_ledger import CreditLedger
from shared.subscription import entitlement_for_user


def grant_data(grant: ManualResourceGrantModel) -> dict:
    return {key: getattr(grant, key) for key in
            ('id', 'resource_kind', 'quantity', 'created_at', 'revoked_at')}


class AdminEntitlementService:
    def __init__(self, db: Session):
        self.db = db

    def user(self, user_id: str, *, lock: bool = False) -> ProfileModel | None:
        query = self.db.query(ProfileModel).filter_by(id=user_id)
        return (query.populate_existing().with_for_update() if lock else query).one_or_none()

    def user_data(self, profile: ProfileModel, *, effective: dict | None = None) -> dict:
        return {'id': profile.id, 'email': profile.email, 'name': profile.name,
                'nickname': profile.nickname, 'is_active': profile.is_active,
                'is_admin': profile.is_admin, 'created_at': profile.created_at,
                'effective': effective or entitlement_for_user(self.db, profile.id)}

    def list_users(self, *, q: str | None, is_admin: bool | None, limit: int, offset: int) -> dict:
        query = self.db.query(ProfileModel)
        if q:
            term = q.strip()
            query = query.filter(or_(ProfileModel.id == term, ProfileModel.email.ilike(f'%{term}%'),
                                     ProfileModel.nickname.ilike(f'%{term}%')))
        if is_admin is not None:
            query = query.filter_by(is_admin=is_admin)
        count = query.count()
        profiles = query.order_by(ProfileModel.created_at.desc(), ProfileModel.id).offset(offset).limit(limit).all()
        results = [self.user_data(profile) for profile in profiles]
        self.db.commit()
        return {'results': results, 'total_count': count, 'limit': limit, 'offset': offset}

    def entitlement_detail(self, profile: ProfileModel) -> dict:
        effective = entitlement_for_user(self.db, profile.id)
        lots = self.db.query(CreditLotModel).filter_by(user_id=profile.id).all()
        purchases = self.db.query(PurchaseDeliveryModel).filter_by(user_id=profile.id).all()
        result = {'user_id': profile.id, 'is_admin': profile.is_admin, 'effective': effective,
                  'credits': [{'source': lot.source, 'quantity': lot.quantity,
                               'available': CreditLedger(self.db).available(lot),
                               'revoked_at': lot.revoked_at} for lot in lots],
                  'purchases': [{'transaction_id': purchase.transaction_id, 'created_at': purchase.created_at,
                                 'product_id': purchase.product_id, 'status': purchase.status,
                                 'resource_kind': purchase.resource_kind, 'quantity': purchase.quantity,
                                 'first_used_at': purchase.first_used_at,
                                 'support_refund_eligible': self._refund_eligible(purchase)}
                                for purchase in purchases]}
        self.db.commit()
        return result

    def _refund_eligible(self, purchase: PurchaseDeliveryModel) -> bool:
        if purchase.status != 'granted':
            return False
        if purchase.resource_kind == 'slots':
            return purchase.first_used_at is None
        lot = self.db.query(CreditLotModel).filter_by(user_id=purchase.user_id, source='apple',
                                                    source_key=purchase.transaction_id).one()
        return not self.db.query(TurnReservationModel).filter_by(lot_id=lot.id, status='committed').first()

    def history(self, user_id: str, *, limit: int, offset: int) -> dict:
        query = self.db.query(ManualResourceGrantModel).filter_by(user_id=user_id)
        return {'results': [grant_data(grant) for grant in query.order_by(
            ManualResourceGrantModel.created_at.desc(), ManualResourceGrantModel.id).offset(offset).limit(limit)],
            'total_count': query.count(), 'limit': limit, 'offset': offset}

    def put_manual(self, user_id: str, request_id: str, resource_kind: str, quantity: int) -> dict | None:
        try:
            profile = self.user(user_id, lock=True)
            if profile is None:
                return None
            if profile.is_guest or profile.is_admin or resource_kind not in {'slots', 'turns'} or quantity <= 0:
                raise ValueError('일반 회원에게 양수의 슬롯 또는 턴을 지급해 주세요')
            grant = self.db.get(ManualResourceGrantModel, request_id)
            if grant:
                if (grant.user_id, grant.resource_kind, grant.quantity) != (user_id, resource_kind, quantity):
                    raise ValueError('이미 다른 지급에 사용한 요청 ID예요')
            else:
                grant = ManualResourceGrantModel(id=request_id, user_id=user_id,
                                                resource_kind=resource_kind, quantity=quantity)
                self.db.add(grant)
                self.db.flush()
                if resource_kind == 'turns':
                    CreditLedger(self.db).grant_turns(profile, quantity, source='manual', source_key=request_id)
            self.db.commit()
            return self.entitlement_detail(profile)
        except Exception:
            self.db.rollback()
            raise

    def delete_manual(self, user_id: str, grant_id: str) -> dict | None:
        try:
            profile = self.user(user_id, lock=True)
            if profile is None:
                return None
            grant = self.db.query(ManualResourceGrantModel).filter_by(id=grant_id, user_id=user_id).one_or_none()
            if grant is None:
                return None
            grant.revoked_at = grant.revoked_at or datetime.utcnow()
            if grant.resource_kind == 'turns':
                lot = self.db.query(CreditLotModel).filter_by(user_id=user_id, source='manual', source_key=grant_id).one()
                CreditLedger(self.db).revoke_lot(profile, lot)
            self.db.commit()
            return self.entitlement_detail(profile)
        except Exception:
            self.db.rollback()
            raise

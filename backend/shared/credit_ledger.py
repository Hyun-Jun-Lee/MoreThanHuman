"""모든 변경은 profile 잠금 아래 실행하며 호출자가 트랜잭션을 확정해요."""
from datetime import datetime, timedelta

from sqlalchemy import func
from sqlalchemy.orm import Session

from domains.auth.models import ProfileModel
from shared.billing_models import CreditLotModel, ManualResourceGrantModel, PurchaseDeliveryModel, TurnReservationModel
from shared.exceptions import AppException


class CreditsExhausted(AppException):
    pass


class CreditLedger:
    def __init__(self, db: Session):
        self.db = db

    def lock(self, user_id: str) -> ProfileModel:
        return self.db.query(ProfileModel).filter_by(id=user_id).populate_existing().with_for_update().one()

    def ensure_trial(self, profile: ProfileModel) -> CreditLotModel | None:
        if profile.is_guest or profile.is_admin:
            return None
        return self.grant_turns(profile, 10, source='trial', source_key='member-trial')

    def grant_turns(self, profile: ProfileModel, quantity: int, *, source: str, source_key: str) -> CreditLotModel:
        if quantity <= 0:
            raise ValueError('Credit quantity must be positive')
        existing = self.db.query(CreditLotModel).filter_by(user_id=profile.id, source=source, source_key=source_key).one_or_none()
        if existing:
            if existing.quantity != quantity:
                raise ValueError('Grant request was reused with a different quantity')
            return existing
        lot = CreditLotModel(user_id=profile.id, source=source, source_key=source_key, quantity=quantity)
        self.db.add(lot)
        self.db.flush()
        return lot

    def expire(self, user_id: str) -> None:
        now = datetime.utcnow()
        reservations = self.db.query(TurnReservationModel).filter(
            TurnReservationModel.user_id == user_id, TurnReservationModel.status == 'reserved',
            TurnReservationModel.deadline_at < now,
        ).all()
        for reservation in reservations:
            lot = self.db.get(CreditLotModel, reservation.lot_id)
            reservation.status = 'revoked' if lot.revoked_at else 'released'
            reservation.finished_at = now
        self.db.flush()

    def _lots(self, profile: ProfileModel) -> list[CreditLotModel]:
        self.ensure_trial(profile)
        self.expire(profile.id)
        return self.db.query(CreditLotModel).filter_by(user_id=profile.id).order_by(
            (CreditLotModel.source != 'trial'), CreditLotModel.created_at, CreditLotModel.id,
        ).all()

    def available(self, lot: CreditLotModel) -> int:
        if lot.revoked_at:
            return 0
        used = self.db.query(TurnReservationModel).filter(
            TurnReservationModel.lot_id == lot.id,
            TurnReservationModel.status.in_(['reserved', 'committed', 'revoked']),
        ).count()
        return max(0, lot.quantity - used)

    def balance(self, profile: ProfileModel) -> dict:
        lots = self._lots(profile)
        remaining_trial = sum(self.available(lot) for lot in lots if lot.source == 'trial')
        remaining_paid = sum(self.available(lot) for lot in lots if lot.source != 'trial')
        slots = self.db.query(func.coalesce(func.sum(PurchaseDeliveryModel.quantity), 0)).filter_by(
            user_id=profile.id, resource_kind='slots', status='granted',
        ).scalar()
        manual = self.db.query(func.coalesce(func.sum(ManualResourceGrantModel.quantity), 0)).filter_by(
            user_id=profile.id, resource_kind='slots', revoked_at=None,
        ).scalar()
        return {'slot_limit': None if profile.is_admin else 1 + slots + manual,
                'additional_slots': slots + manual,
                'remaining_turns': None if profile.is_admin else remaining_trial + remaining_paid,
                'trial_turns': remaining_trial, 'paid_turns': remaining_paid,
                'unlimited': bool(profile.is_admin), 'is_admin': bool(profile.is_admin)}

    def reserve(self, profile: ProfileModel, request_key: str) -> TurnReservationModel | None:
        if profile.is_admin or profile.is_guest:
            return None
        lots = self._lots(profile)
        existing = self.db.query(TurnReservationModel).filter_by(user_id=profile.id, request_key=request_key).one_or_none()
        if existing and existing.status in {'reserved', 'committed'}:
            return existing
        lot = next((lot for lot in lots if self.available(lot) > 0), None)
        if lot is None:
            raise CreditsExhausted('남은 AI 답변 횟수가 없어요')
        if existing is None:
            existing = TurnReservationModel(user_id=profile.id, request_key=request_key)
            self.db.add(existing)
        existing.lot_id = lot.id
        existing.status = 'reserved'
        existing.deadline_at = datetime.utcnow() + timedelta(minutes=5)
        existing.finished_at = None
        self.db.flush()
        return existing

    def commit(self, user_id: str, request_key: str) -> None:
        profile = self.lock(user_id)
        if profile.is_guest or profile.is_admin:
            return
        self.expire(user_id)
        reservation = self.db.query(TurnReservationModel).filter_by(user_id=user_id, request_key=request_key).one_or_none()
        if reservation is None:
            return  # 회원 제한이 꺼진 요청에는 예약이 없어요.
        if reservation.status == 'committed':
            return
        if reservation.status != 'reserved':
            raise ValueError('Turn reservation is no longer active')
        reservation.status = 'committed'
        reservation.finished_at = datetime.utcnow()
        self.db.query(PurchaseDeliveryModel).filter_by(
            user_id=user_id, resource_kind='slots', status='granted', first_used_at=None,
        ).update({'first_used_at': reservation.finished_at}, synchronize_session='fetch')
        self.db.flush()

    def release(self, user_id: str, request_key: str) -> None:
        self.lock(user_id)
        reservation = self.db.query(TurnReservationModel).filter_by(user_id=user_id, request_key=request_key, status='reserved').one_or_none()
        if reservation:
            lot = self.db.get(CreditLotModel, reservation.lot_id)
            reservation.status = 'revoked' if lot.revoked_at else 'released'
            reservation.finished_at = datetime.utcnow()
            self.db.flush()

    def revoke_lot(self, profile: ProfileModel, lot: CreditLotModel) -> None:
        if lot.user_id != profile.id:
            raise ValueError('Credit lot ownership mismatch')
        lot.revoked_at = lot.revoked_at or datetime.utcnow()
        self.db.flush()

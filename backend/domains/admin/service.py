from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import or_
from sqlalchemy.orm import Session

from config import get_settings
from domains.auth.models import ProfileModel
from domains.conversation.repository import ConversationRepository
from shared.subscription import (
    AppleSubscriptionModel,
    ManualEntitlementGrantModel,
    active_manual_grant,
    apple_entitlement_from_records,
    apple_entitlement_for_user,
    effective_entitlement,
    entitlement_for_user,
)


def grant_data(grant: ManualEntitlementGrantModel) -> dict:
    def utc(value: datetime | None) -> datetime | None:
        return value.replace(tzinfo=timezone.utc) if value is not None else None

    return {
        "id": grant.id,
        "plan": grant.plan,
        "revoke_at": utc(grant.revoke_at),
        "revoked_at": utc(grant.revoked_at),
        "granted_by": grant.granted_by,
        "revoked_by": grant.revoked_by,
        "created_at": utc(grant.created_at),
    }


class AdminEntitlementService:
    def __init__(self, db: Session):
        self.db = db

    def user(self, user_id: str, *, lock: bool = False) -> ProfileModel | None:
        query = self.db.query(ProfileModel).filter_by(id=user_id)
        return (query.with_for_update() if lock else query).one_or_none()

    def user_data(self, profile: ProfileModel, *, effective: dict | None = None) -> dict:
        return {
            "id": profile.id,
            "email": profile.email,
            "name": profile.name,
            "nickname": profile.nickname,
            "is_active": profile.is_active,
            "is_admin": profile.is_admin,
            "created_at": profile.created_at,
            "effective": effective or entitlement_for_user(self.db, profile.id, profile=profile),
        }

    def user_data_batch(self, profiles: list[ProfileModel]) -> list[dict]:
        now = datetime.utcnow()
        user_ids = [profile.id for profile in profiles if not profile.is_admin]
        apple_by_user: dict[str, list[AppleSubscriptionModel]] = {}
        manual_by_user: dict[str, ManualEntitlementGrantModel] = {}
        if user_ids:
            for record in self.db.query(AppleSubscriptionModel).filter(
                AppleSubscriptionModel.user_id.in_(user_ids)
            ).all():
                apple_by_user.setdefault(record.user_id, []).append(record)
            grants = (self.db.query(ManualEntitlementGrantModel)
                      .filter(ManualEntitlementGrantModel.user_id.in_(user_ids),
                              ManualEntitlementGrantModel.revoked_at.is_(None),
                              (ManualEntitlementGrantModel.revoke_at.is_(None)
                               | (ManualEntitlementGrantModel.revoke_at > now)))
                      .order_by(ManualEntitlementGrantModel.created_at.desc(),
                                ManualEntitlementGrantModel.id.desc()).all())
            for grant in grants:
                manual_by_user.setdefault(grant.user_id, grant)
        results = []
        for profile in profiles:
            apple = (None if profile.is_admin else
                     apple_entitlement_from_records(apple_by_user.get(profile.id, []), now=now))
            effective = effective_entitlement(profile, apple, manual_by_user.get(profile.id))
            results.append(self.user_data(profile, effective=effective))
        return results

    def list_users(
        self, *, q: str | None, plan: str | None, source: str | None,
        is_admin: bool | None, limit: int, offset: int,
    ) -> dict:
        query = self.db.query(ProfileModel)
        if q:
            term = q.strip()
            query = query.filter(or_(ProfileModel.id == term,
                                     ProfileModel.email.ilike(f"%{term}%"),
                                     ProfileModel.nickname.ilike(f"%{term}%")))
        if is_admin is not None:
            query = query.filter(ProfileModel.is_admin == is_admin)
        if plan is None and source is None:
            total_count = query.count()
            profiles = (query.order_by(ProfileModel.created_at.desc(), ProfileModel.id.desc())
                        .offset(offset).limit(limit).all())
            return {"results": self.user_data_batch(profiles),
                    "total_count": total_count, "limit": limit, "offset": offset}
        ordered = query.order_by(ProfileModel.created_at.desc(), ProfileModel.id.desc())
        results = []
        matched = 0
        batch_offset = 0
        while True:
            profiles = ordered.offset(batch_offset).limit(200).all()
            if not profiles:
                break
            for data in self.user_data_batch(profiles):
                effective = data["effective"]
                if plan is not None and effective["plan"] != plan:
                    continue
                if source is not None and effective["source"] != source:
                    continue
                if offset <= matched < offset + limit:
                    results.append(data)
                matched += 1
            batch_offset += len(profiles)
        return {"results": results, "total_count": matched,
                "limit": limit, "offset": offset}

    def entitlement_detail(self, profile: ProfileModel) -> dict:
        now = datetime.utcnow()
        grant = active_manual_grant(self.db, profile.id, now=now)
        apple = apple_entitlement_for_user(self.db, profile.id, now=now)
        return {
            "user_id": profile.id,
            "is_admin": profile.is_admin,
            "apple": apple,
            "manual": grant_data(grant) if grant else None,
            "effective": effective_entitlement(profile, apple, grant),
        }

    def history(self, user_id: str, *, limit: int, offset: int) -> dict:
        query = self.db.query(ManualEntitlementGrantModel).filter_by(user_id=user_id)
        count = query.count()
        grants = (query.order_by(ManualEntitlementGrantModel.created_at.desc(),
                                 ManualEntitlementGrantModel.id.desc())
                  .offset(offset).limit(limit).all())
        return {"results": [grant_data(grant) for grant in grants],
                "total_count": count, "limit": limit, "offset": offset}

    def put_manual(self, user_id: str, actor_id: str | None, plan: str, revoke_at: datetime | None) -> dict | None:
        try:
            profile = self.user(user_id, lock=True)
            if profile is None:
                return None
            now = datetime.utcnow()
            current = active_manual_grant(self.db, user_id, now=now)
            if current is not None and current.plan == plan and current.revoke_at == revoke_at:
                self.db.commit()
                return self.entitlement_detail(profile)
            if current is not None:
                current.revoked_at = now
                current.revoked_by = actor_id
            self.db.add(ManualEntitlementGrantModel(
                id=str(uuid4()), user_id=user_id, plan=plan, revoke_at=revoke_at,
                granted_by=actor_id, created_at=now,
            ))
            self.db.flush()
            if get_settings().conversation_access_enabled:
                ConversationRepository(self.db)._reconcile_slots_locked(profile)
            self.db.commit()
            return self.entitlement_detail(profile)
        except Exception:
            self.db.rollback()
            raise

    def delete_manual(self, user_id: str, actor_id: str | None) -> dict | None:
        try:
            profile = self.user(user_id, lock=True)
            if profile is None:
                return None
            current = active_manual_grant(self.db, user_id, now=datetime.utcnow())
            if current is not None:
                current.revoked_at = datetime.utcnow()
                current.revoked_by = actor_id
                self.db.flush()
                if get_settings().conversation_access_enabled:
                    ConversationRepository(self.db)._reconcile_slots_locked(profile)
            self.db.commit()
            return self.entitlement_detail(profile)
        except Exception:
            self.db.rollback()
            raise

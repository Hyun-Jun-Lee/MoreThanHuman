from datetime import datetime
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base, get_db
from domains.auth.dependencies import get_current_ai_profile, get_current_profile
from domains.auth.models import ProfileModel, UserConsentModel
from domains.auth.router import router
from domains.auth.consent import AIConsentService


def test_notice_choice_api_versions_ownership_and_legacy_compatibility(monkeypatch):
    settings = SimpleNamespace(
        privacy_policy_version='privacy-v1', ai_data_processing_version='ai-v1',
        privacy_policy_url='https://example.com/privacy',
        privacy_policy_url_en='https://example.com/en/privacy', ai_consent_required=True,
    )
    for module in ('router', 'consent', 'dependencies'):
        monkeypatch.setattr(f'domains.auth.{module}.get_settings', lambda: settings)
    engine = create_engine('sqlite://', poolclass=StaticPool, connect_args={'check_same_thread': False})
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as db:
        guest = ProfileModel(id='guest', name='Guest', is_guest=True, last_active_at=datetime.utcnow())
        member = ProfileModel(id='member', name='Member', is_guest=False)
        db.add_all([guest, member])
        db.commit()
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: db
        with TestClient(app) as client:
            notice = client.get('/api/auth/ai-notice')
            assert notice.status_code == 200
            assert notice.json()['data']['accepted'] is False
            assert client.get('/api/auth/me/ai-consent').status_code in (401, 403)
            app.dependency_overrides[get_current_profile] = lambda: guest
            choice = {'privacy_policy_version': 'privacy-v1', 'ai_data_processing_version': 'ai-v1', 'accept_ai': False}
            result = client.post('/api/auth/me/ai-consent', json=choice)
            assert result.status_code == 200
            assert result.json()['data']['notice_acknowledged'] is True
            assert result.json()['data']['accepted'] is False
            assert db.query(UserConsentModel).filter_by(user_id='member').count() == 0
            import pytest
            from fastapi import HTTPException
            with pytest.raises(HTTPException) as error:
                get_current_ai_profile(guest, db)
            assert error.value.detail['code'] == 'CONSENT_REQUIRED'
            assert client.post('/api/auth/me/ai-consent', json={**choice, 'user_id': 'member'}).status_code == 422
            assert client.post('/api/auth/me/ai-consent', json={**choice, 'accept_ai': 'yes'}).status_code == 422
            assert client.post('/api/auth/me/ai-consent', json={**choice, 'ai_data_processing_version': 'old', 'accept_ai': True}).status_code == 409
            assert AIConsentService(db).status('guest')['accepted'] is False
            assert client.post('/api/auth/me/ai-consent', json={**choice, 'accept_ai': True}).json()['data']['accepted'] is True
            assert get_current_ai_profile(guest, db).id == 'guest'
            # 기존 앱은 명시적 동의 버튼에서 빈 본문으로 요청해요.
            app.dependency_overrides[get_current_profile] = lambda: member
            assert client.post('/api/auth/me/ai-consent').json()['data']['accepted'] is True
            assert db.query(UserConsentModel).filter_by(user_id='member', consent_kind='privacy_policy').count() == 1
    engine.dispose()

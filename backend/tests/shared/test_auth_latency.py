import json
from types import SimpleNamespace

import httpx
import pytest
from fastapi import Depends, FastAPI, HTTPException

from domains.auth.dependencies import (
    get_auth_service, get_current_user, get_current_user_from_token_param,
    get_supabase_auth_verifier,
)
from domains.billing.apple import AppleVerificationError
from domains.billing.service import BillingService
from domains.language_snacks.dependencies import (
    get_language_snack_operations_key, require_language_snack_operations_key,
)
from shared.latency import LatencyMiddleware


class Verifier:
    async def verify_access_token(self, token):
        if token != "private-token":
            raise ValueError("invalid token")
        return {"sub": "user"}


class AuthService:
    def get_or_create_profile_from_claims(self, claims):
        return SimpleNamespace(id=claims["sub"], is_active=True)


class FailingAppleGateway:
    def decode_notification(self, signed_payload):
        raise AppleVerificationError("signature secret: " + signed_payload)


@pytest.mark.asyncio
async def test_all_protected_auth_paths_share_request_context_without_tokens(capsys):
    app = FastAPI()
    app.add_middleware(LatencyMiddleware)
    app.dependency_overrides[get_auth_service] = AuthService
    app.dependency_overrides[get_supabase_auth_verifier] = Verifier
    app.dependency_overrides[get_language_snack_operations_key] = lambda: "operations-secret"

    @app.get("/api/bearer/")
    async def bearer(user=Depends(get_current_user)):
        return {"id": user.id}

    @app.get("/api/sse/")
    async def sse(user=Depends(get_current_user_from_token_param)):
        return {"id": user.id}

    @app.post("/api/operations/", dependencies=[Depends(require_language_snack_operations_key)])
    async def operations():
        return {"ok": True}

    @app.post("/api/apple/")
    async def apple():
        try:
            BillingService(None, FailingAppleGateway()).process_notification("signed-secret")
        except AppleVerificationError:
            raise HTTPException(status_code=400, detail="invalid notification")

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="http://test") as client:
        responses = [
            await client.get("/api/bearer/", headers={"Authorization": "Bearer private-token"}),
            await client.get("/api/sse/?token=private-token"),
            await client.post("/api/operations/", headers={"X-Operations-Key": "operations-secret"}),
            await client.post("/api/apple/"),
            await client.get("/api/bearer/"),
        ]

    rows = [json.loads(line) for line in capsys.readouterr().out.splitlines()
            if line.startswith("{") and '"event":"http.' in line]
    assert [response.status_code for response in responses] == [200, 200, 200, 400, 403]
    for route in ("/api/bearer/", "/api/sse/", "/api/operations/", "/api/apple/"):
        completed = next(row for row in rows if row["event"] == "http.request.completed"
                         and row["route"] == route and row["status_code"] != 403)
        stages = [row for row in rows if row["event"] == "http.stage.completed"
                  and row["request_id"] == completed["request_id"]]
        assert len(stages) == 1
        assert stages[0]["stage"] == "auth"
    forbidden = next(row for row in rows if row["event"] == "http.request.completed"
                     and row["status_code"] == 403)
    assert not any(row["event"] == "http.stage.completed" and
                   row["request_id"] == forbidden["request_id"] for row in rows)
    assert all(secret not in json.dumps(rows) for secret in
               ("private-token", "operations-secret", "signed-secret"))

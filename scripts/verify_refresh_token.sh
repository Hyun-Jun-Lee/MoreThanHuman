#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8010}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd curl
require_cmd python

python_json_get() {
  local key="$1"
  python - "$key" <<'PY'
import json, sys
key = sys.argv[1]
raw = sys.stdin.read()
obj = json.loads(raw)
parts = key.split(".")
cur = obj
for p in parts:
  cur = cur[p]
if isinstance(cur, (dict, list)):
  print(json.dumps(cur))
else:
  print(cur)
PY
}

echo "== Verify refresh token flow =="
echo "BASE_URL=$BASE_URL"

DEVICE_ID="$(python - <<'PY'
import uuid
print(str(uuid.uuid4()))
PY
)"

EMAIL="$(python - <<'PY'
import secrets
print(f"verify_{secrets.token_hex(6)}@example.com")
PY
)"

PASSWORD="password"
NAME="VerifyUser"

echo
echo "[1] Register (expects access_token + refresh_token)"
REGISTER_BODY="$(cat <<JSON
{"email":"$EMAIL","password":"$PASSWORD","name":"$NAME","device_id":"$DEVICE_ID"}
JSON
)"

REGISTER_RESP="$(curl -sS -X POST "$BASE_URL/api/auth/register" -H 'Content-Type: application/json' -d "$REGISTER_BODY")"
echo "$REGISTER_RESP" | python_json_get "success" >/dev/null
ACCESS_TOKEN="$(echo "$REGISTER_RESP" | python_json_get "data.access_token")"
REFRESH_TOKEN_1="$(echo "$REGISTER_RESP" | python_json_get "data.refresh_token")"
echo "access_token: ${ACCESS_TOKEN:0:16}..."
echo "refresh_token: ${REFRESH_TOKEN_1:0:16}..."

echo
echo "[2] /me with access_token (expects 200)"
ME_CODE="$(curl -sS -o /dev/null -w "%{http_code}" "$BASE_URL/api/auth/me" -H "Authorization: Bearer $ACCESS_TOKEN")"
echo "status=$ME_CODE"

echo
echo "[3] Refresh (rotate) using refresh_token_1 (expects 200 + new refresh token)"
REFRESH_BODY_1="$(cat <<JSON
{"refresh_token":"$REFRESH_TOKEN_1","device_id":"$DEVICE_ID"}
JSON
)"

REFRESH_RESP_1="$(curl -sS -X POST "$BASE_URL/api/auth/refresh" -H 'Content-Type: application/json' -d "$REFRESH_BODY_1")"
NEW_ACCESS_TOKEN="$(echo "$REFRESH_RESP_1" | python_json_get "data.access_token")"
REFRESH_TOKEN_2="$(echo "$REFRESH_RESP_1" | python_json_get "data.refresh_token")"
echo "new access_token: ${NEW_ACCESS_TOKEN:0:16}..."
echo "new refresh_token: ${REFRESH_TOKEN_2:0:16}..."

echo
echo "[4] Reuse old refresh_token_1 (expects 401)"
REUSE_CODE="$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/auth/refresh" -H 'Content-Type: application/json' -d "$REFRESH_BODY_1")"
echo "status=$REUSE_CODE"

echo
echo "[5] Concurrency: 2 refresh calls with same refresh_token_2 (expects 1x200, 1x401)"
REFRESH_BODY_2="$(cat <<JSON
{"refresh_token":"$REFRESH_TOKEN_2","device_id":"$DEVICE_ID"}
JSON
)"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

(
  curl -sS -o "$TMPDIR/r1.body" -w "%{http_code}" -X POST "$BASE_URL/api/auth/refresh" -H 'Content-Type: application/json' -d "$REFRESH_BODY_2" >"$TMPDIR/r1.code"
) &
(
  curl -sS -o "$TMPDIR/r2.body" -w "%{http_code}" -X POST "$BASE_URL/api/auth/refresh" -H 'Content-Type: application/json' -d "$REFRESH_BODY_2" >"$TMPDIR/r2.code"
) &
wait

CODE1="$(cat "$TMPDIR/r1.code")"
CODE2="$(cat "$TMPDIR/r2.code")"
echo "call1 status=$CODE1"
echo "call2 status=$CODE2"

if [[ "$CODE1" == "200" ]]; then
  REFRESH_TOKEN_3="$(cat "$TMPDIR/r1.body" | python_json_get "data.refresh_token")"
elif [[ "$CODE2" == "200" ]]; then
  REFRESH_TOKEN_3="$(cat "$TMPDIR/r2.body" | python_json_get "data.refresh_token")"
else
  echo "Neither refresh call succeeded (expected one 200)." >&2
  echo "call1 body: $(cat "$TMPDIR/r1.body")" >&2
  echo "call2 body: $(cat "$TMPDIR/r2.body")" >&2
  exit 1
fi

echo
echo "[6] Logout using latest refresh token (expects 200)"
LOGOUT_BODY="$(cat <<JSON
{"refresh_token":"$REFRESH_TOKEN_3","device_id":"$DEVICE_ID"}
JSON
)"
LOGOUT_CODE="$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/auth/logout" -H 'Content-Type: application/json' -d "$LOGOUT_BODY")"
echo "status=$LOGOUT_CODE"

echo
echo "[7] Refresh after logout (expects 401)"
AFTER_LOGOUT_CODE="$(curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/auth/refresh" -H 'Content-Type: application/json' -d "$REFRESH_BODY_2")"
echo "status=$AFTER_LOGOUT_CODE"

echo
echo "Done."
echo
echo "OAuth manual check:"
echo "- Call:  GET $BASE_URL/api/auth/google/login?device_id=$DEVICE_ID"
echo "- Open returned url in browser, complete login, verify callback includes state and response includes access_token + refresh_token"


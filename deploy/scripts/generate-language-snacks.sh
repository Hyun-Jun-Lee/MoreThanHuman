#!/bin/sh
set -eu
# 절대 경로로 호출하면 cron의 작업 디렉터리에 의존하지 않아요.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR/../.."
exec docker compose --profile jobs run --rm --no-deps snack-generator python -m scripts.generate_language_snacks "$@"

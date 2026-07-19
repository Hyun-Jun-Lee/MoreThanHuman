#!/usr/bin/env sh
set -eu

docker compose --profile certbot run --rm certbot-renew
docker compose exec nginx nginx -s reload

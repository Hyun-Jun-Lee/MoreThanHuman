#!/usr/bin/env sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

certbot renew --webroot --webroot-path=/var/www/certbot
docker compose exec nginx nginx -s reload

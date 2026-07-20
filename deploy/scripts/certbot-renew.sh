#!/usr/bin/env sh
set -eu

sudo certbot renew --webroot --webroot-path=/var/www/certbot
docker compose exec nginx nginx -s reload

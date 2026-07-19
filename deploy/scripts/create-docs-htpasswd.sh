#!/usr/bin/env sh
set -eu

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "Usage: $0 <username> <password>" >&2
  exit 1
fi

mkdir -p deploy/nginx/auth
docker run --rm httpd:2.4-alpine htpasswd -nbB "$1" "$2" > deploy/nginx/auth/docs.htpasswd
chmod 600 deploy/nginx/auth/docs.htpasswd
echo "Created deploy/nginx/auth/docs.htpasswd"

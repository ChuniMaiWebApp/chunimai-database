#!/usr/bin/env bash
# =============================================================================
# Applies the data-service stack on the VPS.
#
#   ./scripts/deploy.sh
#
# This repo holds no application code, so a "deploy" is: pull the compose file
# and nginx configs, reconcile the containers, and check they answer.
#
# Deliberately does NOT reload nginx or touch /etc — those are one-time,
# root-owned, and a CI job that rewrites them on every push is a good way to
# take the site down from a typo. The script prints what changed instead, and
# you apply it by hand.
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose -f docker-compose.prod.yml --env-file .env.prod)

log()  { printf '\n\033[1;36m▸ %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31m✖ %s\033[0m\n' "$*" >&2; }

[ -f .env.prod ] || { fail ".env.prod is missing. Copy .env.prod.example."; exit 1; }

log "===== DATA DEPLOY $(date -u +%Y-%m-%dT%H:%M:%SZ) ====="

log "Fetching latest"
BRANCH="${DEPLOY_BRANCH:-$(git symbolic-ref --short HEAD)}"
git fetch --prune origin
git reset --hard "origin/$BRANCH"

log "Reconciling containers"
"${COMPOSE[@]}" up -d --remove-orphans

log "Waiting for Postgres"
for attempt in $(seq 1 30); do
  if "${COMPOSE[@]}" exec -T postgres pg_isready -q; then
    echo "  postgres: ready"
    break
  fi
  if [ "$attempt" -eq 30 ]; then
    fail "Postgres did not become ready within 60s."
    "${COMPOSE[@]}" logs --tail 40 postgres
    exit 1
  fi
  sleep 2
done

log "Waiting for Redis"
if ! "${COMPOSE[@]}" exec -T redis redis-cli ping | grep -q PONG; then
  fail "Redis did not answer PING."
  exit 1
fi
echo "  redis: PONG"

log "Studio"
code=$(curl -fsS --max-time 10 -o /dev/null -w '%{http_code}' http://127.0.0.1:3010/ 2>/dev/null || echo 000)
# Studio is a convenience surface, not something players depend on. Say so and
# carry on rather than failing a deploy of the database over it.
[ "$code" = "200" ] && echo "  studio: 200" || echo "  studio: http $code (not fatal)"

log "Checking whether the nginx configs in this commit differ from the installed ones"
changed=0
for pair in \
  "nginx/http-globals.conf:/etc/nginx/conf.d/chunimai-globals.conf" \
  "nginx/cloudflare-realip.conf:/etc/nginx/conf.d/cloudflare-realip.conf" \
  "nginx/snippets-proxy.conf:/etc/nginx/snippets/chunimai-proxy.conf" \
  "nginx/chunithm-api.conf:/etc/nginx/sites-available/chunithm-api" \
  "nginx/chunithm-app.conf:/etc/nginx/sites-available/chunithm-app" \
  "nginx/my-db.conf:/etc/nginx/sites-available/my-db"
do
  src="${pair%%:*}"; dst="${pair##*:}"
  if [ -f "$dst" ] && ! diff -q "$src" "$dst" >/dev/null 2>&1; then
    echo "  CHANGED: $src → $dst"
    changed=1
  fi
done

if [ "$changed" -eq 1 ]; then
  echo
  echo "  nginx configs differ. Review, then apply by hand:"
  echo "    sudo cp nginx/http-globals.conf     /etc/nginx/conf.d/chunimai-globals.conf"
  echo "    sudo cp nginx/cloudflare-realip.conf /etc/nginx/conf.d/"
  echo "    sudo cp nginx/snippets-proxy.conf   /etc/nginx/snippets/chunimai-proxy.conf"
  echo "    sudo cp nginx/chunithm-api.conf     /etc/nginx/sites-available/chunithm-api"
  echo "    sudo cp nginx/chunithm-app.conf     /etc/nginx/sites-available/chunithm-app"
  echo "    sudo cp nginx/my-db.conf            /etc/nginx/sites-available/my-db"
  echo "    sudo nginx -t && sudo systemctl reload nginx"
else
  echo "  nginx: in sync"
fi

log "===== DATA DEPLOY OK ====="

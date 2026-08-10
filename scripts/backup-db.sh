#!/usr/bin/env bash
# =============================================================================
# Nightly Postgres dump.
#
#   ./scripts/backup-db.sh
#
# Install as a cron job (as the deploy user, not root):
#   crontab -e
#   15 19 * * *  /var/www/chunithm-queue/scripts/backup-db.sh >> /var/www/chunithm-queue/logs/backup.log 2>&1
#   # 19:15 UTC = 02:15 Vietnam time — after the arcades close, before the
#   # 08:00 UTC song-data refresh.
#
# What is actually irreplaceable in here: the encrypted CHUNITHM-NET cookie
# jars (every player would have to link their account again) and app.play_details
# (judgement breakdowns for plays that have already fallen out of the 50-track
# playlog window — CHUNITHM-NET cannot give those back).
#
# A dump on the same disk survives a bad migration, not a dead VPS. Copy them
# off the box if the data matters.
# =============================================================================

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"
RETAIN_DAYS="${RETAIN_DAYS:-14}"
STAMP=$(date -u +%Y%m%d-%H%M%S)
TARGET="$BACKUP_DIR/chunithm-$STAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

# shellcheck disable=SC1091
POSTGRES_USER=$(grep -E '^POSTGRES_USER=' .env.prod | cut -d= -f2- || true)
POSTGRES_DB=$(grep -E '^POSTGRES_DB=' .env.prod | cut -d= -f2- || true)

docker compose -f docker-compose.prod.yml --env-file .env.prod exec -T postgres \
  pg_dump -U "${POSTGRES_USER:-postgres}" -d "${POSTGRES_DB:-postgres}" \
  | gzip -9 > "$TARGET"

SIZE=$(stat -c %s "$TARGET")

# A dump that fails midway still leaves a valid gzip header, so size is the
# cheapest check that something real landed. An empty schema is bigger than 10k.
if [ "$SIZE" -lt 10240 ]; then
  echo "$(date -u +%FT%TZ) FAILED: $TARGET is only ${SIZE}B — refusing to rotate old backups." >&2
  rm -f "$TARGET"
  exit 1
fi

echo "$(date -u +%FT%TZ) ok: $TARGET ($((SIZE / 1024)) KiB)"

find "$BACKUP_DIR" -name 'chunithm-*.sql.gz' -mtime "+$RETAIN_DAYS" -delete

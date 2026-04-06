#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="${BABYTRACK_SYNC_DB:-${ROOT_DIR}/backend/api/data/sync_events.db}"
RETENTION_DAYS="${BABYTRACK_SYNC_RETENTION_DAYS:-365}"
GUARD_RETENTION_SEC="${BABYTRACK_SYNC_GUARD_RETENTION_SEC:-86400}"

python3 "${ROOT_DIR}/backend/api/sync_db_retention.py" \
  --db "${DB_PATH}" \
  --event-retention-days "${RETENTION_DAYS}" \
  --guard-retention-sec "${GUARD_RETENTION_SEC}"

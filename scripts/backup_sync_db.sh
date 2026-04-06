#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="${BABYTRACK_SYNC_DB:-${ROOT_DIR}/backend/api/data/sync_events.db}"
OUT_DIR="${ROOT_DIR}/backend/api/backups"

python3 "${ROOT_DIR}/backend/api/sync_db_backup.py" \
  --db "${DB_PATH}" \
  --out "${OUT_DIR}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v uvicorn >/dev/null 2>&1; then
  echo "uvicorn not found; starting stdlib fallback API..."
  python3 "${ROOT_DIR}/backend/api/server_stdlib.py"
  exit 0
fi

uvicorn backend.api.server:app --host 127.0.0.1 --port 8787 --reload

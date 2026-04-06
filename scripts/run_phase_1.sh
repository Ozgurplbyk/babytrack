#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/generated/assets"

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "ERROR: GEMINI_API_KEY is not set."
  exit 2
fi

echo "[Phase-1] Starting full asset generation..."
python3 "${ROOT_DIR}/tools/gemini/generate_assets.py" \
  --manifest "${ROOT_DIR}/assets/manifest/asset_manifest_v1.json" \
  --style "${ROOT_DIR}/tools/gemini/style_system.json" \
  --out "${OUT_DIR}"

echo "[Phase-1] Completed. Output: ${OUT_DIR}"


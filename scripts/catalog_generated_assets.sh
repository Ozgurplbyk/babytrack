#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="${ROOT_DIR}/generated/assets"
OUT_FILE="${ROOT_DIR}/docs/ASSET_CATALOG_TR.md"

if [[ ! -d "${ASSET_DIR}" ]]; then
  echo "ERROR: generated/assets not found. Run phase 1 first."
  exit 1
fi

{
  echo "# Uretilen Asset Katalogu"
  echo
  echo "Toplam dosya sayisi: $(find "${ASSET_DIR}" -type f | wc -l | tr -d ' ')"
  echo
  echo "## Dosyalar"
  echo
  find "${ASSET_DIR}" -type f | sort | sed "s#${ROOT_DIR}/##" | while read -r file; do
    echo "- \`${file}\`"
  done
} > "${OUT_FILE}"

echo "Catalog created: ${OUT_FILE}"


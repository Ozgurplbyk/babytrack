#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/.tools"
XCODEGEN_DIR="${TOOLS_DIR}/xcodegen"
XCODEGEN_BIN="${XCODEGEN_DIR}/bin/xcodegen"

if command -v xcodegen >/dev/null 2>&1; then
  command -v xcodegen
  exit 0
fi

if [[ -x "${XCODEGEN_BIN}" ]]; then
  echo "${XCODEGEN_BIN}"
  exit 0
fi

mkdir -p "${TOOLS_DIR}"
ZIP_PATH="${TOOLS_DIR}/xcodegen.zip"
TMP_EXTRACT="${TOOLS_DIR}/xcodegen_extract"

rm -rf "${TMP_EXTRACT}" "${XCODEGEN_DIR}"

python3 - <<'PY' "${ZIP_PATH}"
import json
import pathlib
import urllib.request
import sys

zip_path = pathlib.Path(sys.argv[1])
release_url = "https://api.github.com/repos/yonaskolb/XcodeGen/releases/latest"
with urllib.request.urlopen(release_url, timeout=30) as response:
    release = json.load(response)

download_url = ""
for asset in release.get("assets", []):
    if asset.get("name") == "xcodegen.zip":
        download_url = str(asset.get("browser_download_url", "")).strip()
        break

if not download_url:
    raise SystemExit("xcodegen.zip asset not found in latest release")

with urllib.request.urlopen(download_url, timeout=60) as response:
    zip_path.write_bytes(response.read())
PY

unzip -q "${ZIP_PATH}" -d "${TMP_EXTRACT}"
mv "${TMP_EXTRACT}/xcodegen" "${XCODEGEN_DIR}"
chmod +x "${XCODEGEN_BIN}"

echo "${XCODEGEN_BIN}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
BASE_FILE="${ROOT_DIR}/config/localization/base_strings_en.json"
OUT_DIR="${ROOT_DIR}/app/ios/BabyTrack/Resources/Localization"
INFO_APP_BASE="${ROOT_DIR}/config/localization/base_infoplist_app_en.json"
INFO_WIDGET_BASE="${ROOT_DIR}/config/localization/base_infoplist_widget_en.json"
INFO_WATCH_BASE="${ROOT_DIR}/config/localization/base_infoplist_watch_en.json"
WIDGET_OUT_DIR="${ROOT_DIR}/app/ios/BabyTrackWidget"
WATCH_OUT_DIR="${ROOT_DIR}/app/ios/BabyTrackWatch"
REGISTRY_FILE="${ROOT_DIR}/config/localization/app_display_name_registry_v1.json"

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "ERROR: GEMINI_API_KEY is not set."
  exit 2
fi

mapfile -t LOCALES < <(python3 - "${REGISTRY_FILE}" <<'PY'
import json
import sys
from pathlib import Path

registry_path = Path(sys.argv[1])
payload = json.loads(registry_path.read_text(encoding="utf-8"))
entries = payload.get("entries", [])
seen = set()
for entry in entries:
    locale = str(entry.get("locale", "")).strip()
    if locale and locale not in seen:
        print(locale)
        seen.add(locale)
PY
)

if [[ "${#LOCALES[@]}" -eq 0 ]]; then
  echo "ERROR: No locales found in ${REGISTRY_FILE}"
  exit 2
fi

echo "[Localization] Generating Localizable.strings for: ${LOCALES[*]}"
python3 "${ROOT_DIR}/tools/localization/translate_localization_with_gemini.py" \
  --base "${BASE_FILE}" \
  --out "${OUT_DIR}" \
  --locales "${LOCALES[@]}"

echo "[Localization] Generating Localizable.strings (Widget)"
python3 "${ROOT_DIR}/tools/localization/translate_localization_with_gemini.py" \
  --base "${BASE_FILE}" \
  --out "${WIDGET_OUT_DIR}" \
  --locales "${LOCALES[@]}"

echo "[Localization] Generating Localizable.strings (Watch)"
python3 "${ROOT_DIR}/tools/localization/translate_localization_with_gemini.py" \
  --base "${BASE_FILE}" \
  --out "${WATCH_OUT_DIR}" \
  --locales "${LOCALES[@]}"

echo "[Localization] Generating InfoPlist.strings (App)"
python3 "${ROOT_DIR}/tools/localization/translate_localization_with_gemini.py" \
  --base "${INFO_APP_BASE}" \
  --out "${OUT_DIR}" \
  --locales "${LOCALES[@]}" \
  --strings-file "InfoPlist.strings"

echo "[Localization] Generating InfoPlist.strings (Widget)"
python3 "${ROOT_DIR}/tools/localization/translate_localization_with_gemini.py" \
  --base "${INFO_WIDGET_BASE}" \
  --out "${WIDGET_OUT_DIR}" \
  --locales "${LOCALES[@]}" \
  --strings-file "InfoPlist.strings"

echo "[Localization] Generating InfoPlist.strings (Watch)"
python3 "${ROOT_DIR}/tools/localization/translate_localization_with_gemini.py" \
  --base "${INFO_WATCH_BASE}" \
  --out "${WATCH_OUT_DIR}" \
  --locales "${LOCALES[@]}" \
  --strings-file "InfoPlist.strings"

echo "[Localization] Syncing app icon display names from registry"
python3 "${ROOT_DIR}/tools/localization/sync_app_display_names.py" \
  --registry "${REGISTRY_FILE}" \
  --localization-root "app/ios/BabyTrack/Resources/Localization" \
  --doc-out "docs/APP_NAME_LOCALIZATION_POLICY_AUTO_TR.md"

echo "[Localization] Completed. Output: ${OUT_DIR}"

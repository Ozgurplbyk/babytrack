#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "ERROR: GEMINI_API_KEY is not set"
  exit 2
fi

echo "[1/8] Generate visual assets"
"${ROOT_DIR}/scripts/run_phase_1.sh"

echo "[2/8] Catalog generated visuals"
"${ROOT_DIR}/scripts/catalog_generated_assets.sh"

echo "[3/8] Generate app localizations"
"${ROOT_DIR}/scripts/run_localization.sh"

echo "[4/8] Generate audio library"
python3 "${ROOT_DIR}/tools/audio/generate_audio_library.py" \
  --catalog "${ROOT_DIR}/content/lullabies/lullaby_catalog.json" \
  --out "${ROOT_DIR}/app/ios/BabyTrack/Resources/Audio" \
  --noise-duration 90 \
  --lullaby-duration 24

echo "[5/8] Build vaccine update packages"
python3 "${ROOT_DIR}/backend/vaccine_pipeline/run_update_cycle.py"

echo "[6/8] Validate vaccine country source registry linkage"
python3 "${ROOT_DIR}/tools/content/validate_vaccine_source_registry.py" \
  --registry "${ROOT_DIR}/content/medical/vaccine_country_source_registry_v1.json" \
  --output-dir "${ROOT_DIR}/backend/vaccine_pipeline/output"

echo "[7/8] Validate locale to vaccine coverage"
python3 "${ROOT_DIR}/tools/content/validate_locale_vaccine_requirements.py" \
  --locale-registry "${ROOT_DIR}/config/localization/app_display_name_registry_v1.json" \
  --vaccine-registry "${ROOT_DIR}/content/medical/vaccine_country_source_registry_v1.json" \
  --output-dir "${ROOT_DIR}/backend/vaccine_pipeline/output"

echo "[8/8] Sync generated visuals into iOS resources"
mkdir -p "${ROOT_DIR}/app/ios/BabyTrack/Resources/Generated"
rsync -a "${ROOT_DIR}/generated/assets/" "${ROOT_DIR}/app/ios/BabyTrack/Resources/Generated/"

echo "Done."

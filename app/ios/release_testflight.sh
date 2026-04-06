#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT="BabyTrack.xcodeproj"
SCHEME="BabyTrack"
CONFIGURATION="Release"
ARCHIVE_PATH="$SCRIPT_DIR/build/BabyTrack.xcarchive"
EXPORT_PATH="$SCRIPT_DIR/build/export"
EXPORT_OPTIONS_PLIST=""
TEAM_ID=""
GENERATE_PROJECT=1
CLEAN_BUILD=0
SKIP_UPLOAD=0
SHOW_HELP=0

usage() {
  cat <<'EOF'
Usage: ./release_testflight.sh [options]

Options:
  --project <path>               Xcode project path (default: BabyTrack.xcodeproj)
  --scheme <name>                Xcode scheme (default: BabyTrack)
  --configuration <name>         Build configuration (default: Release)
  --archive-path <path>          Archive output path
  --export-path <path>           IPA export directory
  --export-options-plist <path>  Use custom export options plist
  --team-id <id>                 Apple Developer Team ID (required if no custom plist)
  --no-generate-project          Skip ./generate_xcodeproj.sh
  --clean                        Remove previous archive/export outputs
  --skip-upload                  Archive + export only, do not upload
  --help, -h                     Show this help

Environment variables for upload:
  ASC_API_KEY_ID       App Store Connect API key id (required unless --skip-upload)
  ASC_API_ISSUER_ID    App Store Connect issuer id (required unless --skip-upload)
  ASC_P8_FILE_PATH     Optional p8 key path (if omitted, altool key search paths are used)
  ASC_API_KEY_SUBJECT  Optional, set to 'user' for individual API keys when needed
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --archive-path)
      ARCHIVE_PATH="$2"
      shift 2
      ;;
    --export-path)
      EXPORT_PATH="$2"
      shift 2
      ;;
    --export-options-plist)
      EXPORT_OPTIONS_PLIST="$2"
      shift 2
      ;;
    --team-id)
      TEAM_ID="$2"
      shift 2
      ;;
    --no-generate-project)
      GENERATE_PROJECT=0
      shift
      ;;
    --clean)
      CLEAN_BUILD=1
      shift
      ;;
    --skip-upload)
      SKIP_UPLOAD=1
      shift
      ;;
    --help|-h)
      SHOW_HELP=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      SHOW_HELP=1
      shift
      ;;
  esac
done

if [[ "$SHOW_HELP" -eq 1 ]]; then
  usage
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode command line tools first." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found. Install Xcode command line tools first." >&2
  exit 1
fi

if [[ "$GENERATE_PROJECT" -eq 1 ]]; then
  if ./ensure_xcodegen.sh >/dev/null 2>&1; then
    ./generate_xcodeproj.sh
  elif [[ -d "$PROJECT" ]]; then
    echo "xcodegen not found. Continuing with existing project: $PROJECT"
  else
    echo "xcodegen not found and $PROJECT is missing." >&2
    echo "Install xcodegen or run with --project pointing to an existing .xcodeproj." >&2
    exit 1
  fi
fi

if [[ "$CLEAN_BUILD" -eq 1 ]]; then
  rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

if [[ -z "$EXPORT_OPTIONS_PLIST" ]]; then
  if [[ -z "$TEAM_ID" ]]; then
    echo "--team-id is required when --export-options-plist is not provided." >&2
    exit 1
  fi
  EXPORT_OPTIONS_PLIST="$SCRIPT_DIR/build/ExportOptions.AppStoreConnect.plist"
  cat > "$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>export</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${TEAM_ID}</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF
fi

if [[ ! -f "$EXPORT_OPTIONS_PLIST" ]]; then
  echo "Export options plist not found: $EXPORT_OPTIONS_PLIST" >&2
  exit 1
fi

XCODE_AUTH_ARGS=()
if [[ -n "${ASC_P8_FILE_PATH:-}" && -n "${ASC_API_KEY_ID:-}" && -n "${ASC_API_ISSUER_ID:-}" ]]; then
  XCODE_AUTH_ARGS+=(
    -authenticationKeyPath "$ASC_P8_FILE_PATH"
    -authenticationKeyID "$ASC_API_KEY_ID"
    -authenticationKeyIssuerID "$ASC_API_ISSUER_ID"
  )
fi

ARCHIVE_CMD=(
  xcodebuild
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
  -allowProvisioningUpdates
  archive
)
if [[ -n "$TEAM_ID" ]]; then
  ARCHIVE_CMD+=("DEVELOPMENT_TEAM=$TEAM_ID")
fi
ARCHIVE_CMD+=("${XCODE_AUTH_ARGS[@]}")

echo "==> Archiving ($SCHEME / $CONFIGURATION)"
"${ARCHIVE_CMD[@]}"

EXPORT_CMD=(
  xcodebuild
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
  -allowProvisioningUpdates
)
EXPORT_CMD+=("${XCODE_AUTH_ARGS[@]}")

echo "==> Exporting IPA"
"${EXPORT_CMD[@]}"

IPA_FILE="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name '*.ipa' | head -n 1 || true)"
if [[ -z "$IPA_FILE" ]]; then
  echo "IPA was not generated under: $EXPORT_PATH" >&2
  exit 1
fi

echo "IPA: $IPA_FILE"

if [[ "$SKIP_UPLOAD" -eq 1 ]]; then
  echo "Upload skipped (--skip-upload)."
  exit 0
fi

if [[ -z "${ASC_API_KEY_ID:-}" || -z "${ASC_API_ISSUER_ID:-}" ]]; then
  echo "ASC_API_KEY_ID and ASC_API_ISSUER_ID are required for upload." >&2
  exit 1
fi

UPLOAD_CMD=(
  xcrun altool
  --upload-app
  -f "$IPA_FILE"
  --api-key "$ASC_API_KEY_ID"
  --api-issuer "$ASC_API_ISSUER_ID"
  --show-progress
  --output-format normal
)

if [[ -n "${ASC_P8_FILE_PATH:-}" ]]; then
  UPLOAD_CMD+=(--p8-file-path "$ASC_P8_FILE_PATH")
fi

if [[ -n "${ASC_API_KEY_SUBJECT:-}" ]]; then
  UPLOAD_CMD+=(--api-key-subject "$ASC_API_KEY_SUBJECT")
fi

echo "==> Uploading IPA to TestFlight"
"${UPLOAD_CMD[@]}"

echo "TestFlight upload request submitted."

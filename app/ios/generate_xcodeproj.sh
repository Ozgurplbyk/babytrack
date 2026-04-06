#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
XCODEGEN_BIN="$(./ensure_xcodegen.sh)"
"${XCODEGEN_BIN}" generate

echo "Generated BabyTrack.xcodeproj"

#!/usr/bin/env bash
set -euo pipefail

SHOW_HELP=0
OPEN_PROJECT=1
BUILD_SMOKE=0

for arg in "$@"; do
  case "$arg" in
    --help|-h)
      SHOW_HELP=1
      ;;
    --no-open)
      OPEN_PROJECT=0
      ;;
    --build-smoke)
      BUILD_SMOKE=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      SHOW_HELP=1
      ;;
  esac
done

if [[ "$SHOW_HELP" -eq 1 ]]; then
  cat <<'EOF'
Usage: ./bootstrap_xcode.sh [--no-open] [--build-smoke]

Options:
  --no-open      Generate .xcodeproj but do not open Xcode
  --build-smoke  Run no-codesign xcodebuild smoke build after generation
  --help, -h     Show this help
EOF
  exit 0
fi

cd "$(dirname "$0")"
./generate_xcodeproj.sh

if [[ "$BUILD_SMOKE" -eq 1 ]]; then
  xcodebuild \
    -project BabyTrack.xcodeproj \
    -scheme BabyTrack \
    -destination 'generic/platform=iOS' \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    build
fi

if [[ "$OPEN_PROJECT" -eq 1 ]]; then
  open BabyTrack.xcodeproj
fi

echo "Xcode bootstrap complete."

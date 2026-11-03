#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <build-name> <build-number> [dart-define-file]"
  echo "Example: $0 1.0.0 2"
  echo "Example: $0 1.0.0 2 .env.prod.json"
  exit 64
fi

BUILD_NAME="$1"
BUILD_NUMBER="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFINE_FILE="${3:-$MOBILE_DIR/.env.prod.json}"
EXPORT_OPTIONS="$MOBILE_DIR/ios/ExportOptions.plist"

if [[ ! -f "$DEFINE_FILE" ]]; then
  echo "Dart define file not found: $DEFINE_FILE"
  exit 66
fi

cd "$MOBILE_DIR"

# Xcode's IPA packaging expects the macOS rsync implementation for its -E option.
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH" flutter build ipa --release \
  --build-name="$BUILD_NAME" \
  --build-number="$BUILD_NUMBER" \
  --dart-define-from-file="$DEFINE_FILE" \
  --export-options-plist="$EXPORT_OPTIONS"

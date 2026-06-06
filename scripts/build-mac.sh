#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_PATH="${WORKSPACE_PATH:-}"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/FinanceCategorizer.xcodeproj}"
SCHEME="${MAC_SCHEME:-FinanceCategorizerMac}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.derived-data.nosync}"

cd "$ROOT_DIR"

if [[ -n "$WORKSPACE_PATH" ]]; then
  BUILD_TARGET=( -workspace "$WORKSPACE_PATH" )
elif [[ -d "$PROJECT_PATH" ]]; then
  BUILD_TARGET=( -project "$PROJECT_PATH" )
else
  echo "error: no .xcworkspace or .xcodeproj found. Run scripts/xcodegen-generate.sh first or set WORKSPACE_PATH/PROJECT_PATH." >&2
  exit 1
fi

echo "==> Building macOS scheme: $SCHEME"

xcodebuild \
  "${BUILD_TARGET[@]}" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

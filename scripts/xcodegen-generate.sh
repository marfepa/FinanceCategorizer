#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="${PROJECT_FILE:-$ROOT_DIR/project.yml}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is not installed. Install it first, for example with Homebrew." >&2
  exit 1
fi

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "error: project.yml not found at $PROJECT_FILE" >&2
  exit 1
fi

cd "$ROOT_DIR"
echo "==> Generating Xcode project from $(basename "$PROJECT_FILE")"
xcodegen generate --spec "$PROJECT_FILE"
echo "==> Done"

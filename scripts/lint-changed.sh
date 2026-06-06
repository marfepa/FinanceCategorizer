#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_REF="${BASE_REF:-HEAD}"

cd "$ROOT_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: this script must run inside a git repository." >&2
  exit 1
fi

mapfile -t SWIFT_FILES < <(git diff --name-only --diff-filter=ACMRTUXB "$BASE_REF" -- '*.swift')

if [[ ${#SWIFT_FILES[@]} -eq 0 ]]; then
  echo "==> No changed Swift files against $BASE_REF"
  exit 0
fi

echo "==> Changed Swift files:"
printf ' - %s\n' "${SWIFT_FILES[@]}"

echo
echo "==> Trailing whitespace check"

FAILED=0
for file in "${SWIFT_FILES[@]}"; do
  if grep -nE '[[:blank:]]+$' "$file" >/dev/null 2>&1; then
    echo "trailing whitespace: $file"
    FAILED=1
  fi
done

if command -v swiftlint >/dev/null 2>&1; then
  echo
  echo "==> Running SwiftLint on changed files"
  swiftlint lint --strict "${SWIFT_FILES[@]}" || FAILED=1
else
  echo
  echo "==> SwiftLint not installed; skipping SwiftLint"
fi

if command -v swift-format >/dev/null 2>&1; then
  echo
  echo "==> Running swift-format lint on changed files"
  swift-format lint "${SWIFT_FILES[@]}" || FAILED=1
else
  echo
  echo "==> swift-format not installed; skipping swift-format lint"
fi

if [[ $FAILED -ne 0 ]]; then
  echo
  echo "lint-changed: failures detected" >&2
  exit 1
fi

echo
echo "lint-changed: OK"

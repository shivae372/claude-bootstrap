#!/usr/bin/env bash
# PostToolUse hook (Write|Edit|MultiEdit): format.sh
# Formats the file Claude just wrote, using whatever formatter the project already
# has. Never installs anything, never fails the tool call (always exits 0).
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

FILEPATH=""
if command -v python3 >/dev/null 2>&1; then
  FILEPATH="$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    inp = json.load(sys.stdin).get("tool_input", {}) or {}
    print(inp.get("file_path", "") or "")
except Exception:
    print("")' 2>/dev/null || true)"
fi
# MultiEdit and Edit both carry top-level file_path, so one path covers all writers.
[ -z "$FILEPATH" ] && exit 0
[ -f "$FILEPATH" ] || exit 0

EXT="${FILEPATH##*.}"
case "$EXT" in
  js|jsx|ts|tsx|mjs|cjs|css|scss|sass|json|md|mdx|yaml|yml)
    if [ -x "node_modules/.bin/prettier" ]; then
      node_modules/.bin/prettier --write "$FILEPATH" --log-level silent 2>/dev/null && echo "✨ prettier → $FILEPATH"
    elif command -v prettier >/dev/null 2>&1; then
      prettier --write "$FILEPATH" --log-level silent 2>/dev/null && echo "✨ prettier → $FILEPATH"
    elif [ -x "node_modules/.bin/eslint" ] && [[ "$EXT" =~ ^(js|jsx|ts|tsx|mjs|cjs)$ ]]; then
      node_modules/.bin/eslint --fix "$FILEPATH" 2>/dev/null && echo "✨ eslint --fix → $FILEPATH"
    fi ;;
  py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$FILEPATH" 2>/dev/null; ruff check --fix "$FILEPATH" 2>/dev/null; echo "✨ ruff → $FILEPATH"
    elif command -v black >/dev/null 2>&1; then
      black -q "$FILEPATH" 2>/dev/null && echo "✨ black → $FILEPATH"
    fi ;;
  go)  command -v gofmt   >/dev/null 2>&1 && { gofmt -w "$FILEPATH" 2>/dev/null && echo "✨ gofmt → $FILEPATH"; } ;;
  rs)  command -v rustfmt >/dev/null 2>&1 && { rustfmt "$FILEPATH" 2>/dev/null && echo "✨ rustfmt → $FILEPATH"; } ;;
  rb)  command -v rubocop >/dev/null 2>&1 && { rubocop -a "$FILEPATH" 2>/dev/null && echo "✨ rubocop → $FILEPATH"; } ;;
  sh|bash) command -v shfmt >/dev/null 2>&1 && { shfmt -w "$FILEPATH" 2>/dev/null && echo "✨ shfmt → $FILEPATH"; } ;;
esac

exit 0

#!/usr/bin/env bash
# format.sh — manual, project-wide code formatter (run by you, not by a hook).
# Usage:
#   bash scripts/format.sh            # format all supported files in the repo
#   bash scripts/format.sh <file>     # format a single file
# Uses whatever formatters are installed; silently skips the rest. Never aborts mid-run.
set -uo pipefail

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else GREEN=''; YELLOW=''; BOLD=''; NC=''; fi

FORMATTED=0; SKIPPED=0

format_file() {
  local FILE="$1" EXT="${1##*.}"
  case "$EXT" in
    js|jsx|ts|tsx|mjs|cjs|json|css|scss|sass|md|mdx|yaml|yml)
      if [ -x node_modules/.bin/prettier ]; then node_modules/.bin/prettier --write "$FILE" --log-level silent 2>/dev/null && FORMATTED=$((FORMATTED+1)) || SKIPPED=$((SKIPPED+1))
      elif command -v prettier >/dev/null 2>&1; then prettier --write "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)) || SKIPPED=$((SKIPPED+1))
      else SKIPPED=$((SKIPPED+1)); fi ;;
    py)
      if command -v ruff >/dev/null 2>&1; then ruff format "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)) || SKIPPED=$((SKIPPED+1))
      elif command -v black >/dev/null 2>&1; then black -q "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)) || SKIPPED=$((SKIPPED+1))
      else SKIPPED=$((SKIPPED+1)); fi ;;
    go) command -v gofmt >/dev/null 2>&1 && { gofmt -w "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)); } || SKIPPED=$((SKIPPED+1)) ;;
    rs) command -v rustfmt >/dev/null 2>&1 && { rustfmt "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)); } || SKIPPED=$((SKIPPED+1)) ;;
    rb) command -v rubocop >/dev/null 2>&1 && { rubocop -a "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)); } || SKIPPED=$((SKIPPED+1)) ;;
    sh|bash) command -v shfmt >/dev/null 2>&1 && { shfmt -w "$FILE" 2>/dev/null && FORMATTED=$((FORMATTED+1)); } || SKIPPED=$((SKIPPED+1)) ;;
    *) : ;;
  esac
}

printf '\n%sFormatting…%s\n' "$BOLD" "$NC"
if [ -n "${1:-}" ]; then
  [ -f "$1" ] || { echo "File not found: $1"; exit 1; }
  format_file "$1"; printf '  %s✓%s %s\n' "$GREEN" "$NC" "$1"
else
  while IFS= read -r -d '' file; do format_file "$file"; done < <(find . \
    -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./vendor/*" \
    -not -path "./target/*" -not -path "./.next/*" -not -path "./dist/*" -not -path "./build/*" \
    -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \
      -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.rb" \
      -o -name "*.sh" -o -name "*.json" -o -name "*.css" -o -name "*.scss" \
      -o -name "*.md" -o -name "*.yaml" -o -name "*.yml" \) -print0)
fi

printf '  %s✓%s formatted %d' "$GREEN" "$NC" "$FORMATTED"
[ "$SKIPPED" -gt 0 ] && printf '   %s⚠%s skipped %d (no formatter installed)' "$YELLOW" "$NC" "$SKIPPED"
printf '\n\n'

#!/usr/bin/env bash
# PreToolUse hook (Bash): safety-check.sh
# Blocks unambiguously destructive shell commands before they run. Reasons are
# printed to STDERR (which Claude Code surfaces to the model on a blocking exit 2);
# warnings allow the command but flag it.
#
# Bypass once:  CLAUDE_BOOTSTRAP_ALLOW_DANGEROUS=1
set -uo pipefail

if [ "${CLAUDE_BOOTSTRAP_ALLOW_DANGEROUS:-0}" = "1" ]; then exit 0; fi

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

# Pull the command string (python preferred; grep fallback for resilience).
COMMAND=""
if command -v python3 >/dev/null 2>&1; then
  COMMAND="$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))
except Exception:
    print("")' 2>/dev/null || true)"
fi
[ -z "$COMMAND" ] && COMMAND="$INPUT"
[ -z "$COMMAND" ] && exit 0

# ─── Hard blocks (destructive, no legitimate agent use) ─────────────────────────
# Extended-regex patterns; matched case-insensitively against the command.
BLOCKED=(
  'rm[[:space:]]+-[a-z]*r[a-z]*f?[[:space:]]+(/|~|\$HOME|/\*|\.\.)([[:space:]]|$)'
  'rm[[:space:]]+-[a-z]*f[a-z]*r?[[:space:]]+(/|~|\$HOME)([[:space:]]|$)'
  ':\(\)\{[[:space:]]*:\|:&[[:space:]]*\};:'      # fork bomb
  'git[[:space:]]+push[[:space:]]+.*(--force|-f)([[:space:]]|$)'
  'mkfs\.'
  'dd[[:space:]]+if=/dev/(zero|random|urandom)[[:space:]]+of=/dev/[sh]d'
  '>[[:space:]]*/dev/[sh]da'
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'
  'chown[[:space:]]+-R[[:space:]]+[^[:space:]]+[[:space:]]+/([[:space:]]|$)'
  '(DROP|TRUNCATE)[[:space:]]+(TABLE|DATABASE|SCHEMA)'
  'DELETE[[:space:]]+FROM[[:space:]]+[^;]+[[:space:]]+WHERE[[:space:]]+.*(1=1|true)'
  'format[[:space:]]+[a-z]:'
  'curl[[:space:]]+.*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)([[:space:]]|$)'
  'wget[[:space:]]+.*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)([[:space:]]|$)'
)
for pat in "${BLOCKED[@]}"; do
  if printf '%s' "$COMMAND" | grep -qiE "$pat"; then
    {
      echo "🚫 BLOCKED by safety-check: this command is destructive and was stopped."
      echo "   Command: $COMMAND"
      echo "   If you truly intend this, run it yourself in a terminal, or set"
      echo "   CLAUDE_BOOTSTRAP_ALLOW_DANGEROUS=1 for a single deliberate run."
    } >&2
    exit 2
  fi
done

# ─── Warnings (allowed, but surfaced) ───────────────────────────────────────────
WARN=(
  'git[[:space:]]+push[[:space:]]+--force-with-lease'
  'git[[:space:]]+reset[[:space:]]+--hard'
  'git[[:space:]]+clean[[:space:]]+-[a-z]*f'
  'rm[[:space:]]+-rf[[:space:]]+(node_modules|\.next|dist|build|target|venv)'
  '(npm|pnpm|yarn|bun)[[:space:]]+install'
  'pip[[:space:]]+install'
)
for pat in "${WARN[@]}"; do
  if printf '%s' "$COMMAND" | grep -qiE "$pat"; then
    echo "⚠️  safety-check: '$COMMAND' is allowed but worth a second look — verify it is intentional." >&2
    exit 0
  fi
done

exit 0

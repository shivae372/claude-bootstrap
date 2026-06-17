#!/usr/bin/env bash
# SessionStart hook: resume + load the project's accumulated power.
# Injects three things as additionalContext (nodo hookinstall pattern):
#   1. SESSION_STATE.md     — what you were doing (working memory)
#   2. capability manifest  — the skills/commands/agents/hooks installed here
#   3. learnings            — durable facts the setup learned across sessions
# Always emits valid JSON; degrades gracefully; never blocks.
set -uo pipefail
cat >/dev/null 2>&1 || true   # drain stdin

ENGINE=".claude/engine"
[ -f "$ENGINE/doctor.py" ] || ENGINE="engine"
[ -f "$ENGINE/doctor.py" ] || ENGINE="${CLAUDE_PLUGIN_ROOT:-/nonexistent}/engine"
PARTS=""

# 1. Session state
if [ -f SESSION_STATE.md ]; then
  PARTS+="## Resuming this project"$'\n'"$(head -c 5000 SESSION_STATE.md 2>/dev/null)"$'\n\n'
fi
# 2. Capability manifest
if command -v python3 >/dev/null 2>&1 && [ -f "$ENGINE/doctor.py" ]; then
  MAN="$(python3 "$ENGINE/doctor.py" --manifest 2>/dev/null || true)"
  [ -n "$MAN" ] && PARTS+="## Installed capabilities"$'\n'"$MAN"$'\n\n'
fi
# 3. Learnings
if command -v python3 >/dev/null 2>&1 && [ -f "$ENGINE/learn.py" ]; then
  LRN="$(python3 "$ENGINE/learn.py" inject 2>/dev/null | python3 -c 'import sys,json;
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass' 2>/dev/null || true)"
  [ -n "$LRN" ] && PARTS+="$LRN"$'\n'
fi

[ -z "$PARTS" ] && exit 0

if command -v python3 >/dev/null 2>&1; then
  CTX="$PARTS" python3 -c '
import json, os
print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
      "additionalContext": os.environ.get("CTX","")}}))'
else
  printf '%s\n' "$PARTS"
fi
exit 0

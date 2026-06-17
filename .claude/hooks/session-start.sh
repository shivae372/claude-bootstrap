#!/usr/bin/env bash
# SessionStart hook: session-start.sh
# Makes "resume where you left off" real. At the start of a session (startup,
# resume, or after /clear), this surfaces SESSION_STATE.md back to Claude as
# additional context, so it doesn't need the project re-explained.
#
# Contract: receives JSON on stdin: {"hook_event_name":"SessionStart","source":"startup|resume|clear", …}
# To inject context, print JSON with hookSpecificOutput.additionalContext (exit 0).
set -uo pipefail

cat >/dev/null 2>&1 || true   # drain stdin; we don't need the payload fields here

STATE="SESSION_STATE.md"
[ -f "$STATE" ] || exit 0

# Cap how much we inject so we never blow the budget on a huge state file.
CONTEXT="$(head -c 6000 "$STATE" 2>/dev/null || true)"
[ -z "$CONTEXT" ] && exit 0

if command -v python3 >/dev/null 2>&1; then
  CTX="$CONTEXT" python3 -c '
import json, os
ctx = os.environ.get("CTX", "")
note = ("Resuming this project. Current working state from SESSION_STATE.md is below — "
        "use it instead of re-exploring, and keep it updated as you work.\n\n") + ctx
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": note
    }
}))'
else
  # Fallback: plain text on stdout is still shown to the user at session start.
  echo "📋 Resuming — see SESSION_STATE.md for current task and recent decisions."
fi
exit 0

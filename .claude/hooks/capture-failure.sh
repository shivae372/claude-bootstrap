#!/usr/bin/env bash
# PostToolUse hook: record tool failures so the setup can suggest self-healing.
# PostToolUse can't inject context, so we LOG failures to a queue that the
# UserPromptSubmit hook reads next turn (the documented chaining pattern).
# Never blocks, always exit 0.
set -uo pipefail
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$INPUT" <<'PY' 2>/dev/null || true
import json, os, sys, time
try:
    d = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
resp = d.get("tool_response", d.get("tool_result", {}))
err = False
if isinstance(resp, dict):
    err = bool(resp.get("error") or resp.get("is_error"))
elif isinstance(resp, str):
    err = any(s in resp.lower() for s in ("traceback (most recent call last)", "command not found", "error:"))
# Also honor an explicit success flag if present.
if d.get("success") is False:
    err = True
if not err:
    sys.exit(0)
root = d.get("cwd") or os.getcwd()
p = os.path.join(root, ".claude", "state", "failures.jsonl")
os.makedirs(os.path.dirname(p), exist_ok=True)
rec = {"t": int(time.time()), "tool": d.get("tool_name", "")}
# keep the queue bounded
lines = []
if os.path.exists(p):
    lines = open(p, encoding="utf-8", errors="ignore").read().splitlines()[-200:]
lines.append(json.dumps(rec))
open(p, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
exit 0

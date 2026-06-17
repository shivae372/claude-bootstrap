#!/usr/bin/env bash
# UserPromptSubmit hook: real-time augmentation trigger.
# Notices when the user wants a capability this setup lacks and nudges Claude to
# run `augment` then and there. Pure delegation to the engine; never blocks.
set -uo pipefail
GAP=""
for d in .claude/engine engine "${CLAUDE_PLUGIN_ROOT:-/nonexistent}/engine"; do
  [ -f "$d/gap_detect.py" ] && { GAP="$d/gap_detect.py"; break; }
done
if [ -n "$GAP" ] && command -v python3 >/dev/null 2>&1; then
  python3 "$GAP" 2>/dev/null || true
else
  cat >/dev/null 2>&1 || true   # drain stdin, do nothing
fi
exit 0

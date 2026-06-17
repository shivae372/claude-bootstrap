#!/usr/bin/env bash
# PreCompact hook: checkpoint.sh
# Fires right before Claude Code compacts the conversation. Saves a timestamped
# checkpoint to SESSION_STATE.md so context survives compaction, and warns if
# CLAUDE.md has grown past the point where instruction-following degrades.
#
# Contract: receives JSON on stdin, e.g.
#   {"session_id":"…","transcript_path":"…","hook_event_name":"PreCompact",
#    "trigger":"manual|auto","custom_instructions":"…"}
# NOTE: PreCompact payloads do NOT contain tool_name/tool_input — never gate on them.
# Anything printed to stdout is shown to the user; exit 0 always (never block compaction).
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"

# Extract the trigger ("auto" or "manual"); tolerate missing python / malformed JSON.
TRIGGER="auto"
if command -v python3 >/dev/null 2>&1 && [ -n "$INPUT" ]; then
  TRIGGER="$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("trigger", "auto"))
except Exception:
    print("auto")' 2>/dev/null || echo auto)"
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATE="SESSION_STATE.md"

# Create SESSION_STATE.md on first compaction if the project doesn't have one yet.
if [ ! -f "$STATE" ]; then
  {
    printf '# Session State\n## Last updated: %s\n\n' "$TIMESTAMP"
    printf '## Current Task\n_Resumed after compaction. Fill in what you are working on._\n\n'
    printf '## Completed This Session\n\n## Pending / Blocked\n\n## Key Decisions\n\n## Files Modified\n'
  } > "$STATE" 2>/dev/null || true
fi

if [ -f "$STATE" ]; then
  # Refresh the "Last updated" line (GNU and BSD sed compatible).
  if sed --version >/dev/null 2>&1; then
    sed -i "s/^## Last updated:.*/## Last updated: $TIMESTAMP/" "$STATE" 2>/dev/null || true
  else
    sed -i '' "s/^## Last updated:.*/## Last updated: $TIMESTAMP/" "$STATE" 2>/dev/null || true
  fi
  # Append a compaction breadcrumb under a dedicated section.
  if ! grep -q '^## Compaction Checkpoints' "$STATE" 2>/dev/null; then
    printf '\n## Compaction Checkpoints\n' >> "$STATE"
  fi
  printf -- '- %s — context compacted (trigger: %s)\n' "$TIMESTAMP" "$TRIGGER" >> "$STATE"
  echo "💾 checkpoint: SESSION_STATE.md updated before compaction ($TRIGGER)."
fi

# CLAUDE.md drift warning — a long CLAUDE.md quietly erodes instruction-following.
if [ -f "CLAUDE.md" ]; then
  LINES="$(wc -l < CLAUDE.md 2>/dev/null | tr -d ' ')"
  if [ -n "$LINES" ] && [ "$LINES" -gt 150 ] 2>/dev/null; then
    echo "⚠️  CLAUDE.md is $LINES lines (>150). Trim it — attention degrades past this point."
  fi
fi

exit 0

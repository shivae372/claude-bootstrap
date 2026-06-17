#!/usr/bin/env bash
# Notification hook: notify.sh
# Sends a desktop notification when Claude Code needs your attention. Uses the
# message from the hook payload when present; degrades gracefully everywhere.
set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
TITLE="Claude Code"
MESSAGE="Claude Code needs your input"
if [ -n "$INPUT" ] && command -v python3 >/dev/null 2>&1; then
  MESSAGE="$(printf '%s' "$INPUT" | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("message", "Claude Code needs your input"))
except Exception:
    print("Claude Code needs your input")' 2>/dev/null || echo "Claude Code needs your input")"
fi

if command -v osascript >/dev/null 2>&1; then            # macOS
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null || true
elif command -v notify-send >/dev/null 2>&1; then         # Linux desktop
  notify-send "$TITLE" "$MESSAGE" --urgency=normal 2>/dev/null || true
elif command -v powershell.exe >/dev/null 2>&1; then      # WSL → Windows toast
  powershell.exe -NoProfile -Command "
    Add-Type -AssemblyName System.Windows.Forms
    \$n = New-Object System.Windows.Forms.NotifyIcon
    \$n.Icon = [System.Drawing.SystemIcons]::Information
    \$n.Visible = \$true
    \$n.ShowBalloonTip(3000, '$TITLE', '$MESSAGE', [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 3; \$n.Dispose()" 2>/dev/null || true
else
  printf '\a'                                             # terminal bell fallback
fi
exit 0

#!/usr/bin/env bash
# validate.sh — verify a Claude Code setup is correct and complete.
# Run from your project root:  bash scripts/validate.sh [--quiet] [--json]
# Exit 0 if no errors (warnings allowed), 1 if any errors.
set -uo pipefail

QUIET=0; JSON=0
for a in "$@"; do
  case "$a" in
    --quiet|-q) QUIET=1 ;;
    --json) JSON=1; QUIET=1 ;;
    -h|--help) echo "usage: validate.sh [--quiet] [--json]"; exit 0 ;;
  esac
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "$JSON" -eq 0 ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''; fi

ERRORS=0; WARNINGS=0; PASS=0
declare -a ISSUES=()
pass() { PASS=$((PASS+1)); [ "$QUIET" -eq 1 ] || printf '  %s✓%s %s\n' "$GREEN" "$NC" "$1"; }
warn() { WARNINGS=$((WARNINGS+1)); ISSUES+=("warn: $1"); [ "$QUIET" -eq 1 ] || printf '  %s⚠%s %s\n' "$YELLOW" "$NC" "$1"; }
fail() { ERRORS=$((ERRORS+1)); ISSUES+=("error: $1"); [ "$QUIET" -eq 1 ] || printf '  %s✗%s %s\n' "$RED" "$NC" "$1"; }
hdr()  { [ "$QUIET" -eq 1 ] || printf '\n%s%s%s\n' "$BOLD" "$1" "$NC"; }

is_int() { case "${1:-}" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

[ "$QUIET" -eq 1 ] || printf '\n%sValidating Claude Code setup…%s\n' "$BOLD" "$NC"

# ─── CLAUDE.md ───────────────────────────────────────────────────────────────
hdr "CLAUDE.md"
if [ -f CLAUDE.md ]; then
  pass "CLAUDE.md exists"
  LC="$(wc -l < CLAUDE.md | tr -d ' ')"
  if is_int "$LC" && [ "$LC" -le 150 ]; then pass "CLAUDE.md is $LC lines (≤150)"
  else warn "CLAUDE.md is $LC lines — trim toward ≤150 (attention degrades past this)"; fi
else
  fail "CLAUDE.md missing — Claude has no project context"
fi

# ─── .claude + settings.json ─────────────────────────────────────────────────
hdr ".claude/ + settings.json"
[ -d .claude ] && pass ".claude/ exists" || fail ".claude/ directory missing"
if [ -f .claude/settings.json ]; then
  pass ".claude/settings.json exists"
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json;json.load(open('.claude/settings.json'))" 2>/dev/null; then
      pass "settings.json is valid JSON"
      # Every hook command referenced must exist on disk. (Temp file, not process
      # substitution, so this works without /dev/fd and keeps counters in-shell.)
      _hooks_tmp="$(mktemp 2>/dev/null || echo /tmp/cb_hooks.$$)"
      python3 -c "
import json,re
d=json.load(open('.claude/settings.json'))
for ev in (d.get('hooks') or {}).values():
    for grp in ev:
        for h in grp.get('hooks',[]):
            m=re.search(r'(\.claude/hooks/[A-Za-z0-9._-]+\.sh)', h.get('command',''))
            if m: print(m.group(1))
" > "$_hooks_tmp" 2>/dev/null || true
      while IFS= read -r hookfile; do
        [ -z "$hookfile" ] && continue
        if [ -f "$hookfile" ]; then
          [ -x "$hookfile" ] && pass "hook present + executable: $hookfile" || warn "hook not executable: $hookfile (chmod +x)"
        else
          fail "settings.json references a missing hook: $hookfile"
        fi
      done < "$_hooks_tmp"
      rm -f "$_hooks_tmp"
    else
      fail "settings.json is invalid JSON"
    fi
  fi
else
  warn ".claude/settings.json missing — hooks not configured"
fi

# ─── Agents ──────────────────────────────────────────────────────────────────
hdr "Agents (.claude/agents/)"
if [ -d .claude/agents ]; then
  n=0
  for f in .claude/agents/*.md; do
    [ -e "$f" ] || continue
    n=$((n+1)); name="$(basename "$f" .md)"; miss=""
    grep -q "^name:" "$f" || miss="$miss name"
    grep -q "^description:" "$f" || miss="$miss description"
    grep -q "^model:" "$f" || miss="$miss model"
    grep -q "^tools:" "$f" || miss="$miss tools"
    [ -z "$miss" ] && pass "agent $name — frontmatter ok" || fail "agent $name — missing:$miss"
  done
  [ "$n" -gt 0 ] && pass "$n agent(s) found" || warn "no agents (ok for non-dev tier)"
  [ "$n" -gt 8 ] && warn "$n agents — consider agent teams beyond 8"
else
  warn ".claude/agents/ missing (ok for non-dev tier)"
fi

# ─── Skills (KEY FIX: flag any skill dir without SKILL.md) ───────────────────
hdr "Skills (.claude/skills/)"
if [ -d .claude/skills ]; then
  n=0
  for d in .claude/skills/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    if [ -f "$d/SKILL.md" ]; then
      if grep -q "^name:" "$d/SKILL.md" && grep -q "^description:" "$d/SKILL.md"; then
        n=$((n+1)); pass "skill $name — valid"
      else
        fail "skill $name — SKILL.md missing name/description frontmatter"
      fi
    else
      fail "skill $name — no SKILL.md (this skill will NOT load)"
    fi
  done
  [ "$n" -gt 0 ] || warn "no valid skills found"
else
  warn ".claude/skills/ missing"
fi

# ─── Commands ────────────────────────────────────────────────────────────────
hdr "Slash commands (.claude/commands/)"
if [ -d .claude/commands ]; then
  n=0
  for f in .claude/commands/*.md; do
    [ -e "$f" ] || continue
    n=$((n+1)); name="/$(basename "$f" .md)"
    grep -q "^description:" "$f" || warn "command $name — no description in frontmatter"
  done
  [ "$n" -gt 0 ] && pass "$n command(s) found" || warn "no slash commands found"
else
  warn ".claude/commands/ missing — /review, /test, /ship etc. won't exist"
fi

# ─── Hooks on disk ───────────────────────────────────────────────────────────
hdr "Hooks (.claude/hooks/)"
if [ -d .claude/hooks ]; then
  for h in .claude/hooks/*.sh; do
    [ -e "$h" ] || continue
    bash -n "$h" 2>/dev/null && pass "$(basename "$h") — syntax ok" || fail "$(basename "$h") — bash syntax error"
  done
  chmod +x .claude/hooks/*.sh 2>/dev/null || true
else
  warn ".claude/hooks/ missing"
fi

# ─── Optional runtime files ──────────────────────────────────────────────────
hdr "Runtime files"
[ -f USER_PROFILE.json ] && pass "USER_PROFILE.json present" || warn "USER_PROFILE.json missing (optional; run /onboard for a tailored profile)"
[ -f SESSION_STATE.md ] && pass "SESSION_STATE.md present" || warn "SESSION_STATE.md missing (created on first session/compaction)"

# ─── Summary ─────────────────────────────────────────────────────────────────
if [ "$JSON" -eq 1 ]; then
  printf '{"pass":%d,"warnings":%d,"errors":%d}\n' "$PASS" "$WARNINGS" "$ERRORS"
elif [ "$QUIET" -eq 0 ]; then
  printf '\n%s─────────────────────────────%s\n' "$BOLD" "$NC"
  printf '  %s✓%s pass %d   %s⚠%s warn %d   %s✗%s error %d\n' "$GREEN" "$NC" "$PASS" "$YELLOW" "$NC" "$WARNINGS" "$RED" "$NC" "$ERRORS"
  printf '%s─────────────────────────────%s\n\n' "$BOLD" "$NC"
fi

if [ "$ERRORS" -gt 0 ]; then
  [ "$QUIET" -eq 0 ] && printf '%sSetup has errors — fix the ✗ items above.%s\n' "$RED" "$NC"
  exit 1
fi
[ "$QUIET" -eq 0 ] && printf '%sSetup is valid.%s\n' "$GREEN" "$NC"
exit 0

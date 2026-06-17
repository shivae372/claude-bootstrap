#!/usr/bin/env bash
# tests/run.sh — self-test suite for claude-bootstrap.
# Runs locally and in CI. Exits non-zero on any failure.
#   bash tests/run.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  \033[0;32m✓\033[0m %s\n' "$1"; }
no()   { FAIL=$((FAIL+1)); printf '  \033[0;31m✗\033[0m %s\n' "$1"; }
# expect <description> <actual-exit> <expected-exit>
expect(){ if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (exit $2, want $3)"; fi; }
section(){ printf '\n\033[1m%s\033[0m\n' "$1"; }

# ─── 1. Shell syntax + (optional) shellcheck ─────────────────────────────────
section "1. Shell scripts parse"
SH_FILES="$(find . -name '*.sh' -not -path './.git/*' | sort)"
for f in $SH_FILES; do
  bash -n "$f" 2>/dev/null && ok "syntax: $f" || no "syntax: $f"
done

if command -v shellcheck >/dev/null 2>&1; then
  section "1b. shellcheck"
  for f in $SH_FILES; do
    shellcheck -S error "$f" >/dev/null 2>&1 && ok "shellcheck: $f" || no "shellcheck: $f"
  done
else
  printf '  (shellcheck not installed — skipped)\n'
fi

# ─── 2. Stack detection ──────────────────────────────────────────────────────
section "2. detect-project.py"
DET=".claude/skills/onboarding/scripts/detect-project.py"
FIX="$(mktemp -d)"; mkdir -p "$FIX/next" "$FIX/py" "$FIX/empty"
echo '{"dependencies":{"next":"14","react":"18"},"devDependencies":{"vitest":"1"}}' > "$FIX/next/package.json"
echo 'pnpm' > "$FIX/next/pnpm-lock.yaml"
printf 'fastapi\npytest\n' > "$FIX/py/requirements.txt"
if command -v python3 >/dev/null 2>&1; then
  python3 "$DET" --target "$FIX/next" | grep -q '"Next.js"' && ok "detects Next.js" || no "detects Next.js"
  python3 "$DET" --target "$FIX/next" | grep -q '"package_manager": "pnpm"' && ok "detects pnpm" || no "detects pnpm"
  python3 "$DET" --target "$FIX/py" | grep -q '"python"' && ok "detects Python" || no "detects Python"
  python3 "$DET" --target "$FIX/empty" | grep -q '"has_project": false' && ok "empty dir → no project" || no "empty dir → no project"
else
  printf '  (python3 missing — skipped)\n'
fi

# ─── 3. Hook behavior ────────────────────────────────────────────────────────
section "3. Hooks block/allow correctly"
H=".claude/hooks"
echo '{"tool_input":{"command":"rm -rf /"}}'                 | bash "$H/safety-check.sh"   >/dev/null 2>&1; expect "safety: block rm -rf /" $? 2
echo '{"tool_input":{"command":"git push --force"}}'         | bash "$H/safety-check.sh"   >/dev/null 2>&1; expect "safety: block force push" $? 2
echo '{"tool_input":{"command":"npm test && ls"}}'           | bash "$H/safety-check.sh"   >/dev/null 2>&1; expect "safety: allow safe cmd" $? 0
echo '{"tool_name":"Edit","tool_input":{"new_string":"k=\"sk-ant-api03-ABCDEFGHIJKLMNOPQRST\""}}' | bash "$H/secret-detector.sh" >/dev/null 2>&1; expect "secret: block key in Edit" $? 2
echo '{"tool_name":"Write","tool_input":{"content":"x=process.env.KEY"}}'                          | bash "$H/secret-detector.sh" >/dev/null 2>&1; expect "secret: allow env ref" $? 0
echo '{"tool_name":"Write","tool_input":{"content":"password=\"changeme\""}}'                       | bash "$H/secret-detector.sh" >/dev/null 2>&1; expect "secret: allow placeholder" $? 0

CKDIR="$(mktemp -d)"; ( cd "$CKDIR" && echo '{"hook_event_name":"PreCompact","trigger":"auto"}' | bash "$ROOT/$H/checkpoint.sh" >/dev/null 2>&1 )
[ -f "$CKDIR/SESSION_STATE.md" ] && ok "checkpoint: writes SESSION_STATE.md on PreCompact" || no "checkpoint: writes SESSION_STATE.md on PreCompact"

# ─── 4. validate.sh on the repo's own config ─────────────────────────────────
section "4. validate.sh"
ERR=$(bash scripts/validate.sh --json | python3 -c "import sys,json;print(json.load(sys.stdin)['errors'])" 2>/dev/null || echo 99)
expect "validate: 0 errors on repo config" "$ERR" 0

# ─── 5. Every skill directory has a SKILL.md ─────────────────────────────────
section "5. Skill validity"
for d in .claude/skills/*/; do
  n="$(basename "$d")"
  [ -f "$d/SKILL.md" ] && ok "skill has SKILL.md: $n" || no "skill missing SKILL.md: $n"
done

# ─── 6. install.sh end-to-end ────────────────────────────────────────────────
section "6. install.sh end-to-end"
T="$(mktemp -d)"; echo '{"dependencies":{"next":"14"}}' > "$T/package.json"; echo lock > "$T/pnpm-lock.yaml"
bash install.sh --dir "$T" --tier developer --yes >/dev/null 2>&1
[ -f "$T/CLAUDE.md" ] && ok "install: wrote CLAUDE.md" || no "install: wrote CLAUDE.md"
[ -f "$T/.claude/settings.json" ] && ok "install: wrote settings.json" || no "install: wrote settings.json"
[ -f "$T/.claude/.bootstrap.json" ] && ok "install: wrote marker" || no "install: wrote marker"
[ -x "$T/.claude/hooks/safety-check.sh" ] && ok "install: hooks executable" || no "install: hooks executable"
( cd "$T" && bash "$ROOT/scripts/validate.sh" --json | python3 -c "import sys,json;sys.exit(0 if json.load(sys.stdin)['errors']==0 else 1)" ) && ok "install: result validates" || no "install: result validates"
# Non-dev tier omits agents
T2="$(mktemp -d)"; bash install.sh --dir "$T2" --tier non-dev --yes >/dev/null 2>&1
[ ! -d "$T2/.claude/agents" ] && ok "install: non-dev omits agents" || no "install: non-dev omits agents"
# Dry-run writes nothing
T3="$(mktemp -d)"; bash install.sh --dir "$T3" --yes --dry-run >/dev/null 2>&1
[ ! -d "$T3/.claude" ] && ok "install: --dry-run writes nothing" || no "install: --dry-run writes nothing"

# ─── 7. Regression guards ────────────────────────────────────────────────────
section "7. Regression guards"
# Actionable docs/scripts must never point at the wrong owner. CHANGELOG.md (historical note)
# and this test file (which contains the literal for matching) are intentionally excluded.
if grep -rIn "shivae370" --include='*.md' --include='*.sh' --include='*.py' \
     --exclude=CHANGELOG.md --exclude=run.sh . 2>/dev/null | grep -v 'shivae372' | grep -q .; then
  no "no stale 'shivae370' owner (the old 404 bug)"
else
  ok "no stale 'shivae370' owner (the old 404 bug)"
fi
if grep -rIn "github.com/your-org\|github.com/shivae372-hub" --include='*.md' --include='*.sh' \
     --exclude=CHANGELOG.md --exclude=run.sh . 2>/dev/null | grep -q .; then
  no "no placeholder/wrong GitHub URLs"
else
  ok "no placeholder/wrong GitHub URLs"
fi
# Generated CLAUDE.md must not contain unresolved mustache tags
if grep -q '{{' "$T/CLAUDE.md" 2>/dev/null; then no "generated CLAUDE.md has no {{tags}}"; else ok "generated CLAUDE.md has no {{tags}}"; fi

# ─── Summary ─────────────────────────────────────────────────────────────────
printf '\n\033[1m─────────────────────────────\033[0m\n'
printf '  Passed: %d   Failed: %d\n' "$PASS" "$FAIL"
printf '\033[1m─────────────────────────────\033[0m\n'
rm -rf "$FIX" "$CKDIR" "$T" "$T2" "$T3" 2>/dev/null || true
[ "$FAIL" -eq 0 ] || exit 1

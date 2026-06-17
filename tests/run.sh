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
# Install must deploy the Forge engine + MCP server
[ -f "$T/.claude/engine/doctor.py" ] && ok "install: deploys engine/" || no "install: deploys engine/"
[ -f "$T/.claude/mcp/forge_server.py" ] && ok "install: deploys MCP server" || no "install: deploys MCP server"
[ -f "$T/.claude/skills/augment/SKILL.md" ] && ok "install: augment skill present" || no "install: augment skill present"

# ─── 8. Forge engine (self-heal / self-learn / discover / forge / MCP) ───────
section "8. Forge engine"
EROOT="$(mktemp -d)"; mkdir -p "$EROOT/.claude/skills/ghost" "$EROOT/.claude/hooks"
printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash .claude/hooks/gone.sh"}]}]}}' > "$EROOT/.claude/settings.json"
# doctor: detects errors on a broken setup, exit 1
python3 engine/doctor.py --root "$EROOT" --json >/dev/null 2>&1; [ $? -eq 1 ] && ok "doctor: flags broken setup (exit 1)" || no "doctor: flags broken setup"
DOUT="$(python3 engine/doctor.py --root "$EROOT" --json 2>/dev/null || true)"
echo "$DOUT" | grep -q '"score"' && ok "doctor: emits JSON score" || no "doctor: emits JSON score"
python3 engine/doctor.py --manifest >/dev/null 2>&1 && ok "doctor: --manifest works" || no "doctor: --manifest works"
# learn: rejects junk, accepts valid
LROOT="$(mktemp -d)"
echo '{"category":"bogus","text":"x"}' | python3 engine/learn.py add --root "$LROOT" >/dev/null 2>&1 && no "learn: should reject bad category" || ok "learn: rejects bad category"
echo '{"category":"stack","text":"Uses pnpm + Next.js"}' | python3 engine/learn.py add --root "$LROOT" >/dev/null 2>&1 && ok "learn: accepts valid learning" || no "learn: accepts valid learning"
python3 engine/learn.py inject --root "$LROOT" | grep -q "additionalContext" && ok "learn: injects SessionStart context" || no "learn: injects context"
# skill_forge: skeleton fails, scaffolds
FROOT="$(mktemp -d)"
python3 engine/skill_forge.py scaffold --root "$FROOT" --name demo-skill --description "Demo skill for tests. Use when the test asks for a demo." >/dev/null 2>&1 && ok "forge: scaffolds a skill" || no "forge: scaffolds"
python3 engine/skill_forge.py validate "$FROOT/.claude/skills/demo-skill/SKILL.md" >/dev/null 2>&1 && no "forge: skeleton should fail validation" || ok "forge: rejects unfilled skeleton"
# gap_detect: nudges on a real gap, silent on benign
GROOT="$(mktemp -d)"; mkdir -p "$GROOT/.claude"
echo "{\"prompt\":\"add stripe checkout\",\"cwd\":\"$GROOT\"}" | python3 engine/gap_detect.py | grep -q "augment" && ok "gap_detect: nudges on capability gap" || no "gap_detect: nudges on gap"
echo "{\"prompt\":\"fix a typo\",\"cwd\":\"$GROOT\"}" | python3 engine/gap_detect.py | grep -q . && no "gap_detect: should be silent on benign" || ok "gap_detect: silent on benign prompt"
# sources: self-extending discovery — teach, reject junk, surface in ranking
SROOT="$(mktemp -d)"
echo '{"kind":"hint","name":"fly","text":"Fly.io deploy skills live at superfly/"}' | python3 engine/learn.py source-add --root "$SROOT" >/dev/null 2>&1 && ok "sources: learns a valid source" || no "sources: learns a source"
echo '{"kind":"http_json","name":"x","url":"https://api.x/s","name_field":"n"}' | python3 engine/learn.py source-add --root "$SROOT" >/dev/null 2>&1 && no "sources: should reject url without {query}" || ok "sources: rejects invalid source"
python3 engine/skill_finder.py "fly.io deploy" --root "$SROOT" --json 2>/dev/null | grep -q '"learned:fly"' && ok "sources: learned source surfaces in discovery" || no "sources: learned source surfaces"
# MCP server: handshake + tools (incl. learn_source)
MCPOUT="$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | python3 mcp/forge_server.py 2>/dev/null)"
echo "$MCPOUT" | grep -q '"serverInfo"' && ok "mcp: initialize responds" || no "mcp: initialize"
echo "$MCPOUT" | grep -q 'discover_skill' && ok "mcp: lists tools" || no "mcp: lists tools"
echo "$MCPOUT" | grep -q 'learn_source' && ok "mcp: exposes learn_source tool" || no "mcp: exposes learn_source"
rm -rf "$EROOT" "$LROOT" "$FROOT" "$GROOT" "$SROOT" 2>/dev/null || true

# ─── 9. Everything in sync (the consistency guard) ───────────────────────────
section "9. In-sync / consistency"
# 9a. No skill ships the non-standard `version:` frontmatter key (spec compliance).
if grep -rl '^version:' .claude/skills/*/SKILL.md 2>/dev/null | grep -q .; then no "skills: no non-standard 'version:' key"; else ok "skills: spec-compliant frontmatter (no 'version:')"; fi
# 9b. Plugin hooks.json has the required outer "hooks" wrapper.
python3 -c "import json,sys; sys.exit(0 if 'hooks' in json.load(open('.claude/hooks/hooks.json')) else 1)" 2>/dev/null && ok "plugin hooks.json has outer 'hooks' wrapper" || no "plugin hooks.json wrapper"
# 9c. Every skill install.sh advertises actually exists in the repo.
SYNC_MISS=0
for s in $(grep -oE 'DEV_SKILLS=\([^)]*\)' install.sh | tr -d '()' | cut -d= -f2); do
  [ -f ".claude/skills/$s/SKILL.md" ] || { echo "    missing skill: $s"; SYNC_MISS=1; }
done
[ "$SYNC_MISS" -eq 0 ] && ok "install.sh DEV_SKILLS all exist on disk" || no "install.sh lists a missing skill"
# 9d. Every command install.sh advertises exists.
CMD_MISS=0
for c in $(grep -oE 'DEV_COMMANDS=\([^)]*\)' install.sh | tr -d '()' | cut -d= -f2); do
  [ -f ".claude/commands/$c.md" ] || { echo "    missing command: $c"; CMD_MISS=1; }
done
[ "$CMD_MISS" -eq 0 ] && ok "install.sh DEV_COMMANDS all exist on disk" || no "install.sh lists a missing command"
# 9e. Every hook referenced in settings.json exists and is executable.
HK_MISS=0
for h in $(python3 -c "import json,re; d=json.load(open('.claude/settings.json')); [print(re.search(r'hooks/([\w.-]+)',x['command']).group(1)) for ev in d['hooks'].values() for g in ev for x in g['hooks'] if 'hooks/' in x['command']]" 2>/dev/null); do
  [ -x ".claude/hooks/$h" ] || { echo "    missing/!x hook: $h"; HK_MISS=1; }
done
[ "$HK_MISS" -eq 0 ] && ok "settings.json hooks all present + executable" || no "settings.json references a missing hook"
# 9f. Engine scripts referenced by skills/hooks exist.
ENG_OK=1
for e in skill_finder doctor learn skill_forge gap_detect sources; do
  [ -f "engine/$e.py" ] || { echo "    missing engine: $e"; ENG_OK=0; }
done
[ "$ENG_OK" -eq 1 ] && ok "all engine scripts present" || no "an engine script is missing"

# ─── Summary ─────────────────────────────────────────────────────────────────
printf '\n\033[1m─────────────────────────────\033[0m\n'
printf '  Passed: %d   Failed: %d\n' "$PASS" "$FAIL"
printf '\033[1m─────────────────────────────\033[0m\n'
rm -rf "$FIX" "$CKDIR" "$T" "$T2" "$T3" 2>/dev/null || true
[ "$FAIL" -eq 0 ] || exit 1

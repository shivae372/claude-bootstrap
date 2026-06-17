#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# claude-bootstrap · install.sh
#
# Deterministic, zero-token installer for a professional Claude Code setup.
# It detects your stack and copies a curated, TESTED .claude/ config (agents,
# skills, hooks, slash-commands, settings) into your project, then generates a
# tailored CLAUDE.md and SESSION_STATE.md. No LLM calls, no waiting, no surprises.
#
# Two ways to run:
#   1. One-liner (no clone):
#        curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash
#   2. From a clone:
#        git clone https://github.com/shivae372/claude-bootstrap && bash claude-bootstrap/install.sh
#
# Run with --help for all options. Run with --dry-run to preview without writing.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Single source of truth for repo identity (kills the old 404 install bug) ──
REPO_OWNER="shivae372"
REPO_NAME="claude-bootstrap"
REPO_REF="master"
BOOTSTRAP_VERSION="1.1.0"

# ─── Colors (auto-disable when not a TTY or NO_COLOR is set) ────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; DIM=''; BOLD=''; NC=''
fi

say()  { printf '%s\n' "$*"; }
info() { printf '  %s%s%s\n' "$BLUE" "$*" "$NC"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '  %s✗%s %s\n' "$RED" "$NC" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ─── Defaults / flags ───────────────────────────────────────────────────────────
TARGET_DIR="$PWD"
TIER=""                 # developer | hybrid | non-dev (empty = auto/ask)
STACK_OVERRIDE=""       # force a stack instead of auto-detect
ASSUME_YES=0
DRY_RUN=0
FORCE=0
MERGE=0
NO_HOOKS=0
DO_UNINSTALL=0
QUIET=0

usage() {
  cat <<EOF
${BOLD}claude-bootstrap${NC} · install.sh (v${BOOTSTRAP_VERSION})

Generate a professional Claude Code setup for any project — instantly, deterministically.

${BOLD}USAGE${NC}
  bash install.sh [options]
  curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}/install.sh | bash

${BOLD}OPTIONS${NC}
  --dir <path>         Install into this project dir (default: current directory)
  --tier <tier>        developer | hybrid | non-dev (default: auto from --tech, else developer)
  --tech <1-5>         Your comfort with code/terminal; maps to a tier when --tier is omitted
  --stack <name>       Force a stack (nextjs|python|go|rust|ruby|java|monorepo|none); default: auto-detect
  --merge              Add only missing files; never overwrite existing ones (no backup needed)
  --force              Overwrite existing .claude files without creating a backup
  --no-hooks           Do not install git/format/safety hooks
  -y, --yes            Non-interactive; accept defaults (implies tier=developer if unset)
  --dry-run            Show exactly what would happen; write nothing
  --uninstall          Remove a claude-bootstrap setup from --dir (backs up first)
  --ref <git-ref>      Branch/tag to fetch when run via curl (default: ${REPO_REF})
  -q, --quiet          Less output
  -h, --help           Show this help

${BOLD}EXAMPLES${NC}
  bash install.sh                          # detect stack, developer tier, into ./
  bash install.sh --tier non-dev --yes     # plain-English setup, no prompts
  bash install.sh --dir ~/code/app --dry-run
  bash install.sh --uninstall

Docs: https://github.com/${REPO_OWNER}/${REPO_NAME}
EOF
}

# ─── Parse args ─────────────────────────────────────────────────────────────────
TECH_LEVEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) TARGET_DIR="${2:-}"; shift 2 ;;
    --tier) TIER="${2:-}"; shift 2 ;;
    --tech) TECH_LEVEL="${2:-}"; shift 2 ;;
    --stack) STACK_OVERRIDE="${2:-}"; shift 2 ;;
    --ref) REPO_REF="${2:-}"; shift 2 ;;
    --merge) MERGE=1; shift ;;
    --force) FORCE=1; shift ;;
    --no-hooks) NO_HOOKS=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --uninstall) DO_UNINSTALL=1; shift ;;
    -q|--quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1  (run --help)" ;;
  esac
done

# Resolve target to an absolute path.
mkdir -p "$TARGET_DIR" 2>/dev/null || true
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || die "Cannot access --dir: $TARGET_DIR"

# ─── Locate the component library (clone next to us, or download it) ────────────
SRC_DIR=""
TMP_DOWNLOAD=""
self="${BASH_SOURCE[0]:-}"
if [ -n "$self" ] && [ -f "$self" ]; then
  cand="$(cd "$(dirname "$self")" && pwd)"
  # The script may live at repo-root/install.sh OR repo-root/scripts/*.
  if [ -d "$cand/.claude/agents" ]; then SRC_DIR="$cand"
  elif [ -d "$cand/../.claude/agents" ]; then SRC_DIR="$(cd "$cand/.." && pwd)"; fi
fi

download_library() {
  command -v curl >/dev/null 2>&1 || die "curl is required to fetch the component library."
  TMP_DOWNLOAD="$(mktemp -d 2>/dev/null || mktemp -d -t cb)"
  local url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/heads/${REPO_REF}"
  [ "$QUIET" -eq 1 ] || info "Fetching component library (${REPO_OWNER}/${REPO_NAME}@${REPO_REF})…"
  if ! curl -fsSL "$url" -o "$TMP_DOWNLOAD/cb.tgz"; then
    # Maybe REPO_REF is a tag, not a branch.
    url="https://codeload.github.com/${REPO_OWNER}/${REPO_NAME}/tar.gz/refs/tags/${REPO_REF}"
    curl -fsSL "$url" -o "$TMP_DOWNLOAD/cb.tgz" || die "Could not download library from GitHub (ref: ${REPO_REF})."
  fi
  tar -xzf "$TMP_DOWNLOAD/cb.tgz" -C "$TMP_DOWNLOAD" || die "Could not extract library archive."
  SRC_DIR="$(find "$TMP_DOWNLOAD" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -1)"
  [ -n "$SRC_DIR" ] && [ -d "$SRC_DIR/.claude/agents" ] || die "Downloaded library looks incomplete."
}

cleanup() { [ -n "$TMP_DOWNLOAD" ] && rm -rf "$TMP_DOWNLOAD" 2>/dev/null || true; }
trap cleanup EXIT

if [ -z "$SRC_DIR" ] || [ ! -d "$SRC_DIR/.claude/agents" ]; then
  download_library
fi

# ─── Header ─────────────────────────────────────────────────────────────────────
if [ "$QUIET" -eq 0 ]; then
  say ""
  say "${CYAN}${BOLD}  claude-bootstrap${NC} ${DIM}v${BOOTSTRAP_VERSION}${NC}"
  say "${DIM}  Professional Claude Code setup — deterministic, instant, token-free.${NC}"
  say ""
fi

# ─── Uninstall path ──────────────────────────────────────────────────────────────
if [ "$DO_UNINSTALL" -eq 1 ]; then
  marker="$TARGET_DIR/.claude/.bootstrap.json"
  [ -f "$marker" ] || die "No claude-bootstrap install found in $TARGET_DIR (.claude/.bootstrap.json missing)."
  ts="$(date -u +%Y%m%d-%H%M%S)"
  backup="$TARGET_DIR/.claude.backup.$ts"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "[dry-run] Would back up .claude → $(basename "$backup") and remove the bootstrap config."
    exit 0
  fi
  cp -R "$TARGET_DIR/.claude" "$backup"
  rm -rf "$TARGET_DIR/.claude"
  ok "Removed .claude/ (backup at $(basename "$backup"))."
  say "  CLAUDE.md and SESSION_STATE.md were left untouched — delete them manually if desired."
  exit 0
fi

# ─── Stack detection (deterministic) ─────────────────────────────────────────────
DETECTED_JSON=""
detect() {
  local detector="$SRC_DIR/.claude/skills/onboarding/scripts/detect-project.py"
  if command -v python3 >/dev/null 2>&1 && [ -f "$detector" ]; then
    DETECTED_JSON="$(python3 "$detector" --target "$TARGET_DIR" 2>/dev/null || true)"
  fi
  # Bash fallback so the installer still works without Python.
  if [ -z "$DETECTED_JSON" ]; then
    local lang="unknown" stack="[]" pm="unknown"
    if   [ -f "$TARGET_DIR/package.json" ]; then lang="javascript"; stack='["node"]'
         [ -f "$TARGET_DIR/pnpm-lock.yaml" ] && pm="pnpm"; [ -f "$TARGET_DIR/yarn.lock" ] && pm="yarn"; [ -f "$TARGET_DIR/package-lock.json" ] && pm="npm"
         grep -q '"next"' "$TARGET_DIR/package.json" 2>/dev/null && stack='["Next.js"]'
    elif [ -f "$TARGET_DIR/pyproject.toml" ] || [ -f "$TARGET_DIR/requirements.txt" ]; then lang="python"; pm="pip"; stack='["python"]'
    elif [ -f "$TARGET_DIR/go.mod" ]; then lang="go"; pm="go"; stack='["go"]'
    elif [ -f "$TARGET_DIR/Cargo.toml" ]; then lang="rust"; pm="cargo"; stack='["rust"]'
    elif [ -f "$TARGET_DIR/Gemfile" ]; then lang="ruby"; pm="bundler"; stack='["ruby"]'
    elif [ -f "$TARGET_DIR/pom.xml" ] || [ -f "$TARGET_DIR/build.gradle" ]; then lang="java"; pm="maven_or_gradle"; stack='["java"]'
    fi
    DETECTED_JSON="{\"has_project\":true,\"language\":\"$lang\",\"stack\":$stack,\"package_manager\":\"$pm\",\"test_runner\":\"unknown\",\"ci\":[],\"databases\":[]}"
  fi
}
detect

# Pull a couple of fields for display + stack mapping (python if available, else grep).
json_field() {
  local key="$1"
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$DETECTED_JSON" | python3 -c "import sys,json;d=json.load(sys.stdin);v=d.get('$key','');print(', '.join(v) if isinstance(v,list) else v)" 2>/dev/null || true
  else
    printf '%s' "$DETECTED_JSON" | grep -o "\"$key\"[^,]*" | head -1 | sed 's/.*: *//; s/[\"]//g' || true
  fi
}
LANGUAGE="$(json_field language)"; [ -z "$LANGUAGE" ] && LANGUAGE="unknown"
STACK_LIST="$(json_field stack)"
PKG_MANAGER="$(json_field package_manager)"; [ -z "$PKG_MANAGER" ] && PKG_MANAGER="unknown"

# Map detected language → a stacks/<name>.md key.
map_stack() {
  if [ -n "$STACK_OVERRIDE" ]; then echo "$STACK_OVERRIDE"; return; fi
  case "$LANGUAGE" in
    javascript|typescript)
      printf '%s' "$STACK_LIST" | grep -qi "next" && { echo "nextjs"; return; }
      [ -f "$TARGET_DIR/turbo.json" ] || [ -f "$TARGET_DIR/nx.json" ] && { echo "monorepo"; return; }
      echo "nextjs" ;;
    python) echo "python" ;;
    go) echo "go" ;;
    rust) echo "rust" ;;
    ruby) echo "ruby" ;;
    java) echo "java" ;;
    *) echo "no-stack" ;;
  esac
}
STACK_KEY="$(map_stack)"

# ─── Tier resolution ─────────────────────────────────────────────────────────────
tier_from_tech() {
  case "${1:-}" in
    1|2) echo "non-dev" ;;
    3)   echo "hybrid" ;;
    4|5) echo "developer" ;;
    *)   echo "" ;;
  esac
}
if [ -z "$TIER" ] && [ -n "$TECH_LEVEL" ]; then TIER="$(tier_from_tech "$TECH_LEVEL")"; fi
if [ -z "$TIER" ]; then
  if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
    TIER="developer"
  else
    say "${BOLD}  Who is this setup for?${NC}"
    say "    ${DIM}1)${NC} Developer  — full agent set, TDD, review, security, git hooks"
    say "    ${DIM}2)${NC} Hybrid     — founder/designer; simplified agents, plain-language"
    say "    ${DIM}3)${NC} Non-dev    — plain English, no agents, task-focused"
    printf "  Choose [1-3] (default 1): "
    read -r choice || choice=""
    case "$choice" in 2) TIER="hybrid" ;; 3) TIER="non-dev" ;; *) TIER="developer" ;; esac
    say ""
  fi
fi
case "$TIER" in developer|hybrid|non-dev) ;; *) die "Invalid --tier: $TIER (use developer|hybrid|non-dev)" ;; esac

PROJECT_NAME="$(basename "$TARGET_DIR")"

# ─── Plan summary ────────────────────────────────────────────────────────────────
if [ "$QUIET" -eq 0 ]; then
  say "${BOLD}  Plan${NC}"
  ok "Project:        $PROJECT_NAME"
  ok "Location:       $TARGET_DIR"
  ok "Language:       ${LANGUAGE}${STACK_LIST:+  ($STACK_LIST)}"
  ok "Stack template: $STACK_KEY"
  ok "Tier:           $TIER"
  ok "Hooks:          $([ "$NO_HOOKS" -eq 1 ] && echo 'skipped (--no-hooks)' || echo 'enabled')"
  say ""
fi

# ─── Component plan by tier ──────────────────────────────────────────────────────
# Developer = everything. Hybrid = lighter. Non-dev = no agents, gentle skills.
DEV_AGENTS=(explorer code-reviewer test-runner security-scanner dep-checker doc-writer)
DEV_SKILLS=(augment forge doctor learn analyze-repo code-review context-guard dep-check git-workflow security-scan test-runner self-update tips onboarding)
DEV_COMMANDS=(bootstrap plan test review security deps ship checkpoint tips update onboard)

HYB_AGENTS=(explorer code-reviewer test-runner)
HYB_SKILLS=(augment forge doctor learn analyze-repo code-review context-guard git-workflow test-runner tips onboarding self-update)
HYB_COMMANDS=(bootstrap plan test review ship checkpoint tips update onboard)

NON_SKILLS=(augment doctor learn context-guard tips onboarding self-update)
NON_COMMANDS=(bootstrap plan tips update onboard checkpoint)

ALL_HOOKS=(safety-check.sh secret-detector.sh format.sh checkpoint.sh session-start.sh user-prompt-submit.sh capture-failure.sh notify.sh)

case "$TIER" in
  developer) AGENTS=("${DEV_AGENTS[@]}"); SKILLS=("${DEV_SKILLS[@]}"); COMMANDS=("${DEV_COMMANDS[@]}") ;;
  hybrid)    AGENTS=("${HYB_AGENTS[@]}"); SKILLS=("${HYB_SKILLS[@]}"); COMMANDS=("${HYB_COMMANDS[@]}") ;;
  non-dev)   AGENTS=();                   SKILLS=("${NON_SKILLS[@]}"); COMMANDS=("${NON_COMMANDS[@]}") ;;
esac

# ─── Helpers for copy + dry-run ──────────────────────────────────────────────────
WROTE=0; SKIPPED=0
copy_into() {  # copy_into <src-file-or-dir> <dest-path>
  local s="$1" d="$2"
  if [ "$DRY_RUN" -eq 1 ]; then printf '    %s+%s %s\n' "$DIM" "$NC" "${d#"$TARGET_DIR"/}"; WROTE=$((WROTE+1)); return; fi
  if [ "$MERGE" -eq 1 ] && [ -e "$d" ]; then SKIPPED=$((SKIPPED+1)); return; fi
  mkdir -p "$(dirname "$d")"
  cp -R "$s" "$d"
  WROTE=$((WROTE+1))
}

# ─── Back up existing .claude unless --merge/--force ─────────────────────────────
CLAUDE_DIR="$TARGET_DIR/.claude"
if [ -d "$CLAUDE_DIR" ] && [ "$MERGE" -eq 0 ] && [ "$FORCE" -eq 0 ]; then
  ts="$(date -u +%Y%m%d-%H%M%S)"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "[dry-run] Would back up existing .claude/ → .claude.backup.$ts"
  else
    cp -R "$CLAUDE_DIR" "$TARGET_DIR/.claude.backup.$ts"
    ok "Backed up existing .claude/ → .claude.backup.$ts"
  fi
fi

[ "$QUIET" -eq 0 ] && say "${BOLD}  Installing${NC}"

# ─── Agents ──────────────────────────────────────────────────────────────────────
for a in ${AGENTS[@]+"${AGENTS[@]}"}; do
  [ -f "$SRC_DIR/.claude/agents/$a.md" ] && copy_into "$SRC_DIR/.claude/agents/$a.md" "$CLAUDE_DIR/agents/$a.md"
done

# ─── Skills (skill = a directory with SKILL.md, plus any scripts/) ──────────────
for s in ${SKILLS[@]+"${SKILLS[@]}"}; do
  [ -d "$SRC_DIR/.claude/skills/$s" ] && copy_into "$SRC_DIR/.claude/skills/$s" "$CLAUDE_DIR/skills/$s"
done

# ─── Slash commands ──────────────────────────────────────────────────────────────
for c in ${COMMANDS[@]+"${COMMANDS[@]}"}; do
  [ -f "$SRC_DIR/.claude/commands/$c.md" ] && copy_into "$SRC_DIR/.claude/commands/$c.md" "$CLAUDE_DIR/commands/$c.md"
done

# ─── Hooks + settings.json ───────────────────────────────────────────────────────
if [ "$NO_HOOKS" -eq 0 ]; then
  for h in "${ALL_HOOKS[@]}"; do
    [ -f "$SRC_DIR/.claude/hooks/$h" ] && copy_into "$SRC_DIR/.claude/hooks/$h" "$CLAUDE_DIR/hooks/$h"
  done
  copy_into "$SRC_DIR/.claude/settings.json" "$CLAUDE_DIR/settings.json"
  if [ "$DRY_RUN" -eq 0 ] && [ -d "$CLAUDE_DIR/hooks" ]; then
    chmod +x "$CLAUDE_DIR"/hooks/*.sh 2>/dev/null || true
  fi
fi

# ─── Forge engine + MCP server (the self-healing / self-learning brain) ──────────
# Copied into the project so skills, hooks, and the MCP server all resolve locally.
if [ -d "$SRC_DIR/engine" ]; then
  for f in "$SRC_DIR"/engine/*.py; do
    [ -f "$f" ] && copy_into "$f" "$CLAUDE_DIR/engine/$(basename "$f")"
  done
fi
if [ -d "$SRC_DIR/mcp" ]; then
  for f in "$SRC_DIR"/mcp/*.py; do
    [ -f "$f" ] && copy_into "$f" "$CLAUDE_DIR/mcp/$(basename "$f")"
  done
  # Register the Forge MCP server for this project (merge-safe: don't clobber an existing .mcp.json).
  if [ -f "$SRC_DIR/.mcp.json" ] && [ ! -e "$TARGET_DIR/.mcp.json" ]; then
    copy_into "$SRC_DIR/.mcp.json" "$TARGET_DIR/.mcp.json"
  elif [ -e "$TARGET_DIR/.mcp.json" ] && [ "$DRY_RUN" -eq 0 ]; then
    warn ".mcp.json already exists — add the 'forge' server manually (see .claude/mcp/forge_server.py)."
  fi
fi

# ─── Generate CLAUDE.md + SESSION_STATE.md ───────────────────────────────────────
render_docs() {
  local renderer="$SRC_DIR/scripts/render.py"
  local tpl="$SRC_DIR/docs/templates/$TIER/CLAUDE.md.tpl"
  local out_claude="$TARGET_DIR/CLAUDE.md"
  local out_state="$TARGET_DIR/SESSION_STATE.md"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    %s+%s %s\n' "$DIM" "$NC" "CLAUDE.md"
    [ -f "$out_state" ] || printf '    %s+%s %s\n' "$DIM" "$NC" "SESSION_STATE.md"
    return
  fi

  if [ -e "$out_claude" ] && [ "$MERGE" -eq 1 ]; then
    warn "CLAUDE.md exists — left untouched (--merge). New context not written."
  elif command -v python3 >/dev/null 2>&1 && [ -f "$renderer" ]; then
    python3 "$renderer" --template "$tpl" --detected-json "$DETECTED_JSON" \
      --project-name "$PROJECT_NAME" --tier "$TIER" --stack-key "$STACK_KEY" \
      --version "$BOOTSTRAP_VERSION" > "$out_claude" || warn "CLAUDE.md render failed; see template at $tpl"
    ok "Wrote CLAUDE.md"
  else
    # Minimal fallback render (no python): copy template, swap a couple of vars.
    sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" -e "s/{{STACK}}/${STACK_LIST:-$LANGUAGE}/g" "$tpl" > "$out_claude" 2>/dev/null \
      || cp "$tpl" "$out_claude"
    ok "Wrote CLAUDE.md (basic)"
  fi

  if [ ! -e "$out_state" ]; then
    local stpl="$SRC_DIR/docs/templates/SESSION_STATE.md.tpl"
    if [ -f "$stpl" ]; then
      sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" -e "s/{{DATE}}/$(date -u +%Y-%m-%d)/g" "$stpl" > "$out_state"
    else
      printf '# Session State\n## Last updated: %s\n\n## Current Task\n_Nothing yet._\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$out_state"
    fi
    ok "Wrote SESSION_STATE.md"
  fi
}
render_docs

# ─── Write install marker (manifest used by --uninstall and /update) ─────────────
if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$CLAUDE_DIR"
  cat > "$CLAUDE_DIR/.bootstrap.json" <<EOF
{
  "bootstrap_version": "$BOOTSTRAP_VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tier": "$TIER",
  "stack_key": "$STACK_KEY",
  "language": "$LANGUAGE",
  "source": "${REPO_OWNER}/${REPO_NAME}@${REPO_REF}"
}
EOF
fi

# ─── Validate (non-fatal) ────────────────────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ] && [ -f "$SRC_DIR/scripts/validate.sh" ]; then
  [ "$QUIET" -eq 0 ] && { say ""; }
  ( cd "$TARGET_DIR" && bash "$SRC_DIR/scripts/validate.sh" --quiet ) || warn "Validation reported issues (see above)."
fi

# ─── Summary ─────────────────────────────────────────────────────────────────────
say ""
if [ "$DRY_RUN" -eq 1 ]; then
  say "${BOLD}  Dry run complete${NC} — ${WROTE} item(s) would be written. Nothing changed."
  exit 0
fi
say "${GREEN}${BOLD}  ✓ Setup complete${NC} — ${WROTE} item(s) installed${DIM}${SKIPPED:+, $SKIPPED skipped}${NC}."
say ""
say "${BOLD}  What you got${NC}"
[ "${#AGENTS[@]}" -gt 0 ] && ok "${#AGENTS[@]} sub-agents in .claude/agents/"
ok "${#SKILLS[@]} skills in .claude/skills/"
ok "${#COMMANDS[@]} slash commands in .claude/commands/"
[ "$NO_HOOKS" -eq 0 ] && ok "Guardrail hooks wired in .claude/settings.json"
ok "Tailored CLAUDE.md + SESSION_STATE.md"
say ""
say "${BOLD}  Next steps${NC}"
say "    1. ${CYAN}claude${NC}                       ${DIM}# start Claude Code in this project${NC}"
say "    2. ${CYAN}/bootstrap${NC}                   ${DIM}# (optional) let Claude tailor the setup further${NC}"
if [ "$TIER" = "non-dev" ]; then
  say "    3. ${CYAN}/onboard${NC}, ${CYAN}/plan${NC}, ${CYAN}/tips${NC}     ${DIM}# your starting commands${NC}"
else
  say "    3. ${CYAN}/review${NC}, ${CYAN}/test${NC}, ${CYAN}/ship${NC}        ${DIM}# your new workflow commands${NC}"
fi
say ""
say "  ${DIM}Re-run anytime. Undo with: bash install.sh --uninstall${NC}"
say ""

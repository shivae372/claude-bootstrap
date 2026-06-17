# claude-bootstrap — Repo Guide

Context for Claude (and humans) working **inside this repository**. If you're an end user who
ran the installer in *your own* project, this file isn't yours — your generated `CLAUDE.md` is.

## What this project is
A tool that installs a professional Claude Code setup into any project. Philosophy:
**deterministic core, AI for judgment.** A real installer does the reliable work; the LLM is
only used for optional, interactive tailoring (the `/bootstrap` command).

## Architecture
- `install.sh` — the entry point. Detects stack, resolves tier, backs up, copies components,
  renders `CLAUDE.md`, writes `SESSION_STATE.md` + `.claude/.bootstrap.json`, validates. Runs via
  `curl | bash` (self-downloads the library) or from a clone. Zero LLM calls.
- `scripts/render.py` — pure substitution: tier template + detected facts → final `CLAUDE.md`.
- `scripts/validate.sh` — verifies a setup (agents/skills/commands/hooks/JSON); `--quiet`/`--json`.
- `scripts/format.sh` — manual multi-language formatter. `scripts/bootstrap.sh` — shim → `install.sh`.
- `.claude/` is the **component library** that gets copied into user projects:
  - `agents/` one job each, read-only unless they must write.
  - `skills/` every dir MUST contain `SKILL.md` (a skill without it does not load).
  - `commands/` slash commands (`/plan`, `/review`, `/ship`, …).
  - `hooks/` shell guardrails (see contracts below).
  - `settings.json` wires hooks to events.
- `docs/stacks/*` per-stack reference; `docs/templates/<tier>/` tier templates; `docs/FORMATS.md` specs.

## Hook contracts (get these exactly right — past bugs lived here)
- Hooks receive **JSON on stdin**, never positional args.
- `PreToolUse` blocks with **exit 2** and the reason on **stderr** (Claude reads stderr on block).
- `PreCompact` payloads contain `trigger`/`custom_instructions` — **no** `tool_name`/`tool_input`.
  Never gate PreCompact logic on a tool name.
- `SessionStart` injects context via JSON `hookSpecificOutput.additionalContext`.
- Write paths differ: Write→`content`, Edit→`new_string`, MultiEdit→`edits[].new_string`.

## Hard rules
- One agent = one job; scope its `tools`; route read-only work to Haiku.
- Every skill directory has a `SKILL.md` with `name` + `description`.
- `CLAUDE.md` (this one and generated ones) stays ≤150 lines.
- Single source of truth for the repo URL: `REPO_OWNER`/`REPO_NAME` in `install.sh`
  (owner is **shivae372** — a wrong owner is what made the old installer 404).
- Prefer a hook over a CLAUDE.md "NEVER" rule — hooks are 100% reliable, prose ~70%.

## Testing (always before committing)
```bash
bash tests/run.sh          # full suite: syntax, hooks, detection, install e2e, regressions
bash scripts/validate.sh   # validate this repo's own .claude/
```
CI (`.github/workflows/ci.yml`) runs the suite on Linux + macOS for every push and PR.

## Conventions
- Bash: `#!/usr/bin/env bash`, `set -uo pipefail`, GNU/BSD-portable `sed`, no `/dev/fd`
  process substitution (some sandboxes lack it — use temp files).
- Commits: conventional (`feat:`, `fix:`, `docs:`…). Keep `VERSION` and `CHANGELOG.md` in sync on release.

# Changelog

All notable changes to claude-bootstrap are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/); this project uses [SemVer](https://semver.org/).

## [1.1.0] — 2026-06-17

The **Forge living engine** — claude-bootstrap stops being a one-shot setup and becomes a
self-healing, self-learning capability engine that grows itself in real time as you work.
Modeled on `nodo`'s philosophy: the tool finds where it's blind, Claude reasons, the tool
persists and applies deterministically — offline, zero-dependency, validated before apply.

### Added — the engine (`.claude/engine/`, pure stdlib)
- **`skill_finder.py`** — discovers skills/MCP across the open ecosystem (Anthropic skills,
  GitHub topic+repo search, the MCP Registry, Smithery) with relevance ranking, trust scoring,
  and graceful degradation. Proven live (finds the official Stripe MCP, postgres servers, the
  official `pdf` skill, GitHub skill repos).
- **`doctor.py`** — deterministic self-heal: health score + structured findings + safe
  auto-fixes (`--apply`) + a capability manifest (`--manifest`).
- **`learn.py`** — self-learning lessons store (validated, bounded, local) that the SessionStart
  hook injects so every session starts smarter.
- **`skill_forge.py`** — scaffolds + validates bespoke skills; the validator **rejects generic,
  unfilled skeletons** so a forged skill is always detailed and specific.
- **`gap_detect.py`** — the real-time trigger behind the UserPromptSubmit hook.

### Added — Claude-facing layer
- **Skills**: `augment` (discover → vet → install, else forge), `forge` (author a detailed
  project-specific skill), `doctor` (self-heal), `learn` (remember).
- **Real-time hooks**: `user-prompt-submit.sh` (notices a capability gap mid-task and nudges
  Claude to `augment` then and there), `capture-failure.sh` (logs tool failures → heal nudge),
  and an upgraded `session-start.sh` (injects SESSION_STATE + capability manifest + learnings).
- **MCP server** `mcp/forge_server.py` (stdio JSON-RPC, pure stdlib) exposing `discover_skill`,
  `capability_audit`, `heal_report`, `record_learning` — so Claude can augment/heal the setup
  live, mid-session. Registered via `.mcp.json`.
- **Plugin packaging** (`.claude-plugin/plugin.json` + `marketplace.json` + `hooks.json`) so the
  whole thing installs via `/plugin marketplace add shivae372/claude-bootstrap` (experimental;
  the installer remains the validated path).

### Changed
- `install.sh` (now v1.1.0) deploys the engine + MCP server into every project and registers the
  new skills/hooks across all tiers.
- Test suite grown to **64 checks** covering the engine, hooks, MCP handshake, and install e2e.

### Known limitations (honest)
- MCP servers can't be hot-registered into a *running* session — `.mcp.json`/`claude mcp add`
  take effect next session.
- The plugin manifest path isn't validated against live Claude Code yet; use the installer.

## [1.0.0] — 2026-06-17

A ground-up reliability overhaul. The bootstrap moved from a fragile, LLM-driven generator to a
**deterministic installer with a tested component library**. This is the first release where the
documented quick-start actually works end to end.

### Added
- **`install.sh`** — deterministic, zero-token installer. Runs via `curl | bash` (self-downloads
  the component library) or from a clone. Flags: `--dir`, `--tier`, `--tech`, `--stack`, `--merge`,
  `--force`, `--no-hooks`, `--yes`, `--dry-run`, `--uninstall`, `--ref`, `--quiet`, `--help`.
  Backs up any existing `.claude/` before changing anything.
- **Real slash commands** in `.claude/commands/`: `/bootstrap`, `/plan`, `/test`, `/review`,
  `/security`, `/deps`, `/ship`, `/checkpoint`, `/tips`, `/update`, `/onboard`. (Previously the
  README promised these but none existed.)
- **`/bootstrap`** interactive command — the correct home for AI-driven tailoring (runs in a live
  session where it can ask questions and write with permission).
- **`SessionStart` hook** (`session-start.sh`) — feeds `SESSION_STATE.md` back so Claude resumes
  where you left off. Makes the long-advertised "session continuity" real.
- **`scripts/render.py`** — deterministic `CLAUDE.md` rendering from tier template + detected facts.
- **Test suite** (`tests/run.sh`) + **GitHub Actions CI** (Linux + macOS): syntax/shellcheck,
  hook block-allow behavior, stack detection, full installer e2e, and regression guards.
- **`VERSION`** marker and `.claude/.bootstrap.json` install manifest (powers `--uninstall` / `/update`).
- **`CHANGELOG.md`**.

### Fixed
- **Install command 404'd for everyone.** Docs cloned `github.com/shivae370/…` (wrong owner) →
  HTTP 404. Repo identity is now a single source of truth in `install.sh` (`shivae372`), with a
  CI regression guard that fails the build if a wrong owner ever reappears.
- **`secret-detector.sh` missed the common path and cried wolf on the rest.** It read `new_str`
  (real key is `new_string`) so secrets in `Edit`/`MultiEdit` slipped through, while hard-blocking
  harmless placeholders like `password = "changeme"`. Now inspects Write/Edit/MultiEdit correctly,
  blocks only high-confidence provider keys, ignores placeholders/`process.env`, and warns (not
  blocks) on low-confidence patterns. Reasons print to stderr; bypass with `CLAUDE_BOOTSTRAP_ALLOW_SECRETS=1`.
- **`checkpoint.sh` was dead code.** Wired to `PreCompact` but gated on `tool_name` (which
  PreCompact payloads never contain), so it exited immediately and never checkpointed. Rewritten to
  the real PreCompact contract; it now writes/updates `SESSION_STATE.md`.
- **`safety-check.sh`** now prints block reasons to **stderr** (which Claude Code surfaces on a
  blocking exit), uses tightened patterns (incl. fork-bombs, `curl|bash`), and supports
  `CLAUDE_BOOTSTRAP_ALLOW_DANGEROUS=1`.
- **Broken skills.** `onboarding`, `self-update`, and `tips` shipped without `SKILL.md`, so
  `Skill('onboarding')` never resolved. All three now have valid `SKILL.md`; `tips` is self-contained
  (it referenced a `tips.json` that didn't exist).
- **`validate.sh` gave false green lights** — it counted only dirs that already had `SKILL.md`, so it
  could never flag the broken skills. It now flags any skill dir missing `SKILL.md`, checks commands,
  verifies every hook referenced in `settings.json` exists, and adds `--quiet`/`--json`.

### Changed
- Replaced the headless `claude --print` generation flow (which couldn't ask questions, couldn't
  confirm a blueprint, and couldn't write files without permissions) with the deterministic installer
  plus the interactive `/bootstrap` command.
- `scripts/bootstrap.sh` is now a thin shim that forwards to `install.sh` (backward compatible).
- Removed redundant/divergent files: the second detector (`detect-project.sh`) and duplicate skill
  bodies (`context-guard.md`, `git-workflow.md`).
- README/CONTRIBUTING/CLAUDE.md rewritten for accuracy (correct URLs, real feature list, the new
  architecture, troubleshooting, and hook contracts).

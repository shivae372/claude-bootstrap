# Contributing to claude-bootstrap

The goal: the best possible Claude Code setup generator, covering every major stack — and one
that actually works on a fresh machine, every time. Reliability is the product.

## Ground rules

1. **Everything is tested.** Add or update a check in `tests/run.sh` for any behavior you change.
   Run `bash tests/run.sh` locally; CI runs it on Linux + macOS for every PR.
2. **Deterministic core stays deterministic.** `install.sh`, `render.py`, hooks, and `validate.sh`
   must never require an LLM or network (except the `curl | bash` self-download).
3. **No hallucinated features.** Everything must map to real Claude Code behavior — see
   [docs/FORMATS.md](docs/FORMATS.md) and the hook contracts in [CLAUDE.md](CLAUDE.md).
4. **Hooks are safe and bypassable.** Blocking hooks (exit 2) print the reason to stderr and offer
   an env-var bypass for deliberate use.
5. **Agents stay scoped** (one job, explicit `tools`). **Skills always have a `SKILL.md`.**
   **`CLAUDE.md` stays ≤150 lines.**

## High-value contributions

- **New stack templates** in `docs/stacks/` — e.g. `flutter.md`, `elixir.md`, `dotnet.md`, `swift.md`.
  Then add detection to `.claude/skills/onboarding/scripts/detect-project.py` and a stack mapping
  in `install.sh`'s `map_stack`.
- **Better hooks / agents / skills** — include what was wrong before and a before/after.
- **More tests** — edge cases for detection, hook block/allow, installer flags.

## Local development

```bash
git clone https://github.com/shivae372/claude-bootstrap
cd claude-bootstrap

# Try the installer against a throwaway project
mkdir -p /tmp/demo && echo '{"dependencies":{"next":"14"}}' > /tmp/demo/package.json
bash install.sh --dir /tmp/demo --tier developer --yes --dry-run   # preview
bash install.sh --dir /tmp/demo --tier developer --yes             # for real
bash scripts/validate.sh                                            # (from /tmp/demo)

# Run the full suite before opening a PR
bash tests/run.sh
```

## PR format

```
## What     — one sentence: what you added/changed
## Why      — the problem it solves
## Stack    — which stack(s), or "universal"
## Tested   — OS + how you verified (and `bash tests/run.sh` passing)
```

Bump `VERSION` and add a `CHANGELOG.md` entry for user-facing changes.

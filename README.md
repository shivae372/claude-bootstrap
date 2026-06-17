# claude-bootstrap

> Give any project a professional Claude Code setup in seconds — deterministically, with zero token cost.

Claude Code is powerful, but most of that power is lost to weak configuration: no project
context, exploration that burns your context window, no guardrails, generic prompts.

`claude-bootstrap` fixes that in one command. It detects your stack and installs a curated,
**tested** Claude Code configuration — sub-agents, skills, slash-commands, safety hooks, a
tailored `CLAUDE.md`, and session continuity — tuned to how you work.

```bash
curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash
```

That's it. No LLM call, no waiting, no questionnaire to sit through. Run it inside any project
and you're set up. Prefer to read before you run? See [Install](#install) for the clone option.

---

## Why it's different

Most "AI setup" tools ask a model to *generate* your config on the fly — slow, non-deterministic,
and it often half-works. claude-bootstrap inverts that:

- **Deterministic core.** A real installer copies battle-tested components and renders your
  `CLAUDE.md` from detected facts. Same input → same output, every time. Works offline once cloned.
- **AI only where judgment helps.** Want bespoke tailoring? Run `/bootstrap` *inside* Claude Code,
  where it can actually ask questions and write files with your approval.
- **Self-tested.** Every hook, the installer, and the validator are covered by a CI test suite
  (`tests/run.sh`) that runs on Linux and macOS.

## What gets installed

| Component | What it does |
|---|---|
| **`CLAUDE.md`** | Project context — stack, commands, conventions, rules. Generated from your project, kept ≤150 lines. |
| **Sub-agents** (`.claude/agents/`) | Isolated specialists (explorer, code-reviewer, test-runner, security-scanner, dep-checker, doc-writer) that keep your main context clean. |
| **Skills** (`.claude/skills/`) | On-demand workflows Claude auto-invokes (code review, security scan, git workflow, repo analysis, …). |
| **Slash commands** (`.claude/commands/`) | One-word workflows: `/plan`, `/test`, `/review`, `/security`, `/deps`, `/ship`, `/checkpoint`, `/tips`, `/update`, `/onboard`, `/bootstrap`. |
| **Hooks** (`.claude/hooks/`) | Shell guardrails: block destructive commands, stop real secrets from being written, auto-format on save, checkpoint before compaction, resume on session start. |
| **`SESSION_STATE.md`** | Working memory. The SessionStart hook feeds it back so Claude resumes without re-explaining. |

## Install

**One-liner (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash
```

**From a clone (inspect first):**
```bash
git clone https://github.com/shivae372/claude-bootstrap
bash claude-bootstrap/install.sh --dir /path/to/your/project
```

**Common options:**
```bash
bash install.sh --tier non-dev --yes      # plain-English setup, no prompts
bash install.sh --dry-run                  # preview exactly what would be written
bash install.sh --merge                    # add only missing files; never overwrite yours
bash install.sh --no-hooks                 # skip the guardrail hooks
bash install.sh --uninstall                # remove the setup (backs up first)
bash install.sh --help                     # all options
```

The installer **backs up** any existing `.claude/` to `.claude.backup.<timestamp>` before making
changes, so re-running is always safe.

## Who it's for

| You are… | Pass | What you get |
|---|---|---|
| **Developer** (comfortable in the terminal) | `--tier developer` | Full agent set, TDD/review/security commands, git + safety hooks |
| **Founder / designer / PM** | `--tier hybrid` | Lighter agent set, plain-language workflow, the core commands |
| **Non-technical** | `--tier non-dev` | No agents, gentle plain-English skills, `/plan` + `/tips` |

Omit `--tier` and the installer asks once (or pass `--tech 1-5` to infer it).

## Supported stacks

Detection is automatic (`--stack` to override): **Next.js / React / Node**, **Python**
(Django / FastAPI / Flask), **Go**, **Rust**, **Ruby** (Rails / Sinatra), **Java**
(Spring / Quarkus), **monorepos** (Turborepo / Nx), and a sensible **no-stack** fallback for
scripts, docs, infra, and data projects.

## After install — your new workflow

```bash
claude                # start Claude Code in your project
```

| Command | Does |
|---|---|
| `/bootstrap` | Tailor the setup further, interactively (asks first, then writes) |
| `/plan` | Break a feature into an ordered checklist before coding |
| `/test` | Run the suite; get a parsed pass/fail summary |
| `/review` | Severity-ranked review of your diff |
| `/security` | Audit for auth/injection/secret issues |
| `/deps` | Vulnerability + outdated-dependency audit |
| `/ship` | Gate: tests → review → security → clean commit/PR |
| `/checkpoint` | Snapshot state into `SESSION_STATE.md` now |
| `/tips` · `/update` · `/onboard` | Tips, self-update, first-run profile |

## How it works

```
install.sh
   ├── detect stack            (deterministic; detect-project.py, bash fallback)
   ├── resolve tier            (flag, --tech, or one prompt)
   ├── back up existing .claude (timestamped)
   ├── copy curated components  (agents · skills · commands · hooks · settings)
   ├── render CLAUDE.md         (scripts/render.py ← template + detected facts)
   ├── write SESSION_STATE.md + .claude/.bootstrap.json (version marker)
   └── validate.sh             (verifies the result)
```

## Requirements

- **Claude Code** — [claude.ai/code](https://claude.ai/code)
- **bash** + **curl** — preinstalled on macOS/Linux. On Windows use **Git Bash** or **WSL**.
- **Python 3.8+** *(optional)* — improves stack detection and `CLAUDE.md` rendering; the installer
  has a pure-bash fallback if it's missing.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `curl … \| bash` blocked by a proxy | Use the clone install instead. |
| Stack detected as `no-stack` | Pass `--stack nextjs` (etc.), or run `/bootstrap` to tailor by hand. |
| A hook blocked something legitimate | One-off bypass: `CLAUDE_BOOTSTRAP_ALLOW_DANGEROUS=1` (safety) or `CLAUDE_BOOTSTRAP_ALLOW_SECRETS=1` (secrets). |
| Want to undo everything | `bash install.sh --uninstall` (backs up to `.claude.backup.<ts>`). |

## Contributing

PRs welcome — new stacks, agents, and hooks especially. Run `bash tests/run.sh` before
submitting (CI runs it on Linux + macOS). See [CONTRIBUTING.md](CONTRIBUTING.md).

## Roadmap

Ideas, not promises — the items below are not built yet:
`claude-cowork` (shared sessions) · `claude-memory-pro` (cross-project memory) ·
`claude-review-bot` (PR auto-review) · `stack-packs` (more turnkey stacks).

## License

Apache 2.0 — see [LICENSE](LICENSE). Patent grant included per the Apache 2.0 terms.

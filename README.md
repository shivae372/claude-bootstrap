# claude-bootstrap

> **A Claude Code setup that installs itself, heals itself, and teaches itself new skills as you work.**

Most people use a fraction of Claude Code's power — because configuration is hard, setups rot,
and you hit a wall the moment you need a capability you didn't pre-install.

`claude-bootstrap` makes that wall disappear. One command gives any project — and any person,
coder or not — a professional, curated setup. Then it *keeps getting more powerful on its own*:
when you ask for something it can't do yet, it searches the open ecosystem, installs the right
skill, or **forges a new one** — mid-task. It heals its own config and remembers what it learns.

### Install — pick one (30 seconds)

**A · As a Claude Code plugin (recommended).** Type these inside Claude Code:

```text
/marketplace
#  ↳ when prompted "Enter marketplace source:", type:  shivae372/claude-bootstrap
/plugin install claude-bootstrap@claude-bootstrap
/plugin install nodo@claude-bootstrap          # the codebase-map sibling
```

> **Don't see `/marketplace` (or get a "path does not exist" error)?** Your Claude Code is out of date —
> run **`claude update`** (or reinstall the latest), then retry. The `/plugin` command ships in recent versions.

**B · One-line installer (works on _any_ Claude Code version, no `/plugin` needed).** From your project folder:

```bash
curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash
```

Either way: no setup LLM call, no questionnaire — the install is instant. The *intelligence* lives in
skills, hooks, and a bundled MCP server that run inside your session.

> **Not a coder?** That's fine — run option B, then just talk to Claude normally. It sets everything up and
> asks before doing anything irreversible. **Developer?** Everything's deterministic, tested, and documented below.

**The last Claude Code setup you'll install — because it grows itself.**

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

## The living engine (self-healing · self-learning · self-extending)

The setup doesn't just get installed — it **grows itself as you work**. Modeled on the
`nodo` philosophy (the tool finds where it's blind, Claude reasons, the tool persists
deterministically — offline, validated before apply):

- **Augments in real time.** Ask for something the project can't do yet ("add Stripe
  checkout", "deploy to Fly.io") and a `UserPromptSubmit` hook notices the gap and nudges
  Claude to run **`augment`** — which searches the open ecosystem (Anthropic skills, GitHub,
  the MCP Registry, Smithery), vets candidates, and installs the best one. *Then and there.*
- **Forges what doesn't exist.** If nothing fits, **`forge`** authors a detailed,
  project-specific skill — and a validator rejects generic, unfilled stubs.
- **Heals itself.** **`doctor`** scans `.claude/` for broken skills/hooks/config, scores
  health, and applies safe fixes. Repeated tool failures trigger a heal nudge automatically.
- **Learns and remembers.** **`learn`** captures durable facts ("we use pnpm", "deploy via
  Fly") into a validated store that the `SessionStart` hook feeds back every session — so the
  project keeps its memory across sessions and compactions.
- **Works live via MCP.** A bundled stdio MCP server (`forge`) exposes `discover_skill`,
  `capability_audit`, `heal_report`, and `record_learning` as tools Claude can call mid-task.

Everything is pure-Python stdlib, offline-tolerant, and validated before anything is persisted.
Run `python3 .claude/engine/doctor.py` anytime for a health report.

## Install options & flags

(Quick install is at the top. This section is the detail for the one-line installer.)

**One-line installer:**
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

## Ecosystem — pairs with [nodo](https://github.com/shivae372/nodo)

claude-bootstrap is the *capability* layer; **nodo** is the *codebase-map* layer. They bind:
bootstrap reads nodo's architecture map at session start, reports nodo's health in `/doctor`, and
offers to install nodo the moment you ask an architecture or blast-radius question. One marketplace
ships both. See [docs/ECOSYSTEM.md](docs/ECOSYSTEM.md).

```bash
/marketplace          # when asked, enter:  shivae372/claude-bootstrap   (offers BOTH plugins)
/plugin install claude-bootstrap@claude-bootstrap
/plugin install nodo@claude-bootstrap
```

## Contributing

PRs welcome — new stacks, agents, and hooks especially. Run `bash tests/run.sh` before
submitting (CI runs it on Linux + macOS). See [CONTRIBUTING.md](CONTRIBUTING.md).

## Roadmap

Ideas, not promises — the items below are not built yet:
`claude-cowork` (shared sessions) · `claude-memory-pro` (cross-project memory) ·
`claude-review-bot` (PR auto-review) · `stack-packs` (more turnkey stacks).

## License

Apache 2.0 — see [LICENSE](LICENSE). Patent grant included per the Apache 2.0 terms.

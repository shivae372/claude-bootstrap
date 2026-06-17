# The ecosystem: claude-bootstrap + nodo

Two tools, one loop. They're designed to bind together so Claude Code always knows
**what your codebase is**, **what it can do here**, and **how to get better** — and can
diagnose all of it when something breaks.

```
            ┌─────────────────────────────┐
            │            nodo             │   "what is this codebase?"
            │  deterministic map + issues │   → .nodo/nodo-context.{json,md}
            └──────────────┬──────────────┘
                           │  architecture map (read at session start)
                           ▼
            ┌─────────────────────────────┐
            │       claude-bootstrap      │   "what can Claude do here, and
            │  augment · forge · doctor   │    how does it keep improving?"
            │  · learn · hooks · MCP      │
            └─────────────────────────────┘
```

## How they bind

| Direction | Binding |
|---|---|
| nodo → bootstrap | `session-start.sh` injects `.nodo/nodo-context.md` as session context — Claude starts every session with the architecture map **next to** the capability manifest and learnings. |
| bootstrap → nodo | `doctor.py` reports nodo's status (installed? map present? stale?) so nodo is **transparent** to Claude. The real-time gap hook routes architecture/blast-radius questions ("what calls X", "what breaks if I change Y") to nodo, and offers to install it if absent. |
| shared | One marketplace (`/plugin marketplace add shivae372/claude-bootstrap`) offers **both** plugins. |

## Division of labour (both follow the same philosophy)

Both are **deterministic, offline scaffolds; Claude is the reasoning layer.** nodo extracts
the graph/symbols/issues with zero guessing; claude-bootstrap discovers/forges/heals capabilities
and persists learnings. Neither calls an LLM to do its core job — so results stay grounded,
private, and reproducible.

## Diagnosing the ecosystem

Everything is transparent to Claude Code so it can self-diagnose:

```bash
python3 .claude/engine/doctor.py            # bootstrap health + nodo status, with fixes
python3 .claude/engine/doctor.py --manifest # installed skills/commands/agents/hooks + nodo state
python  nodo.py . --self-check              # nodo's own blind-spot report (then --teach to fix)
```

## Get both

```bash
/plugin marketplace add shivae372/claude-bootstrap
/plugin install claude-bootstrap@claude-bootstrap
/plugin install nodo@claude-bootstrap
```

Or the deterministic installer for bootstrap + clone nodo:

```bash
curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash
git clone https://github.com/shivae372/nodo && python nodo/nodo.py . --install
```

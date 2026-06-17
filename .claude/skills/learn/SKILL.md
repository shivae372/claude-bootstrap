---
name: learn
description: "Makes the setup remember. Captures durable, project-specific learnings — user preferences, stack facts, conventions, fixes, recurring gaps — so every future session starts smarter (they're injected at SessionStart). Use when you discover something about how THIS project or user works that should persist. Triggers: 'remember that…', 'from now on…', 'we always/never…', or right after you learn a non-obvious project fact."
allowed-tools: Bash, Read
version: 1.0.0
---

## Purpose
Turn one-off discoveries into permanent context. Mirrors how a good teammate stops
needing to be re-told things. Storage is local, validated, and bounded — never networked.

## When to use this
- The user states a preference or rule ("deploy via Fly, not Vercel"; "never touch
  the legacy/ dir"; "we use pnpm").
- You uncover a non-obvious project fact, a convention, or a fix worth keeping.
- After `augment`/`forge`/`doctor` change the setup, record what changed.

## Steps

### 1. Distill ONE atomic learning
Write a single, specific sentence. Pick a `category`:
`preference` · `stack` · `convention` · `workflow` · `fix` · `gap` · `fact`.

### 2. Persist it (validated before it becomes durable)
```bash
echo '{"category":"preference","text":"User prefers TypeScript strict mode everywhere","tags":["ts"]}' \
  | python3 .claude/engine/learn.py add
```
The store rejects empty/oversized text or a bad category (the "heal-safely" gate) and
de-dupes identical entries. It auto-renders `.claude/memory/learnings.md`.

### 3. Review when useful
```bash
python3 .claude/engine/learn.py list
```

## How it comes back
The SessionStart hook runs `learn.py inject` and feeds `learnings.md` to Claude as
additional context at the start of every session — so the project keeps its memory
across sessions and compactions, with zero effort from the user.

## Output
A new entry in `.claude/memory/learnings.json` + the refreshed `learnings.md`, and a
one-line confirmation of what was remembered.

## Guardrails
- Keep each learning atomic and durable — not transient task state (that belongs in
  SESSION_STATE.md). One fact per entry.
- Never store secrets or credentials as learnings.

---
name: tips
description: "Surfaces a few high-leverage, context-aware tips for getting more out of Claude Code. Self-contained (no external data file). Invoked by /tips, by analyze-repo at the end of a scan, or when the user asks how to use Claude better."
allowed-tools: Read
---

## Purpose
Teach the user 3–5 high-impact habits, chosen to fit their tech level and what this project
actually has. Tips live in this file (no external `tips.json` needed).

## When To Use This
- The user runs `/tips` or asks "how do I get better at this / what am I doing wrong?"
- `analyze-repo` calls it at the end of a scan (show only 2–3, the most relevant)

## Steps
1. If `USER_PROFILE.json` exists, read `tech_level` and `primary_goals` to bias selection;
   otherwise assume tech_level 3.
2. Look at the project: are there tests? agents? a long CLAUDE.md? a SESSION_STATE.md?
3. Pick 3–5 tips from the catalog below, preferring ones the user can act on right now.
4. Present them scannably: a bold category, the tip, and a one-line `→ example`.

## Tip Catalog

**Tokens / context** (tech 1–5)
- 💡 Delegate exploration to the `explorer` sub-agent — its context is isolated, so reading a
  big codebase doesn't bloat your main session. → "explore where auth is handled"
- 💡 Ask for targeted reads, not whole files. → "show lines 40–80 of server.ts", not "open server.ts"
- 💡 `/compact` (or let the PreCompact hook checkpoint) before starting a new sub-task.

**Workflow** (tech 2–5)
- 💡 `/plan` before building anything non-trivial — agree on scope first. → "/plan add OAuth login"
- 💡 `/ship` before committing — it gates tests + review + security in one pass.
- 💡 Keep `SESSION_STATE.md` current so a fresh session resumes instantly (the SessionStart hook reads it).

**Quality** (tech 3–5)
- 💡 `/review` your diff before opening a PR; fix 🔴/🟠 findings first.
- 💡 Put hard rules in hooks, not just CLAUDE.md — hooks are 100% reliable, prose is ~70%.

**Prompting** (tech 1–4)
- 💡 State the goal AND the constraints. → "add caching, but don't change the public API"
- 💡 When output is wrong, say what you expected — don't just say "no". 

**Safety** (tech 1–5)
- 💡 The safety-check + secret-detector hooks have your back, but still review destructive commands.
- 💡 Never paste real secrets into chat — reference `process.env.X` / `os.environ["X"]` instead.

## Notes
- From `analyze-repo`, show only 2–3 and label them "Quick wins for this setup".
- Don't repeat the same tips every time; vary by category.

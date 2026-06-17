---
name: augment
description: "Gives this project a NEW capability on demand. Use the moment the user needs something the current setup can't do well — a new framework, a service integration (Stripe, Postgres, Twilio…), a deploy target, a niche workflow. Searches the open ecosystem for a fitting skill/MCP across platforms, installs the best vetted one, and if nothing fits, forges a bespoke skill. Triggers: 'can you also…', 'I need to…', 'set up…', 'integrate…', 'how do I … here', or any task with no matching installed skill."
allowed-tools: Bash, Read, Write, Edit, WebFetch
version: 1.0.0
---

## Purpose
Close the gap between what the user wants and what this setup can do — in the moment,
without them leaving the conversation. This is the engine that makes a fresh Claude
Code project grow into exactly the toolkit THIS user needs.

## When to use this
- The user asks for a capability with no matching skill/command/agent (check the
  capability manifest: `python3 .claude/engine/doctor.py --manifest`).
- A `[gap]` nudge was injected by the real-time hook (`.claude/state/needs.jsonl`).
- The user explicitly says "augment", "find a skill for…", "add support for…".

## Steps

### 1. Name the capability precisely
Restate what's missing as a short search phrase (e.g. "stripe payments",
"deploy to fly.io", "supabase row level security"). Confirm with the user in one line.

### 2. Search the open ecosystem (across platforms)
```bash
python3 .claude/engine/skill_finder.py "<capability>" --json
```
This queries, in parallel and offline-tolerant: Anthropic's official skills,
GitHub (topic + repo search), the MCP Registry, and Smithery (if `SMITHERY_API_KEY`
is set). Results come back ranked by relevance with a `trust` score and `flags`.
Set `GITHUB_TOKEN` first if available — it lifts GitHub's rate limit.

### 3. Vet before you trust (never auto-install blindly)
Reject or down-rank a candidate that is: brand-new (<30d) with no stars, has a vague
or missing description, grants `Bash` with no constraint, or fetches remote code at
runtime. Prefer: official (`anthropic/skills`), `verified` (Smithery), pinned commit
SHAs, and repos with real usage. Show the user the top 1–3 with their trust/flags and
let them pick when it's a close call.

### 4a. Install a good match
- **Official skill / plugin:** `/plugin marketplace add <owner/repo>` then `/plugin install <name>@<marketplace>`.
- **MCP server:** `claude mcp add <name> ...` (it activates next session — tell the user).
  Record it in `.mcp.json` so the team gets it too.
- **A SKILL.md in a repo:** fetch it, read it end-to-end, then write it into
  `.claude/skills/<name>/SKILL.md`. Validate: `python3 .claude/engine/skill_forge.py validate <path>`.

### 4b. Nothing fits → forge it
Invoke the **forge** skill to author a detailed, project-specific skill. Do NOT settle
for a generic one — a vague skill is worse than none.

### 5. Make it real now, then learn
- Verify the new capability works (run it once if safe).
- Record what you added so the setup remembers:
```bash
echo '{"category":"stack","text":"Added <capability> via <skill/mcp>","tags":["augment"]}' \
  | python3 .claude/engine/learn.py add
```
- Tell the user the new command/skill is live and how to use it.

## Output
A new, working capability in `.claude/` (skill, command, or MCP server), vetted and
validated, plus a one-line summary of what was added and how to invoke it.

## Guardrails
- Never install a skill you haven't read. Never run a skill's setup script without
  inspecting it. Surface trust flags honestly.
- If discovery returns nothing and the domain is unfamiliar, ask the user one
  clarifying question rather than forging something generic.

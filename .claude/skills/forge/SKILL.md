---
name: forge
description: "Authors a NEW, project-specific Claude Code skill from scratch when the ecosystem has nothing that fits. Use after `augment` finds no good match, or when the user wants a custom workflow captured as a reusable skill. Produces a detailed, validated skill — never a generic stub. Triggers: 'make a skill for…', 'turn this into a skill', 'I keep doing X, automate it'."
allowed-tools: Bash, Read, Write, Edit
---

## Purpose
Capture a capability as a durable, high-quality skill tailored to THIS codebase.
The deterministic scaffolder guarantees structure and validity; you supply the real,
specific substance. A generic skill is a failed skill.

## When to use this
- `augment` searched the ecosystem and nothing good fit.
- The user has a repeatable, project-specific workflow worth making one-command.

## Steps

### 1. Understand the task deeply FIRST
Before writing anything, learn how this project actually does the thing:
- Read the relevant files (configs, scripts in `package.json`/`Makefile`/`pyproject`,
  existing patterns). Use the `explorer` agent for big repos.
- Identify the EXACT commands, file paths, env vars, and success checks involved.
  Specificity here is the whole point.

### 2. Scaffold a valid skeleton
```bash
python3 .claude/engine/skill_forge.py scaffold \
  --name <kebab-name> \
  --description "<what it does> + Use when <concrete triggers>" \
  --allowed-tools "Bash, Read"
```
This writes `.claude/skills/<name>/SKILL.md` with the right frontmatter and the
section skeleton (Purpose / When to use / Steps / Output / Guardrails / References),
plus `scripts/` and `references/` dirs.

### 3. Fill it with REAL detail (replace every placeholder)
Edit the SKILL.md so the Steps are the actual procedure for this project:
- Real commands with the real flags (`pnpm test --filter web`, `fly deploy --remote-only`…).
- Real file paths and expected outputs.
- A concrete success check and explicit guardrails (what it must never do).
- Long reference material → drop into `references/` and link it (progressive disclosure).
- If the skill needs a helper, write it into `scripts/` and call it from the steps.

### 4. Validate — the quality gate
```bash
python3 .claude/engine/skill_forge.py validate .claude/skills/<name>/SKILL.md
```
It FAILS if placeholders remain or the body is too thin. Do not finish until it passes.

### 5. Prove it, then learn
Run the new skill once on a real (safe) case to confirm it works. Then record it:
```bash
echo '{"category":"workflow","text":"Forged skill <name>: <one-line what it does>","tags":["forge"]}' \
  | python3 .claude/engine/learn.py add
```

## Output
A validated `.claude/skills/<name>/SKILL.md` (plus any `scripts/`), specific to this
project, ready to auto-invoke — and a note to the user on how to trigger it.

## Guardrails
- Never ship a skill that still contains skeleton placeholders (the validator blocks this).
- One skill = one job. If it's growing two jobs, forge two skills.
- Keep the body lean; push detail into `references/`.

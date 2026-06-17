---
name: doctor
description: "Self-heals this project's Claude Code setup. Diagnoses broken or missing pieces — skills with no SKILL.md, hooks referenced but absent or non-executable, invalid settings.json, bloated CLAUDE.md — scores health, and applies safe fixes. Use when something in the setup seems off, after edits to .claude/, when a hook or skill isn't firing, or on a `[heal]` nudge. Triggers: 'is my setup ok', 'fix my claude setup', 'why isn't my skill/hook working', '/doctor'."
allowed-tools: Bash, Read, Edit, Write
version: 1.0.0
---

## Purpose
Keep the setup healthy without the user having to understand its internals. The
diagnosis is fully deterministic (no guessing); repairs are explicit and safe.

## When to use this
- A hook/skill/command isn't behaving, or the user edited `.claude/` by hand.
- A `[heal]` nudge appeared (a tool failed repeatedly — see `.claude/state/failures.jsonl`).
- Proactively after `augment`/`forge` writes new config.

## Steps

### 1. Diagnose
```bash
python3 .claude/engine/doctor.py --json
```
Returns `{score, errors, warnings, findings[]}`. Each finding has `where`, `problem`,
`fix`, and `auto_fixable`.

### 2. Apply the safe auto-fixes
```bash
python3 .claude/engine/doctor.py --apply
```
This performs only non-destructive repairs (e.g. `chmod +x` hooks). Everything else
is left to you with a precise fix string.

### 3. Repair the rest, in order of severity
- **error** first (a missing hook reference, a skill with no SKILL.md, invalid JSON).
  Fix the root cause: restore/author the file, correct the JSON, or remove the dead
  reference. For a skill dir missing SKILL.md, use `forge` (or delete it if obsolete).
- **warn** next (non-executable hook already covered by --apply; oversized CLAUDE.md →
  trim and move detail into skills; agent missing frontmatter → add it).
- **info** as time allows.

### 4. Re-check and learn
Re-run the diagnosis until `errors: 0`. If a failure pattern recurs, record it so the
setup avoids it next time:
```bash
echo '{"category":"fix","text":"<what was broken> → <how fixed>","tags":["heal"]}' \
  | python3 .claude/engine/learn.py add
```

## Output
A health score and a clean before/after: what was broken, what was auto-fixed, what
you repaired, ending at 0 errors.

## Guardrails
- Auto-fix is safe-only; never delete user content to "fix" a finding without asking.
- If a finding's root cause is ambiguous, show the user the finding and the proposed
  fix before applying it.

---
name: onboarding
description: "First-run user onboarding. Asks 6 quick questions, detects the project, writes USER_PROFILE.json, and recommends the right setup tier. Auto-activates on first use or when the user says 'set me up', 'I'm new', or runs /onboard."
allowed-tools: Read, Write, Bash
version: 1.0.0
---

## Purpose
Collect just enough about the person and their project to tailor the Claude Code setup, then
write `USER_PROFILE.json` and route to the right tier (developer / hybrid / non-dev).

## When To Use This
- The user runs `/onboard`, says they're new, or asks to be set up
- No `USER_PROFILE.json` exists yet and the user wants `/bootstrap`

## Steps

### 1. Greet briefly
> "I'll ask 6 quick questions so Claude Code fits how YOU work — about 2 minutes, once."

### 2. Ask the 6 questions ONE AT A TIME (wait for each answer)
1. **Role** — developer, founder, designer, PM, data, student, other?
2. **Comfort with code/terminal (1–5)** — 1 = avoid the terminal … 5 = senior engineer.
3. **Team** — solo / small (2–5) / larger?
4. **Domain** — software / design / ops / marketing / research / other?
5. **Top 1–3 goals** — e.g. "ship faster", "automate reports", "learn to code".
6. **Success in 30 days** — one sentence.

### 3. Detect the project (no interaction)
```bash
python3 .claude/skills/onboarding/scripts/detect-project.py --target . --output /tmp/detected.json
```
If it fails, treat detection as `{"has_project": false}`.

### 4. Write the profile
```bash
echo '<answers_json>' | python3 .claude/skills/onboarding/scripts/write-profile.py \
  --detected /tmp/detected.json --output USER_PROFILE.json
```
`<answers_json>` keys: `role_type`, `tech_level` (int 1–5), `team_size` (solo|small|large),
`domain`, `primary_goals` (array), `success_in_30_days`.

### 5. Recommend the tier
Read `generation_tier` from `USER_PROFILE.json` and tell the user which tier fits, then point
them to `/bootstrap` (or to `bash install.sh --tier <tier>` if they prefer the deterministic path).

## Output
Writes `USER_PROFILE.json` and prints a short summary (role, tech level, tier, detected stack).

## Notes
- If a profile already exists, ask whether to update or keep it — never silently overwrite.
- If an answer is ambiguous, ask one quick follow-up rather than guessing.

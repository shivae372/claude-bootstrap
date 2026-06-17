---
description: First-run onboarding — a few quick questions to tailor Claude Code to how you work.
allowed-tools: Read, Write, Bash
---

Run the first-run onboarding. Use the `onboarding` skill if present.

Ask the questions ONE at a time (role, comfort with code 1–5, solo/team, domain, top goals,
what success looks like in 30 days), detect the project, then write `USER_PROFILE.json` via
`.claude/skills/onboarding/scripts/write-profile.py`. Finish by recommending the right tier and
pointing the user to `/bootstrap`. If a profile already exists, offer to update or keep it.

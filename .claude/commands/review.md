---
description: Structured code review of your current changes, organized by severity.
argument-hint: "[optional: file/path; default = uncommitted diff]"
allowed-tools: Bash, Read
---

Review code for correctness, security, performance, and project conventions.

Scope: ${ARGUMENTS:-the current uncommitted diff (git diff HEAD)}.

1. Read project conventions from `CLAUDE.md` first.
2. Get the diff/files (`git diff HEAD`, `git diff --cached`, or the path in $ARGUMENTS).
3. Use the `code-review` skill / `code-reviewer` agent if present (keeps context clean).
4. Present findings grouped as 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low, each with file:line,
   the problem, and a concrete fix. End with a verdict: Approved / Needs changes / Blocking.
5. Offer to fix the issues one at a time, re-reviewing each fix.

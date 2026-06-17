---
description: Break a feature or task into a concrete, ordered checklist before any code is written.
argument-hint: "<what you want to build>"
allowed-tools: Read, Glob, Grep
---

Plan this work before touching code: **$ARGUMENTS**

1. Restate the goal in one sentence so we agree on scope.
2. If a `task-planner` agent exists, dispatch it; otherwise plan inline.
3. Produce an ordered checklist of small, verifiable steps. For each: the files likely involved
   and how we'll know it's done (test, behavior, or check).
4. Call out unknowns, risks, and anything that needs a decision from the user first.
5. End with the smallest sensible first step and ask whether to proceed.

Do not write code in this command — planning only.

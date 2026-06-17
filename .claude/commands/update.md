---
description: Check whether this project's claude-bootstrap setup is current and apply updates safely.
allowed-tools: Bash, Read, Edit
---

Check for and apply claude-bootstrap updates.

1. Use the `self-update` skill if present.
2. Read the installed version from `.claude/.bootstrap.json` (`bootstrap_version`).
3. Compare against the source repo's `VERSION` (github.com/shivae372/claude-bootstrap).
4. Show what changed (CHANGELOG/commits) in plain language before touching anything.
5. Apply only what the user approves. Never overwrite a customized CLAUDE.md or SESSION_STATE.md
   without explicit confirmation; back up files before replacing them.

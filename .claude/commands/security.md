---
description: Security audit of recent changes or a target area — auth, injection, secrets, data exposure.
argument-hint: "[optional: area, e.g. 'auth' or a path; default = recent changes]"
allowed-tools: Bash, Read
---

Run a security audit. Scope: ${ARGUMENTS:-files changed since the last commit}.

1. Use the `security-scan` skill / `security-scanner` agent if present.
2. Check for: missing authn/authz checks, injection (SQL/command/template), hardcoded
   secrets, sensitive data in logs/responses, missing input validation, and insecure defaults.
3. Report a Risk Level (CRITICAL/HIGH/MEDIUM/LOW/CLEAN) and findings by severity with fixes.
4. If anything CRITICAL is found, lead with: "⛔ Do not deploy until fixed:" and the exact fix.

---
description: Pre-ship gate — run tests, review the diff, security-check, then prepare a clean commit/PR.
argument-hint: "[optional: short description of the change]"
allowed-tools: Bash, Read
---

Take this change from "done coding" to "ready to ship": ${ARGUMENTS:+ ($ARGUMENTS)}

Run as a gated checklist and STOP at the first hard failure:

1. **Tests** — run the suite (prefer the `test-runner` skill). If anything fails, stop and report.
2. **Review** — structured review of the diff (prefer the `code-review` skill). Surface 🔴/🟠 issues.
3. **Security** — quick scan of the diff (prefer `security-scan`). Block on anything CRITICAL.
4. **Secrets** — confirm no credentials are staged: `git diff --cached | grep -iE "api_key|secret|password|token|sk-|AKIA"`.
5. **Commit/PR** — if all green, use the `git-workflow` skill to craft a conventional-commit message
   and (if asked) a PR description. Show the commands; run them only if the user says go.

Report a single ✅/❌ verdict line at the end. Never push to main/master directly.

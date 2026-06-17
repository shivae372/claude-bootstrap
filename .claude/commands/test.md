---
description: Run the project's test suite and report a clean pass/fail summary (raw output stays out of context).
argument-hint: "[optional: file or test name to scope to]"
allowed-tools: Bash
---

Run tests${ARGUMENTS:+ scoped to: $ARGUMENTS}.

- Prefer the `test-runner` skill/agent if present so raw output never floods the main context.
- Otherwise detect the runner (jest/vitest/pytest/go test/cargo test/rspec) from the project and run it.
- If a scope was given ($ARGUMENTS), run only that file/test.
- Report: `✅ N passed | ❌ M failed | ⏭️ K skipped`, then list each failure as
  `test name → reason`, and propose the single most likely fix for the first failure.
- Never paste raw test output — always parse and summarize.

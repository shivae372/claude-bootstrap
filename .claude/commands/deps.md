---
description: Audit dependencies for vulnerabilities and outdated packages, with exact fix commands.
allowed-tools: Bash
---

Audit this project's dependencies.

1. Use the `dep-check` skill / `dep-checker` agent if present.
2. Otherwise run the native auditor for the stack: `npm audit` / `pnpm audit` / `yarn npm audit`,
   `pip-audit`, `cargo audit`, `govulncheck`, or `bundle audit` — whichever matches.
3. Report: Risk (CRITICAL/HIGH/MEDIUM/CLEAN), security vulns with CVE + fix command, major
   updates needing manual review, and safe minor/patch updates.
4. Give the exact commands to apply safe fixes. Flag breaking upgrades separately.

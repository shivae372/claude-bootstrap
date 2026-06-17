# {{PROJECT_NAME}} — Claude Code Setup

## Stack
{{STACK}}

## Key Commands
- **Install:** `{{INSTALL_CMD}}`
- **Dev server:** `{{DEV_CMD}}`
- **Test:** `{{TEST_CMD}}`
- **Build:** `{{BUILD_CMD}}`

## Project Structure
{{PROJECT_STRUCTURE}}

## Agents Available
- **explorer** — Read-only codebase exploration (Haiku, fast)
- **test-runner** — Runs test suite, reports failures (Haiku)
- **code-reviewer** — Reviews diffs for bugs and security issues (Sonnet)
- **security-scanner** — Auth/injection/secret audit (Sonnet)
- **dep-checker** — Dependency vulnerability + outdated audit (Haiku)

## Workflow
1. New feature → `/plan` to create a task list
2. Exploration → dispatch the `explorer` agent (never read whole files yourself)
3. Tests → `/test` before committing
4. Review → `/review` before opening a PR
5. Ship → `/ship` (gates tests + review + security, then a clean commit)

## Hard Rules
- Never read entire files when a targeted search works
- Never run `{{INSTALL_CMD}}` without confirming package changes
- Always check `{{TEST_CMD}}` passes before marking work done
- Commit atomically — one logical change per commit

## Commands Available
- `/plan` — Create a task breakdown
- `/test` — Run the test suite
- `/review` — Code review the current diff
- `/security` — Security audit
- `/deps` — Dependency audit
- `/ship` — Pre-ship gate, then commit/PR
- `/checkpoint` — Save session state now

## SESSION_STATE.md
Read it at session start (the SessionStart hook surfaces it automatically). Keep it current.

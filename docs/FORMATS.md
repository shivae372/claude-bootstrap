# File Format Specifications

This document defines the exact format Claude must follow when generating files during bootstrap.
Claude reads this file as part of Step 3 of the bootstrap process.

---

## Sub-agent Format (`.claude/agents/NAME.md`)

```markdown
---
name: agent-name
description: One or two sentences. This is how Claude decides when to auto-delegate. Be specific about trigger conditions: "Use when the user asks to review code, inspect a diff, or check for bugs." Vague descriptions cause missed delegations.
model: haiku          # haiku for read-only/fast tasks, sonnet for complex reasoning
tools: Read, Glob, Grep   # ONLY tools this agent actually needs
memory: user          # include if agent needs to accumulate project knowledge across sessions
---

You are a [role] specialist. Your job is exactly this: [one sentence].

## What You Do
[2-3 bullet points. No more.]

## What You Do NOT Do
[1-2 bullet points. Explicitly scope the agent out of adjacent tasks.]

## Output Format
Always return your output as:
```json
{
  "status": "complete|failed|blocked",
  "summary": "2-3 sentence summary of findings",
  "findings": [...],
  "recommended_action": "..."
}
```
This output is read by the orchestrator. Be concise. Never dump raw file content.

## Memory Instructions
[Only include if memory: user is set]
After each session, update your MEMORY.md with:
- Key files you discovered and what they do
- Patterns and conventions you observed
- Issues you found and their resolution status
```

### Agent Rules
- Name must be lowercase with hyphens: `code-reviewer`, not `CodeReviewer`
- `tools` must be an explicit list — never omit this field (defaults to all tools if omitted, which wastes permissions)
- Haiku for: file reading, searching, running tests, checking deps — anything fast and read-heavy
- Sonnet for: code review, writing, reasoning, security analysis
- Max system prompt body: 400 lines. Extract reusable content into a skill and reference it with `skills: [skill-name]`
- One agent = one job. If you're tempted to add a second job, make a second agent.

---

## Skill Format (`.claude/skills/NAME/SKILL.md`)

```markdown
---
name: skill-name
description: Clear description of what this skill does and when Claude should auto-invoke it. Example: "Provides structured code review workflow. Auto-activates when user asks to review code, check a PR, or inspect changes."
allowed-tools: Read, Bash
# invocation: auto    # omit for both auto+manual; set to "user" for manual-only
version: 1.0.0
---

## Purpose
One paragraph. What problem does this skill solve?

## When To Use This
- [Trigger condition 1]
- [Trigger condition 2]

## Steps
[Numbered list of exactly what Claude does when this skill is invoked]

1. Step one
2. Step two
3. ...

## Output
Describe what the output looks like. If it writes a file, name the file. If it prints a summary, show the format.

## Notes
Any important caveats, edge cases, or things Claude must NOT do.
```

### Skill Rules
- Skill directory name = slug: `.claude/skills/code-review/SKILL.md`
- `name` in frontmatter must match directory name
- Add supporting scripts to `.claude/skills/NAME/scripts/` — reference via Bash tool
- Add reference docs to `.claude/skills/NAME/references/` — Claude loads on demand
- Keep SKILL.md under 5000 words. Longer content goes in `references/`
- Skills with `allowed-tools` override the main session's tool permissions for their duration
- Skills are NOT agents — they run in the main context. For isolated execution, use `fork: agent-name` in frontmatter to run in a subagent

---

## Hooks Format (`.claude/settings.json`)

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/format.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/safety-check.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/notify.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/hooks/checkpoint.sh"
          }
        ]
      }
    ]
  }
}
```

### Hook Events Reference
| Event | When it fires | Common use |
|---|---|---|
| `PreToolUse` | Before Claude uses any tool | Block dangerous commands, validate inputs |
| `PostToolUse` | After Claude uses a tool | Auto-format, log changes, trigger tests |
| `Notification` | When Claude needs user input | Desktop notifications |
| `PreCompact` | Before context compaction | Save state to SESSION_STATE.md |
| `Stop` | When Claude finishes a task | Summary notification, cleanup |

### Hook Script Contract
Hooks receive JSON on **stdin** (never positional args):
```json
{
  "tool_name": "Bash",
  "tool_input": {"command": "rm -rf node_modules"},
  "session_id": "..."
}
```

- To **block** an action (PreToolUse): exit code `2` with the reason on **stderr** — Claude Code
  surfaces stderr to the model on a blocking exit. (Printing to stdout is shown to the user, not fed back.)
- To **allow**: exit `0`.
- To **inject context** (e.g. SessionStart): exit `0` and print JSON with
  `hookSpecificOutput.additionalContext`.

**Write-path keys differ by tool** — extract content accordingly:
| Tool | Where the written content lives |
|---|---|
| `Write` | `tool_input.content` |
| `Edit` | `tool_input.new_string` |
| `MultiEdit` | `tool_input.edits[].new_string` |

**Event-specific payloads:** `PreCompact` carries `trigger` and `custom_instructions` — it does
**not** include `tool_name`/`tool_input`, so never gate PreCompact logic on a tool name.

---

## Slash Command Format (`.claude/commands/NAME.md`)

A command is a Markdown prompt with optional YAML frontmatter. Invoked as `/NAME [args]`.

```markdown
---
description: One line shown in the command menu (required for discoverability).
argument-hint: "[what to pass]"        # optional
allowed-tools: Bash, Read              # optional — restrict tools for this command
model: sonnet                          # optional
---

The prompt Claude runs when you type /NAME.
Use $ARGUMENTS for everything after the command, or $1, $2 for positional args.
```

### Command Rules
- File name = command name: `.claude/commands/review.md` → `/review`.
- Keep the body an instruction to Claude, not prose for humans.
- Commands compose skills/agents — e.g. `/review` should prefer the `code-review` skill if present.
- `${ARGUMENTS:-default}` gives a sensible fallback when the user passes nothing.

---

## CLAUDE.md Format (Root)

```markdown
# [Project Name]

## Stack
- [Framework + version]
- [Database]
- [Key libraries]

## Directory Map
- `/src` — [what lives here]
- `/api` — [what lives here]
- `/tests` — [what lives here]

## Conventions
- [Code style conventions]
- [Naming conventions]
- [Branch naming]
- [Commit message format]

## Commands
- `[run command]` — start dev server
- `[test command]` — run tests
- `[build command]` — build for production

## Agents Available
- `explorer` — Use for codebase search (runs in isolated context)
- `code-reviewer` — Use for reviewing changes
- [etc.]

## Skills Available
- `/code-review` — Structured code review
- `/git-workflow` — Git commit/PR workflow
- [etc.]

## NEVER
- [Hard rule 1 — something Claude must never do in this project]
- [Hard rule 2]

## SESSION_STATE.md
Always check `SESSION_STATE.md` at the start of a new session. It contains the latest summary of what was happening. Update it when you complete a significant task.
```

### CLAUDE.md Rules
- **Hard limit: 150 lines.** Claude's instruction-following degrades uniformly past ~200 total instructions (including its own system prompt which already uses ~50 slots).
- No workflow instructions in CLAUDE.md — those go in skills
- No agent system prompts in CLAUDE.md — those go in `.claude/agents/`
- Every "NEVER" rule is a candidate for a hook instead (hooks are 100% reliable, CLAUDE.md is ~70%)
- Nested CLAUDE.md files in subdirectories append to root — use for directory-specific conventions

---

## SESSION_STATE.md Format (Root)

```markdown
# Session State
*Last updated: [timestamp by hook]*

## Current Task
[What was being worked on]

## Completed This Session
- [Item 1]
- [Item 2]

## Pending / Blocked
- [Item 1]

## Key Decisions Made
- [Decision and reason]

## Files Modified
- [filepath] — [what changed]

## Agent Output Summaries
### code-reviewer (last run)
[JSON summary from agent]

### test-runner (last run)  
[JSON summary from agent]
```

---

## Generated Directory Layout

```
your-project/
├── CLAUDE.md                          ← orchestrator instructions (≤150 lines)
├── SESSION_STATE.md                   ← agent output summaries, session continuity
├── .claude/
│   ├── settings.json                  ← hooks configuration
│   ├── agents/
│   │   ├── explorer.md               ← read-only Haiku explorer
│   │   ├── code-reviewer.md          ← diff reviewer
│   │   ├── test-runner.md            ← test executor
│   │   ├── doc-writer.md             ← documentation agent
│   │   ├── security-scanner.md       ← security audit agent
│   │   └── dep-checker.md            ← dependency checker
│   ├── skills/
│   │   ├── git-workflow/
│   │   │   └── SKILL.md
│   │   ├── code-review/
│   │   │   └── SKILL.md
│   │   ├── context-guard/
│   │   │   └── SKILL.md
│   │   ├── analyze-repo/
│   │   │   └── SKILL.md
│   │   ├── test-runner/
│   │   │   └── SKILL.md
│   │   └── security-scan/
│   │       └── SKILL.md
│   └── hooks/
│       ├── format.sh                  ← auto-formatter (PostToolUse)
│       ├── safety-check.sh            ← dangerous command blocker (PreToolUse)
│       ├── checkpoint.sh              ← state saver (PreCompact)
│       ├── notify.sh                  ← desktop notification (Notification)
│       └── secret-detector.sh         ← blocks writing secrets (PreToolUse/Write)
└── src/
    └── CLAUDE.md                      ← scoped instructions for /src (optional)
```

---

## Template Library

The bootstrap uses a tiered template system based on `USER_PROFILE.json → generation_tier`.

### Directory Structure

```
docs/
├── stacks/              # Stack-specific configurations
│   ├── nextjs.md        # Next.js + TypeScript
│   ├── python.md        # Python (Django/FastAPI/Flask)
│   ├── go.md            # Go (Gin/Echo/Fiber/Chi)
│   ├── rust.md          # Rust (Axum/Actix/Rocket)
│   ├── ruby.md          # Ruby (Rails/Sinatra)
│   ├── java.md          # Java (Spring Boot/Quarkus)
│   ├── monorepo.md      # Turborepo/Nx monorepos
│   └── no-stack.md      # Fallback for undetected stacks
└── templates/
    ├── README.md         # Template system overview
    ├── developer/        # tier: developer (tech_level 4-5)
    │   ├── CLAUDE.md.tpl
    │   ├── agents.md
    │   └── hooks.md
    ├── hybrid/           # tier: hybrid (founders, designers, PM)
    │   ├── CLAUDE.md.tpl
    │   ├── agents.md
    │   └── hooks.md
    ├── non-dev/          # tier: non-dev (tech_level 1-2)
    │   ├── CLAUDE.md.tpl
    │   └── skills.md
    └── agents/           # Reusable agent templates
        ├── task-planner.md
        ├── product-advisor.md
        ├── launch-planner.md
        ├── content-writer.md
        ├── data-analyst.md
        └── presentation-agent.md
```

### How Template Selection Works

1. Bootstrap reads `USER_PROFILE.json` → `generation_tier`
2. Selects `docs/templates/<tier>/` directory
3. Reads the matching stack from `docs/stacks/<stack>.md` (if detected)
4. Merges tier template + stack config
5. Substitutes `{{VARIABLE}}` placeholders with detected values
6. Writes final files to user's `.claude/` directory

### Template Variables Reference

| Variable | Source | Example |
|----------|--------|---------|
| `{{PROJECT_NAME}}` | Directory name or package.json name | `my-saas-app` |
| `{{STACK}}` | detect-project.py output | `Next.js, Supabase, Tailwind` |
| `{{LANGUAGE}}` | detect-project.py output | `typescript` |
| `{{PACKAGE_MANAGER}}` | Lockfile detection | `pnpm` |
| `{{TEST_CMD}}` | Stack template or package.json scripts | `pnpm test` |
| `{{DEV_CMD}}` | Stack template or package.json scripts | `pnpm dev` |
| `{{BUILD_CMD}}` | Stack template or package.json scripts | `pnpm build` |
| `{{INSTALL_CMD}}` | Package manager detection | `pnpm install` |
| `{{DEPLOY_TARGET}}` | CI/CD detection | `Vercel` |
| `{{TECH_LEVEL}}` | USER_PROFILE.json | `4` |
| `{{ROLE}}` | USER_PROFILE.json | `developer` |
| `{{GOALS}}` | USER_PROFILE.json | `ship faster, save tokens` |
| `{{PROJECT_DESCRIPTION}}` | Inferred or from README | `SaaS app for...` |
| `{{KEY_FILES}}` | detect-project.py output | `src/app/, src/api/` |
| `{{PROJECT_STRUCTURE}}` | Inferred from directory scan | `app/, components/, lib/` |

### Adding New Stack Templates

To add support for a new stack, create `docs/stacks/<name>.md` with:

```markdown
# <Stack Name> — Bootstrap Configuration

## Detection
- [file/pattern that indicates this stack]

## Key Commands
\`\`\`yaml
install_cmd: "..."
dev_cmd: "..."
test_cmd: "..."
build_cmd: "..."
format_cmd: "..."
\`\`\`

## Common Frameworks
- [list with detection hints]

## Recommended Agent Set
- [agents and rationale]

## <Stack>-Specific Rules for CLAUDE.md
\`\`\`
[stack-specific rules to inject]
\`\`\`

## Hook: Auto-format
\`\`\`bash
[formatter hook snippet]
\`\`\`
```

### Adding New Agent Templates

To add a reusable agent, create `docs/templates/agents/<name>.md` with YAML frontmatter:

```markdown
---
name: agent-name
description: One-line description used by Claude to decide when to dispatch this agent.
model: claude-haiku-4-5-20251001  # or claude-sonnet-4-6
tools:
  - Read
  - [other tools]
---

# Agent Name

[Agent instructions...]
```

---
name: analyze-repo
description: Full repository analysis. Invoke at the start of a new session or when Claude needs to understand the project from scratch. Writes a comprehensive summary to SESSION_STATE.md.| Use when: starting fresh, after a long break, when context was lost, or when explicitly asked to "analyze the project".
allowed-tools: Read, Glob, Grep, Bash, Write
---

## Purpose
Build a complete mental model of the project and write it to SESSION_STATE.md. This is the "repo memory reload" skill — it turns a cold start into a warm start.

## Steps

### 1. Discover Structure
```bash
# Get top-level layout
ls -la
# Find key config files
ls package.json tsconfig.json pyproject.toml Cargo.toml go.mod 2>/dev/null
# Framework detection
cat package.json | grep -E '"next"|"react"|"vue"|"express"|"fastapi"|"django"' 2>/dev/null
```

### 2. Read Key Config Files
Read (do not dump into conversation — just extract key info):
- `package.json` / `pyproject.toml` / `Cargo.toml` — dependencies and scripts
- `.env.example` — what environment variables are needed
- Existing `CLAUDE.md` if present — don't overwrite it, extend it

### 3. Map the Codebase
Use the explorer sub-agent to explore large codebases:
```
Use the explorer agent to: map the top 3 levels of directory structure and identify what each major directory contains
```

For smaller repos, read directly.

### 4. Identify Key Patterns
- Auth pattern (JWT, session, OAuth?)
- Database access pattern (ORM, raw SQL, query builder?)
- API style (REST, GraphQL, tRPC?)
- State management (if frontend)
- Test setup (unit? integration? e2e?)

### 5. Find Existing Scripts
```bash
cat package.json | python3 -c "import sys,json; d=json.load(sys.stdin); [print(k,':',v) for k,v in d.get('scripts',{}).items()]" 2>/dev/null
```

### 6. Write SESSION_STATE.md
Write a clean, structured summary:

```markdown
# Session State
*Analyzed: [date]*

## Project
- **Name**: [name]
- **Stack**: [e.g., Next.js 14 + Supabase + Tailwind + TypeScript]
- **Package Manager**: [npm/pnpm/yarn]

## Key Commands
- Dev: `[command]`
- Test: `[command]`
- Build: `[command]`
- Lint: `[command]`

## Directory Map
- `/src/app` — Next.js App Router pages
- `/src/components` — Reusable UI components
- `/src/lib` — Utilities and helpers
- `/api` — API routes
- `/tests` — Test files

## Architecture Notes
[Key architectural decisions, patterns, and things Claude needs to know]

## Active Work
[What was being worked on — if any TODO.md or recent commits indicate this]

## Agents Available
[List the .claude/agents/ files found]

## Skills Available  
[List the .claude/skills/ directories found]
```

### 7. Report to User
Print a short 5-line summary:
- Stack detected
- Key commands found
- Number of agents/skills configured
- Anything unexpected or worth noting
- "SESSION_STATE.md updated. Ready to work."

## Final Step — Surface Tips

After the analysis is complete, call the tips skill to show 2-3 relevant tips:

```
Skill("tips")
```

When calling from analyze-repo context:
- Show only 2-3 tips (not 5)
- Prioritize based on what the analysis revealed:
  - Large files found → tip about targeted reads
  - No tests found → tip about /test workflow
  - No SESSION_STATE.md → tip about session continuity
  - Many agents → tip about context window
- Label them: "Quick wins for this setup"

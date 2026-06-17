---
name: git-workflow
description: Git workflow assistant. Invoke when the user wants to commit, create a branch, write a PR description, or follow the project's git conventions. Auto-activates on: "commit this", "create a PR", "write a commit message", "what should I name this branch".
allowed-tools: Bash, Read
---

## Purpose
Handle git operations following the project's specific conventions. Read the project's CLAUDE.md to understand branch naming, commit message format, and PR conventions before doing anything.

## Steps

### 1. Read Project Conventions
Before any git operation, read CLAUDE.md for:
- Commit message format (conventional commits? custom format?)
- Branch naming convention
- PR template (check `.github/pull_request_template.md` if it exists)

### 2. Check Current State
```bash
git status
git diff --stat HEAD
```

### 3. For Commits
- Group related changes into logical commits (not one giant commit)
- Write commit message following project conventions
- If conventional commits: `type(scope): description`
- Include breaking change footer if relevant
- Max subject line: 72 characters
- Body: what changed and WHY, not what (the diff shows what)

### 4. For Branches
- Read the issue/task first to understand scope
- Name: `type/short-description` (e.g., `feat/add-review-widget`, `fix/auth-cookie-bug`)
- Check it doesn't already exist: `git branch -a | grep name`

### 5. For PR Descriptions
Structure:
```markdown
## What
[One paragraph: what changed]

## Why  
[One paragraph: why this change was needed]

## How
[Brief technical explanation of the approach]

## Testing
[How to test this change]

## Checklist
- [ ] Tests pass
- [ ] No console.logs left
- [ ] Docs updated if needed
```

### 6. Safety Checks
- NEVER suggest `git push --force` on a shared branch
- NEVER commit to `main` or `master` directly
- Always check for secrets before committing: `git diff --cached | grep -i "api_key\|secret\|password\|token"`

## Output
Print the git commands to run (don't run them automatically unless the user said "just do it").
Explain what each command does if it's non-obvious.

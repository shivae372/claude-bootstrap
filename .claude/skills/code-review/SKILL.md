---
name: code-review
description: Structured code review. Invoke before committing, before opening a PR, or when you want feedback on changes. Auto-activates on "review this code", "check my changes", "look for issues", "review before I push". Routes to code-reviewer sub-agent to keep main context clean.
allowed-tools: Bash, Read
---

## Purpose
Run a structured code review using the code-reviewer sub-agent. Returns findings organized by severity. The sub-agent runs in its own isolated context window.

## Steps

### 1. Get the Scope
Determine what to review:
```bash
# If reviewing uncommitted changes
git diff HEAD

# If reviewing staged changes
git diff --cached

# If reviewing a specific file
# (user will have specified)
```

### 2. Delegate to Sub-agent
```
Use the code-reviewer agent to: review [the diff / file / changes described above]
Focus on: correctness, security, performance, and adherence to project conventions in CLAUDE.md
```

### 3. Present Findings
Format the sub-agent's output as:

```
## Code Review

### 🔴 Critical (must fix)
[list]

### 🟠 High (should fix)
[list]

### 🟡 Medium (consider fixing)
[list]

### ✅ Looks Good
[things done well]

**Verdict**: [Approved / Needs changes / Blocking issues found]
```

### 4. If No Issues
```
✅ Code review complete — no significant issues found.
[Optional: one positive observation]
Ready to commit.
```

## Rules
- Never skip the sub-agent for large diffs — isolation protects the main context
- Always read CLAUDE.md conventions before reviewing
- If the user asks to fix issues found, do them one at a time and re-review each fix

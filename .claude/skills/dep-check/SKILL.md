---
name: dep-check
description: Dependency audit skill. Check for outdated packages and security vulnerabilities. Auto-activates on "check dependencies", "any vulnerable packages", "audit deps", "what's outdated", "npm audit". Routes to dep-checker sub-agent to keep main context clean.
allowed-tools: Bash
---

## Purpose
Run a full dependency audit using the dep-checker sub-agent. Returns a clean vulnerability and outdated package report.

## Steps

### 1. Delegate to Sub-agent
```
Use the dep-checker agent to: audit all project dependencies for vulnerabilities and outdated packages
```

### 2. Present Results

```
## Dependency Audit

**Risk**: [CRITICAL / HIGH / MEDIUM / CLEAN]

### 🔴 Security Vulnerabilities
[CVEs with fix commands]

### ⬆️ Major Updates Available
[Packages with breaking version bumps — manual review needed]

### 📦 Minor/Patch Updates
[Safe to update: `npm update` or equivalent]

### Recommended Action
[Specific commands to run]
```

### 3. If Critical Vulnerabilities Found

```
⛔ CRITICAL: Known exploited vulnerability in [package].
Fix: [exact command]
Do not deploy until patched.
```

### 4. If Clean

```
✅ All dependencies are up to date with no known vulnerabilities.
```

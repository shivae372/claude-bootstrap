---
name: security-scan
description: Security audit skill. Invoke before deploying, after adding auth code, or when reviewing for vulnerabilities. Auto-activates on "security check", "check for vulnerabilities", "pre-deploy audit", "scan for secrets", "is this auth secure". Routes to security-scanner sub-agent.
allowed-tools: Bash, Read
---

## Purpose
Run a security audit using the security-scanner sub-agent. Covers auth, injection, secrets, data exposure, and input validation. Sub-agent runs in isolation — no raw file dumps in main context.

## Steps

### 1. Determine Scope
```bash
# Recent changes only
git diff HEAD --name-only

# Specific area (auth, API, etc.)
# User will specify
```

### 2. Delegate to Sub-agent
```
Use the security-scanner agent to: audit [scope — recent changes / auth module / API routes / full project]
Pay special attention to: authentication, authorization checks, input validation, and any hardcoded credentials
```

### 3. Present Results

Format as:
```
## Security Audit

**Risk Level**: [CRITICAL / HIGH / MEDIUM / LOW / CLEAN]

### 🔴 Critical Issues
[Must fix before deployment]

### 🟠 High Issues
[Fix before merge]

### 🟡 Medium Issues  
[Address in next iteration]

### ✅ Clean Areas
[Confirmed secure]

**Recommendation**: [Deploy / Fix critical first / Full security review needed]
```

### 4. If Critical Issues Found
Immediately flag:
```
⛔ DEPLOYMENT BLOCKED: Critical security issue found.
Do not deploy until [specific fix] is applied.
```

## Scope Guide
| What user says | Scope to pass to agent |
|---|---|
| "check auth" | Authentication and session management code |
| "pre-deploy scan" | All files changed since last deploy |
| "check this file" | That specific file |
| "full audit" | Entire project (warn: this will take longer) |
| "scan for secrets" | Use secret-detector hook + grep patterns |

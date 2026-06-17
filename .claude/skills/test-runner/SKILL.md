---
name: test-runner
description: Run the project's test suite and get a structured report. Invoke when you want to run tests after making changes. Auto-activates when user says "run tests", "do tests pass", or "check if this broke anything". Routes execution to the test-runner sub-agent to keep main context clean.
allowed-tools: Bash
---

## Purpose
Run the project's test suite and return a clean pass/fail report. Uses the test-runner sub-agent so raw test output never floods the main context.

## Steps

### 1. Delegate to Test-Runner Agent
Always route to the sub-agent:
```
Use the test-runner agent to: run the full test suite and return a structured summary
```

### 2. If Quick Targeted Test Needed
For a single file or test name (low context cost, run inline):
```bash
# Jest
npx jest path/to/file.test.ts --no-coverage 2>&1 | tail -20
# Pytest  
python -m pytest tests/test_specific.py -v --tb=short 2>&1 | tail -30
# Vitest
npx vitest run src/specific.test.ts 2>&1 | tail -20
```

### 3. Report Format
Always present results as:
```
Tests: ✅ 42 passed | ❌ 3 failed | ⏭️ 1 skipped

Failed:
1. AuthController > expired tokens → Expected 401, got 200
2. ReviewForm > required fields → TypeError: Cannot read 'id'
3. DB > connection pool → Timeout after 5000ms

Next: [specific action to fix the first failure]
```

Never paste raw test runner output. Always parse and summarize.

---
name: context-guard
description: "Context window protection. Auto-activates when the conversation is getting long, when the user is about to do a large file read or exploration task, or when the context is approaching its limit. Helps route expensive operations to sub-agents to protect the main session."
allowed-tools: Bash
---

## Purpose
Protect the user's context window from expensive operations that should run in a sub-agent instead. This skill activates automatically when it detects patterns that commonly cause context blowout.

## When I Activate
- User asks to "read", "scan", "explore", or "analyze" a large codebase
- User asks to run tests and see all output
- Context window is getting long and a compaction is likely soon
- User is about to do something that will dump large amounts of text into the main context

## What I Do

### 1. Assess the Risk
Before the expensive operation happens, estimate the token cost:
- Reading a large file: HIGH risk
- Exploring a directory: MEDIUM-HIGH risk  
- Running tests with verbose output: HIGH risk
- A targeted grep: LOW risk

### 2. Route to Sub-agent If High Risk
If the operation is HIGH risk, do NOT execute it in the main context. Instead:

```
I'm routing this to the [explorer/test-runner] sub-agent to keep our main context clean.
Use: "[agent-name] — [what you need]"
```

### 3. Compress Before Returning
If a sub-agent result is returned to you, summarize it before adding it to the main conversation:
- Max 20 lines for any exploration result
- Max 10 lines for a test run summary  
- Always structured (JSON or bullet list), never raw file dumps

### 4. Warn When Context Is Large
If the current context is approaching the limit:
```
⚠️ Context Warning: Our session is getting long. I recommend:
1. Using /compact to compress history
2. Starting a new session for the next distinct task
3. Current state will be saved to SESSION_STATE.md first
```

## What I Do NOT Do
- Block the user from doing anything
- Make the decision unilaterally — always explain and ask if the rerouting is okay
- Obsessively activate on every message (only on genuinely expensive operations)

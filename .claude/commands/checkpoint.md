---
description: Snapshot the current task, decisions, and open threads into SESSION_STATE.md right now.
allowed-tools: Read, Write, Edit, Bash
---

Write/update `SESSION_STATE.md` so this session can be resumed cleanly later (or after compaction).

Capture, concisely:
- **Current Task** — what we're working on right now
- **Completed This Session** — what's done
- **Pending / Blocked** — what's left and anything waiting on a decision
- **Key Decisions** — choices made and why
- **Files Modified** — touched files with a one-line note each

Keep it tight (it's working memory, not a changelog). Preserve any existing
"Compaction Checkpoints" section. Then confirm in one line that the checkpoint is saved.

---
name: self-update
description: "Checks whether the project's claude-bootstrap setup is current and applies updates safely. Compares the installed version against the source repo, shows what changed, and updates only what the user approves. Triggered by /update."
allowed-tools: Bash, Read, Edit
version: 1.0.0
---

## Purpose
Keep a project's bootstrap config current without clobbering the user's customizations.

## When To Use This
- The user runs `/update` or asks "is my Claude setup outdated?"

## Steps

### 1. Read the installed version
```bash
python3 -c 'import json,pathlib; p=pathlib.Path(".claude/.bootstrap.json"); \
print(json.loads(p.read_text()).get("bootstrap_version","unknown") if p.exists() else "unknown")'
```

### 2. Read the latest version from the source repo
```bash
curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/VERSION 2>/dev/null || echo unknown
```

### 3. Compare and report (plain language)
- **Up to date** → say so and stop.
- **Outdated** → summarize what changed using the repo's CHANGELOG.md
  (`curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/CHANGELOG.md`).

### 4. Apply selectively (only what the user approves)
Offer: hooks, skills, commands, stack templates, or just-show-me. For each chosen item:
1. Back up first: `cp <file> <file>.bak`
2. Re-run the installer in merge mode to pull only new/updated component files:
   `curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash -s -- --merge`
3. Update `bootstrap_version` in `.claude/.bootstrap.json`.

## Safety Rules
- NEVER overwrite `USER_PROFILE.json`.
- NEVER overwrite a customized `CLAUDE.md` or `SESSION_STATE.md` without explicit confirmation.
- ALWAYS show what will change before applying, and back up before replacing.

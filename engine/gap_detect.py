#!/usr/bin/env python3
"""
gap_detect.py — the real-time augmentation trigger.

Runs from the UserPromptSubmit hook on every user turn. It reads the prompt, and
deterministically asks: "is the user trying to do something this setup has no skill
for?" If so, it injects a short note (UserPromptSubmit additionalContext) telling
Claude to run the `augment` skill for that capability — so the setup grows itself
in real time, mid-task, instead of the user hitting a wall.

It also watches `.claude/state/failures.jsonl`; repeated tool failures inject a
`[heal]` nudge toward `/doctor`. Stateless-safe, never blocks, always exit 0.

Reads hook JSON on stdin; prints either nothing or:
  {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"…"}}
"""
import json
import os
import re
import sys
import time
from pathlib import Path

# capability  ->  trigger phrases that imply the user wants it
CAP_TRIGGERS = {
    "stripe payments": ["stripe", "checkout session", "subscription billing", "payment intent"],
    "postgres": ["postgres", "postgresql", "psql ", "pg_dump"],
    "supabase": ["supabase", "row level security", " rls "],
    "docker": ["dockerfile", "docker compose", "containerize", "docker build"],
    "kubernetes": ["kubernetes", "k8s", "kubectl", "helm chart"],
    "fly.io deploy": ["fly.io", "flyctl", "fly deploy"],
    "vercel deploy": ["deploy to vercel", "vercel deploy"],
    "aws": ["aws lambda", "s3 bucket", "dynamodb", "cloudformation", "aws sdk"],
    "twilio sms": ["twilio", "send an sms", "send a text message"],
    "email sending": ["sendgrid", "resend.com", "transactional email", "send an email"],
    "terraform": ["terraform", "tfstate", "terraform apply"],
    "graphql": ["graphql schema", "apollo server", "graphql resolver"],
    "stripe": ["stripe"],
}

# Don't nudge if the installed capability set already plausibly covers it.
def _installed_tokens(root):
    toks = set()
    cl = Path(root) / ".claude"
    for sub, glob, dirs in (("skills", "*", True), ("commands", "*.md", False), ("agents", "*.md", False)):
        d = cl / sub
        if not d.is_dir():
            continue
        names = (p.name for p in d.iterdir() if p.is_dir()) if dirs else (p.stem for p in d.glob(glob))
        for n in names:
            toks |= set(re.split(r"[-_ ]", n.lower()))
    # also count an installed MCP server in .mcp.json
    mcp = Path(root) / ".mcp.json"
    if mcp.exists():
        try:
            for k in (json.loads(mcp.read_text()).get("mcpServers") or {}):
                toks |= set(re.split(r"[-_ ]", k.lower()))
        except Exception:
            pass
    return toks


def detect_gaps(prompt, root):
    p = prompt.lower()
    installed = _installed_tokens(root)
    gaps = []
    for cap, triggers in CAP_TRIGGERS.items():
        if not any(t in p for t in triggers):
            continue
        cap_tokens = set(re.split(r"[-_ .]", cap.lower())) - {"", "io", "deploy"}
        if cap_tokens & installed:        # already covered
            continue
        gaps.append(cap)
    # de-dupe overlapping ("stripe payments" vs "stripe")
    gaps = sorted(set(gaps), key=len, reverse=True)
    out, seen = [], set()
    for g in gaps:
        head = g.split()[0]
        if head in seen:
            continue
        seen.add(head); out.append(g)
    return out[:2]


def failure_nudge(root, window=3600, threshold=3):
    fpath = Path(root) / ".claude" / "state" / "failures.jsonl"
    if not fpath.exists():
        return False
    now = time.time(); n = 0
    try:
        for line in fpath.read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                if now - json.loads(line).get("t", 0) <= window:
                    n += 1
            except Exception:
                pass
    except Exception:
        return False
    return n >= threshold


def _already_nudged(root, key):
    """Nudge a given capability at most once per project to avoid nagging."""
    s = Path(root) / ".claude" / "state" / "nudged.txt"
    seen = set(s.read_text(encoding="utf-8").splitlines()) if s.exists() else set()
    if key in seen:
        return True
    s.parent.mkdir(parents=True, exist_ok=True)
    s.write_text("\n".join(sorted(seen | {key})), encoding="utf-8")
    return False


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    prompt = data.get("prompt") or data.get("user_prompt") or ""
    root = data.get("cwd") or os.getcwd()
    if not prompt.strip():
        return

    notes = []
    for cap in detect_gaps(prompt, root):
        if _already_nudged(root, cap):
            continue
        notes.append(
            f"This project has no skill for **{cap}**, which the user seems to need. "
            f"Consider running the `augment` skill to find or forge one now: "
            f"`python3 .claude/engine/skill_finder.py \"{cap}\" --json` — vet, then install or forge."
        )
    if failure_nudge(root) and not _already_nudged(root, "__heal__"):
        notes.append("Several tool calls have failed recently. Consider running the "
                     "`doctor` skill (`python3 .claude/engine/doctor.py --apply`) to self-heal the setup.")

    if notes:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "[claude-bootstrap] " + " ".join(notes),
        }}))


if __name__ == "__main__":
    main()

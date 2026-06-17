#!/usr/bin/env python3
"""
learn.py — self-learning memory for the setup. Modeled on nodo's lessons.py:
Claude observes what happened (a capability gap found, a fix applied, a user
preference, a recurring failure) and teaches the setup a durable "learning";
this module VALIDATES it, then persists it deterministically. The SessionStart
hook reads it back so every future session starts smarter. Pure stdlib, local,
never networked.

Store:  .claude/memory/learnings.json   (+ a rendered learnings.md for humans/agents)

  echo '{"category":"preference","text":"User deploys via Fly.io, not Vercel"}' \
      | python3 learn.py add
  python3 learn.py render          # (re)write learnings.md
  python3 learn.py list [--json]
  python3 learn.py inject          # print SessionStart additionalContext JSON
"""
import argparse
import json
import sys
import time
from pathlib import Path

CATEGORIES = {"preference", "gap", "fix", "convention", "stack", "workflow", "fact"}
MAX_LEARNINGS = 200
STORE_DIR = ".claude/memory"
STORE = "learnings.json"
RENDER = "learnings.md"


def _path(root, name):
    return Path(root) / STORE_DIR / name


def load(root="."):
    p = _path(root, STORE)
    if not p.exists():
        return {"version": 1, "learnings": []}
    try:
        d = json.loads(p.read_text(encoding="utf-8", errors="ignore"))
        if not isinstance(d.get("learnings"), list):
            d["learnings"] = []
        return d
    except Exception:
        return {"version": 1, "learnings": []}


def validate(obj):
    """The 'heal safely' gate — reject junk before it becomes durable memory."""
    errors = []
    if not isinstance(obj, dict):
        return False, ["learning must be a JSON object"], None
    text = (obj.get("text") or "").strip()
    cat = (obj.get("category") or "fact").strip().lower()
    if not text:
        errors.append("`text` is required and non-empty")
    if len(text) > 500:
        errors.append("`text` too long (>500 chars) — keep learnings atomic")
    if cat not in CATEGORIES:
        errors.append(f"`category` must be one of {sorted(CATEGORIES)}")
    tags = obj.get("tags", [])
    if not isinstance(tags, list):
        tags = []
    if errors:
        return False, errors, None
    return True, [], {"category": cat, "text": text,
                      "tags": [str(t) for t in tags][:8], "ts": int(time.time())}


def add(root, obj):
    ok, errs, norm = validate(obj)
    if not ok:
        return False, errs
    store = load(root)
    # de-dupe identical text
    if any(l.get("text") == norm["text"] for l in store["learnings"]):
        return True, ["(already known — no change)"]
    store["learnings"].append(norm)
    store["learnings"] = store["learnings"][-MAX_LEARNINGS:]
    d = _path(root, STORE)
    d.parent.mkdir(parents=True, exist_ok=True)
    d.write_text(json.dumps(store, indent=2), encoding="utf-8")
    render(root)
    return True, []


def render(root):
    store = load(root)
    by_cat = {}
    for l in store["learnings"]:
        by_cat.setdefault(l["category"], []).append(l)
    lines = ["# Project Learnings",
             "_Durable knowledge the setup has accumulated. Auto-applied at session start._", ""]
    for cat in sorted(by_cat):
        lines.append(f"## {cat.capitalize()}")
        for l in by_cat[cat]:
            tag = f"  _({', '.join(l['tags'])})_" if l.get("tags") else ""
            lines.append(f"- {l['text']}{tag}")
        lines.append("")
    out = _path(root, RENDER)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def inject_json(root):
    """SessionStart additionalContext envelope (nodo hookinstall pattern)."""
    store = load(root)
    if not store["learnings"]:
        return None
    md = _path(root, RENDER)
    body = md.read_text(encoding="utf-8", errors="ignore") if md.exists() else ""
    note = ("The following are durable learnings about THIS project that the setup "
            "accumulated across sessions — honor them without being re-told:\n\n" + body)
    return {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": note}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["add", "render", "list", "inject"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    if args.cmd == "add":
        try:
            obj = json.load(sys.stdin)
        except Exception as e:
            print(f"ERROR: invalid JSON on stdin: {e}", file=sys.stderr); sys.exit(1)
        ok, msgs = add(args.root, obj)
        if not ok:
            print("Rejected:\n  - " + "\n  - ".join(msgs), file=sys.stderr); sys.exit(1)
        print("Learned." + (" " + msgs[0] if msgs else ""))
    elif args.cmd == "render":
        print(f"Wrote {render(args.root)}")
    elif args.cmd == "list":
        store = load(args.root)
        if args.json:
            print(json.dumps(store, indent=2))
        else:
            for l in store["learnings"]:
                print(f"  [{l['category']}] {l['text']}")
            if not store["learnings"]:
                print("  (no learnings yet)")
    elif args.cmd == "inject":
        env = inject_json(args.root)
        if env:
            print(json.dumps(env))


if __name__ == "__main__":
    main()

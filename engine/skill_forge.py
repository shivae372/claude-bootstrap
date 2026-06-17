#!/usr/bin/env python3
"""
skill_forge.py — create and validate bespoke Claude Code skills.

When the discovery engine finds nothing that fits, the setup AUTHORS a skill —
and it must be detailed and project-specific, not generic. This script owns the
DETERMINISTIC half: it scaffolds a correct, valid SKILL.md skeleton (right
frontmatter, the sections a real skill needs, optional scripts/ + references/),
and it validates any SKILL.md against the rules so a bad skill never ships.
Claude fills the skeleton with real, specific domain content. Pure stdlib.

  python3 skill_forge.py scaffold --name deploy-flyio \
      --description "Deploy this app to Fly.io. Use when the user says deploy/ship/release." \
      [--allowed-tools "Bash, Read"] [--root .]
  python3 skill_forge.py validate .claude/skills/deploy-flyio/SKILL.md
"""
import argparse
import re
import sys
from pathlib import Path

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")

SKELETON = """---
name: {name}
description: {description}
allowed-tools: {tools}
version: 0.1.0
---

## Purpose
{purpose}

## When to use this
- {trigger}
<!-- Add the concrete situations that should trigger this skill. Be specific:
     name the commands, file types, or phrases the user will actually use. -->

## Steps
<!-- The exact, ordered procedure. This is the heart of the skill — make it
     SPECIFIC to this project: real commands, real file paths, real configs.
     A generic skill is a failed skill. Replace every bracket below. -->
1. [First concrete action — e.g. read X, run `<real command>`]
2. [Next action, with the exact command/flags for THIS project]
3. [How to verify success — the test, the expected output, the check]

## Output
[What the user sees when this succeeds — the summary format, the file written,
 or the confirmation. Name it precisely.]

## Guardrails
- [Anything this skill must NEVER do — destructive ops, wrong env, etc.]
- If a step fails, stop and report the exact error; do not guess past it.

## References
<!-- Optional: drop long docs/specs in ./references/ and link them here so the
     skill body stays lean (progressive disclosure). -->
"""


def scaffold(root, name, description, tools, purpose=None, trigger=None):
    if not NAME_RE.match(name):
        return False, [f"name must be kebab-case (got {name!r})"], None
    if len(description) < 20:
        return False, ["description should be >=20 chars and say WHAT it does + WHEN to use it"], None
    d = Path(root) / ".claude" / "skills" / name
    sm = d / "SKILL.md"
    if sm.exists():
        return False, [f"{sm} already exists — edit it or pick another name"], None
    d.mkdir(parents=True, exist_ok=True)
    (d / "scripts").mkdir(exist_ok=True)
    (d / "references").mkdir(exist_ok=True)
    (d / "scripts" / ".gitkeep").write_text("", encoding="utf-8")
    (d / "references" / ".gitkeep").write_text("", encoding="utf-8")
    body = SKELETON.format(
        name=name, description=description, tools=tools or "Read, Bash",
        purpose=purpose or f"[One paragraph: what problem '{name}' solves for THIS project.]",
        trigger=trigger or "[the main phrase/command that should trigger this]",
    )
    sm.write_text(body, encoding="utf-8")
    return True, [], str(sm)


def validate(path):
    p = Path(path)
    errors, warnings = [], []
    if not p.exists():
        return False, [f"{path} does not exist"], []
    text = p.read_text(encoding="utf-8", errors="ignore")
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not m:
        return False, ["missing YAML frontmatter (--- ... ---) at top of file"], []
    fm, body = m.group(1), m.group(2)
    fields = dict(re.findall(r"^([A-Za-z0-9_-]+):\s*(.*)$", fm, re.M))
    if "description" not in fields or not fields["description"].strip():
        errors.append("frontmatter needs a non-empty `description` (drives auto-invocation)")
    elif len(fields["description"]) > 1024:
        warnings.append("description >1024 chars — trigger text truncates around 1536")
    name = fields.get("name", p.parent.name)
    if not NAME_RE.match(name):
        warnings.append(f"name {name!r} is not kebab-case")
    # Body must be more than the skeleton — reject obviously-unfilled skills.
    if "[First concrete action" in body or "[the main phrase" in body:
        errors.append("skill still contains skeleton placeholders — fill in real, specific steps")
    if len(body.strip()) < 120:
        errors.append("body is too thin — a real skill needs concrete steps")
    if "## Steps" not in body:
        warnings.append("no `## Steps` section — most skills need an explicit procedure")
    return (not errors), errors, warnings


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sc = sub.add_parser("scaffold")
    sc.add_argument("--root", default=".")
    sc.add_argument("--name", required=True)
    sc.add_argument("--description", required=True)
    sc.add_argument("--allowed-tools", default="Read, Bash")
    sc.add_argument("--purpose", default=None)
    sc.add_argument("--trigger", default=None)
    va = sub.add_parser("validate")
    va.add_argument("path")
    args = ap.parse_args()

    if args.cmd == "scaffold":
        ok, errs, path = scaffold(args.root, args.name, args.description,
                                  args.allowed_tools, args.purpose, args.trigger)
        if not ok:
            print("Could not scaffold:\n  - " + "\n  - ".join(errs), file=sys.stderr); sys.exit(1)
        print(f"Scaffolded {path}\nNow fill the Steps/Output with REAL, project-specific detail, "
              f"then run:\n  python3 engine/skill_forge.py validate {path}")
    else:
        ok, errs, warns = validate(args.path)
        for w in warns:
            print(f"  ⚠ {w}")
        if ok:
            print(f"  ✓ {args.path} is a valid skill.")
        else:
            print("  ✗ invalid skill:\n  - " + "\n  - ".join(errs), file=sys.stderr); sys.exit(1)


if __name__ == "__main__":
    main()

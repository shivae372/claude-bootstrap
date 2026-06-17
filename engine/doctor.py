#!/usr/bin/env python3
"""
doctor.py — self-healing diagnostics for a Claude Code setup.

Mirrors nodo's "find where it's blind → report → heal safely" loop: a fully
deterministic scan of `.claude/` that produces a health score, a structured
finding list (each with a concrete fix), and a set of SAFE auto-fixes it can
apply itself. Pure stdlib, offline.

  python3 doctor.py [--root .] [--json] [--apply] [--manifest]

  (no flag)   human-readable health report
  --json      machine-readable {score, findings[], auto_fixed[]}
  --apply     perform safe auto-fixes (chmod +x hooks, etc.), then report
  --manifest  print a compact capability manifest (for the SessionStart hook)
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

SEV = {"error": 3, "warn": 2, "info": 1}


def _frontmatter(p: Path):
    try:
        t = p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return {}
    m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        mm = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if mm:
            fm[mm.group(1)] = mm.group(2).strip()
    return fm


def diagnose(root="."):
    root = Path(root)
    cl = root / ".claude"
    findings = []
    auto = []  # callables (description, fn)

    def add(sev, where, problem, fix, fixer=None):
        f = {"severity": sev, "where": where, "problem": problem, "fix": fix,
             "auto_fixable": fixer is not None}
        findings.append(f)
        if fixer:
            auto.append((f, fixer))

    if not cl.is_dir():
        add("error", ".claude/", "No .claude/ directory — this project has no Claude Code setup.",
            "Run the installer or `/bootstrap` to create one.")
        return _finalize(findings, auto, root)

    # settings.json + hook references
    sj = cl / "settings.json"
    hook_cmds = []
    if sj.exists():
        try:
            cfg = json.loads(sj.read_text(encoding="utf-8"))
            for ev in (cfg.get("hooks") or {}).values():
                for grp in ev:
                    for h in grp.get("hooks", []):
                        m = re.search(r"\.claude/hooks/([A-Za-z0-9._-]+\.sh)", h.get("command", ""))
                        if m:
                            hook_cmds.append(m.group(1))
        except Exception as e:
            add("error", ".claude/settings.json", f"Invalid JSON: {e}",
                "Fix the JSON syntax; run `python3 -m json.tool .claude/settings.json`.")
    else:
        add("warn", ".claude/settings.json", "Missing — no hooks are wired.",
            "Add a settings.json with your hooks, or run `/doctor --apply`.")

    # hooks on disk: referenced ones must exist + be executable + parse
    hooks_dir = cl / "hooks"
    for name in set(hook_cmds):
        hp = hooks_dir / name
        if not hp.exists():
            add("error", f".claude/hooks/{name}", "Referenced in settings.json but file is missing.",
                f"Restore {name} or remove its reference from settings.json.")
        else:
            if not os.access(hp, os.X_OK):
                add("warn", f".claude/hooks/{name}", "Hook not executable.",
                    f"chmod +x .claude/hooks/{name}",
                    fixer=lambda p=hp: os.chmod(p, 0o755))
            r = subprocess.run(["bash", "-n", str(hp)], capture_output=True, text=True)
            if r.returncode != 0:
                add("error", f".claude/hooks/{name}", f"Shell syntax error: {r.stderr.strip()[:120]}",
                    "Fix the script syntax.")

    # skills: every dir MUST have a valid SKILL.md
    sdir = cl / "skills"
    if sdir.is_dir():
        for d in sorted(p for p in sdir.iterdir() if p.is_dir()):
            sm = d / "SKILL.md"
            if not sm.exists():
                add("error", f".claude/skills/{d.name}", "Skill directory has no SKILL.md — it will NOT load.",
                    f"Create .claude/skills/{d.name}/SKILL.md (use `/forge`) or remove the directory.")
                continue
            fm = _frontmatter(sm)
            if "description" not in fm:
                add("error", f".claude/skills/{d.name}/SKILL.md", "Missing `description` frontmatter — Claude can't auto-invoke it.",
                    "Add a `description:` line describing what it does and when to use it.")
            elif len(fm.get("description", "")) > 1024:
                add("warn", f".claude/skills/{d.name}/SKILL.md", "Description is very long (>1024 chars); trigger text is truncated ~1536.",
                    "Tighten the description.")

    # commands: description recommended
    cdir = cl / "commands"
    if cdir.is_dir():
        for c in sorted(cdir.glob("*.md")):
            if "description" not in _frontmatter(c):
                add("info", f".claude/commands/{c.name}", "No `description` in frontmatter (cosmetic, hides it from the menu).",
                    "Add a `description:` line.")

    # agents: name + description
    adir = cl / "agents"
    if adir.is_dir():
        for a in sorted(adir.glob("*.md")):
            fm = _frontmatter(a)
            miss = [k for k in ("name", "description") if k not in fm]
            if miss:
                add("warn", f".claude/agents/{a.name}", f"Missing frontmatter: {', '.join(miss)}.",
                    "Add the missing fields.")

    # CLAUDE.md size
    cmd = root / "CLAUDE.md"
    if cmd.exists():
        n = len(cmd.read_text(encoding="utf-8", errors="ignore").splitlines())
        if n > 150:
            add("warn", "CLAUDE.md", f"{n} lines (>150) — instruction-following degrades past this.",
                "Trim CLAUDE.md; move workflow detail into skills.")
    else:
        add("info", "CLAUDE.md", "No project CLAUDE.md — Claude lacks persistent project context.",
            "Run `/bootstrap` to generate one.")

    # ── Ecosystem: nodo (the codebase-map sibling) transparency ──────────────
    ns = nodo_status(root)
    if ns["present"]:
        if not ns["map_present"]:
            add("info", "nodo", "nodo is available but no architecture map exists yet.",
                "Run `/nodo` (or `python nodo.py .`) to generate .nodo/nodo-context.* — then Claude reads it on session start.")
        elif ns["stale"]:
            add("info", "nodo", "nodo's architecture map looks stale (older than recent source changes).",
                "Re-run `/nodo` to refresh .nodo/nodo-context.*; run `nodo … --self-check` for nodo's own diagnosis.")
    elif ns["has_code"]:
        add("info", "nodo", "No codebase map. The nodo sibling gives Claude an architecture map + blast-radius answers.",
            "Install it: run /marketplace and enter shivae372/claude-bootstrap, then /plugin install nodo@claude-bootstrap (or clone shivae372/nodo).")

    return _finalize(findings, auto, root)


def _finalize(findings, auto, root):
    errs = sum(1 for f in findings if f["severity"] == "error")
    warns = sum(1 for f in findings if f["severity"] == "warn")
    score = max(0, 100 - 18 * errs - 5 * warns)
    findings.sort(key=lambda f: -SEV[f["severity"]])
    return {"score": score, "errors": errs, "warnings": warns,
            "findings": findings, "_auto": auto, "root": str(root)}


def apply_fixes(report):
    fixed = []
    for f, fn in report.get("_auto", []):
        try:
            fn()
            fixed.append(f["where"])
        except Exception:
            pass
    return fixed


def nodo_status(root="."):
    """Transparency for the nodo sibling: is it available, is its map present/fresh?
    nodo is optional — everything here is informational, never an error."""
    root = Path(root)
    present = ((root / ".nodo").is_dir()
               or (root / ".claude" / "skills" / "nodo" / "SKILL.md").exists()
               or (root / "nodo.py").exists())
    code_markers = ["package.json", "pyproject.toml", "go.mod", "Cargo.toml",
                    "Gemfile", "pom.xml", "requirements.txt"]
    has_code = any((root / m).exists() for m in code_markers)
    ctx = root / ".nodo" / "nodo-context.md"
    map_present = ctx.exists()
    stale = False
    if map_present:
        try:
            mtime = ctx.stat().st_mtime
            newest = 0.0
            for p in root.rglob("*"):
                parts = set(p.parts)
                if parts & {".nodo", ".git", "node_modules", ".claude", "__pycache__"}:
                    continue
                if p.is_file():
                    newest = max(newest, p.stat().st_mtime)
            stale = newest > mtime + 1
        except Exception:
            stale = False
    return {"present": present, "has_code": has_code,
            "map_present": map_present, "stale": stale}


def capability_manifest(root="."):
    cl = Path(root) / ".claude"
    ns = nodo_status(root)
    def names(sub, pat, dirs=False):
        d = cl / sub
        if not d.is_dir():
            return []
        if dirs:
            return sorted(p.name for p in d.iterdir() if p.is_dir())
        return sorted(p.stem for p in d.glob(pat))
    nodo = "not installed" if not ns["present"] else (
        "installed, no map yet" if not ns["map_present"] else
        ("installed, map stale" if ns["stale"] else "installed, map fresh"))
    return {
        "skills": names("skills", "*", dirs=True),
        "commands": names("commands", "*.md"),
        "agents": names("agents", "*.md"),
        "hooks": names("hooks", "*.sh"),
        "nodo": nodo,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--manifest", action="store_true")
    args = ap.parse_args()

    if args.manifest:
        m = capability_manifest(args.root)
        print(json.dumps(m, indent=2) if args.json else
              " · ".join(f"{k}: {', '.join(v) or 'none'}" for k, v in m.items()))
        return

    rep = diagnose(args.root)
    fixed = apply_fixes(rep) if args.apply else []
    rep.pop("_auto", None)
    rep["auto_fixed"] = fixed

    if args.json:
        print(json.dumps(rep, indent=2))
        sys.exit(1 if rep["errors"] else 0)

    print(f"\n  Claude Code setup health: {rep['score']}/100   "
          f"({rep['errors']} errors, {rep['warnings']} warnings)\n")
    icon = {"error": "✗", "warn": "⚠", "info": "·"}
    for f in rep["findings"]:
        print(f"  {icon[f['severity']]} [{f['where']}] {f['problem']}")
        print(f"      → {f['fix']}")
    if fixed:
        print(f"\n  Auto-fixed: {', '.join(fixed)}")
    if not rep["findings"]:
        print("  ✓ Everything looks healthy.")
    print()
    sys.exit(1 if rep["errors"] else 0)


if __name__ == "__main__":
    main()

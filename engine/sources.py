#!/usr/bin/env python3
"""
sources.py — the self-EXTENDING half of discovery.

The built-in web search (skill_finder) covers the common ecosystem. But when it
misses something and Claude finds the capability another way — a specific GitHub
org, a vendor's own JSON search endpoint, or just "X lives at Y" — that knowledge
should not be thrown away. Teach it here, and every future `discover` queries it
TOO, alongside the web. This is self-healing applied to discovery itself.

Store:  .claude/memory/sources.json   (local, validated, never networked except when querying)

Source kinds:
  github_org   {"kind":"github_org","org":"stripe","note":"..."}            → searches that org's repos
  http_json    {"kind":"http_json","name":"acme","url":"https://api.acme/search?q={query}",
                "list_path":"results","name_field":"slug","url_field":"link","note":"..."}
  hint         {"kind":"hint","name":"...","text":"For X, check Y"}          → static guidance, no fetch
"""
import json
import os
import time
import urllib.parse
import urllib.request
from pathlib import Path

STORE = ".claude/memory/sources.json"
UA = "claude-bootstrap-skill-finder/1.1"
TIMEOUT = 15
KINDS = {"github_org", "http_json", "hint"}


def _path(root):
    return Path(root) / STORE


def load(root="."):
    p = _path(root)
    if not p.exists():
        return {"version": 1, "sources": []}
    try:
        d = json.loads(p.read_text(encoding="utf-8", errors="ignore"))
        if not isinstance(d.get("sources"), list):
            d["sources"] = []
        return d
    except Exception:
        return {"version": 1, "sources": []}


def validate(obj):
    """Gate a learned source before it becomes durable (mirrors learn.py)."""
    errs = []
    if not isinstance(obj, dict):
        return False, ["source must be a JSON object"], None
    kind = (obj.get("kind") or "").strip()
    if kind not in KINDS:
        return False, [f"kind must be one of {sorted(KINDS)}"], None
    norm = {"kind": kind, "note": str(obj.get("note", ""))[:200], "added_at": int(time.time())}
    if kind == "github_org":
        org = (obj.get("org") or "").strip()
        if not org or "/" in org or " " in org:
            errs.append("github_org needs a bare `org` (no slashes/spaces)")
        norm["org"] = org
        norm["name"] = f"github:{org}"
    elif kind == "http_json":
        url = (obj.get("url") or "").strip()
        if not url.startswith("https://"):
            errs.append("http_json `url` must be https://")
        if "{query}" not in url:
            errs.append("http_json `url` must contain the {query} placeholder")
        if not obj.get("name_field"):
            errs.append("http_json needs `name_field`")
        norm.update({"name": (obj.get("name") or url[:40]).strip(), "url": url,
                     "list_path": str(obj.get("list_path", "")),
                     "name_field": str(obj.get("name_field", "")),
                     "url_field": str(obj.get("url_field", ""))})
    elif kind == "hint":
        text = (obj.get("text") or "").strip()
        if not text:
            errs.append("hint needs non-empty `text`")
        norm.update({"name": (obj.get("name") or "hint").strip(), "text": text})
    if errs:
        return False, errs, None
    return True, [], norm


def add(root, obj):
    ok, errs, norm = validate(obj)
    if not ok:
        return False, errs
    store = load(root)
    key = (norm["kind"], norm.get("org") or norm.get("url") or norm.get("text"))
    if any((s["kind"], s.get("org") or s.get("url") or s.get("text")) == key for s in store["sources"]):
        return True, ["(already a known source — no change)"]
    store["sources"].append(norm)
    p = _path(root)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(store, indent=2), encoding="utf-8")
    return True, []


def _get(url, headers=None):
    h = {"User-Agent": UA, "Accept": "application/json"}
    if headers:
        h.update(headers)
    if os.environ.get("GITHUB_TOKEN") and "api.github.com" in url:
        h["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=TIMEOUT) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return None


def _dig(obj, dotted):
    if not dotted:
        return obj
    for part in dotted.split("."):
        if isinstance(obj, dict):
            obj = obj.get(part)
        else:
            return None
    return obj


def query(root, q, keywords=None):
    """Query every learned source for `q`; return normalized candidates."""
    keywords = keywords or []
    out = []
    for s in load(root).get("sources", []):
        kind = s.get("kind")
        try:
            if kind == "github_org":
                url = ("https://api.github.com/search/repositories?q="
                       + urllib.parse.quote(f"{q} user:{s['org']}") + "&sort=stars&per_page=6")
                data = _get(url)
                for it in (data.get("items", []) if isinstance(data, dict) else []):
                    out.append({"source": f"learned:{s['name']}", "kind": "repo",
                                "name": it.get("full_name", ""), "url": it.get("html_url", ""),
                                "install": f"add via /marketplace (enter {it.get('full_name','')}), then /plugin install",
                                "match": 3, "trust": 75, "flags": ["learned", f"{it.get('stargazers_count',0)}★"]})
            elif kind == "http_json":
                url = s["url"].replace("{query}", urllib.parse.quote(q))
                data = _get(url)
                items = _dig(data, s.get("list_path", "")) or []
                if isinstance(items, dict):
                    items = list(items.values())
                for it in (items if isinstance(items, list) else [])[:6]:
                    if not isinstance(it, dict):
                        continue
                    out.append({"source": f"learned:{s['name']}", "kind": "external",
                                "name": str(_dig(it, s["name_field"]) or ""),
                                "url": str(_dig(it, s.get("url_field", "")) or ""),
                                "install": "(see url)", "match": 3, "trust": 65, "flags": ["learned"]})
            elif kind == "hint":
                hit = any(k in s["text"].lower() for k in keywords) if keywords else False
                out.append({"source": f"learned:{s['name']}", "kind": "hint",
                            "name": s["text"][:80], "url": "", "install": s["text"],
                            "match": 3 if hit else 1, "trust": 70, "flags": ["learned", "hint"]})
        except Exception:
            continue
    return out

#!/usr/bin/env python3
"""
skill_finder.py — discover Claude Code skills / agents / MCP servers across the
open ecosystem, then rank and vet them. Pure Python stdlib (urllib), offline-
tolerant: any source that fails is skipped, never fatal (the nodo ethos).

Sources searched (all public, read-only):
  • Anthropic official skills   github.com/anthropics/skills (Contents API)
  • GitHub topic + code search  repos tagged agent-skills / claude-skills, SKILL.md files
  • MCP Registry                registry.modelcontextprotocol.io (for service/tool needs)
  • Smithery (optional)         api.smithery.ai  (only if SMITHERY_API_KEY is set)

Usage:
  python3 skill_finder.py "<what the user is trying to do>" [--limit N] [--json]
  python3 skill_finder.py "stripe payments" --json

Output: a ranked, vetted candidate list. Each candidate carries a `trust` score
and `flags` so the caller (a skill, or Claude) can decide what is safe to install.
A GITHUB_TOKEN env var (optional) raises the GitHub rate limit.
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request

UA = "claude-bootstrap-skill-finder/1.0 (+https://github.com/shivae372/claude-bootstrap)"
TIMEOUT = 15


def _get(url, headers=None, token_env=None):
    """HTTP GET → parsed JSON, or None on any failure. Honors HTTPS_PROXY."""
    h = {"User-Agent": UA, "Accept": "application/json"}
    if headers:
        h.update(headers)
    if token_env and os.environ.get(token_env):
        h["Authorization"] = f"Bearer {os.environ[token_env]}"
    try:
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception as e:
        return {"__error__": f"{type(e).__name__}: {e}"}


def _kw(q):
    return [w for w in "".join(c if c.isalnum() else " " for c in q.lower()).split() if len(w) > 2]


# ── Sources ───────────────────────────────────────────────────────────────────
def from_anthropic_skills(keywords):
    """List skills in anthropics/skills and score by keyword overlap with name."""
    out = []
    data = _get("https://api.github.com/repos/anthropics/skills/contents/skills",
                token_env="GITHUB_TOKEN")
    if not isinstance(data, list):
        return out
    for item in data:
        if item.get("type") != "dir":
            continue
        name = item.get("name", "")
        # Name is short; match on the name AND its hyphen-split tokens.
        haystack = name.lower().replace("-", " ")
        score = sum(1 for k in keywords if k in haystack)
        if score < 1:
            continue  # don't dump the whole official catalog — only real matches
        out.append({
            "source": "anthropic/skills", "kind": "skill", "name": name,
            "url": f"https://github.com/anthropics/skills/tree/main/skills/{name}",
            "install": f"/plugin marketplace add anthropics/skills  →  /plugin install {name}",
            "match": score, "trust": 100, "flags": ["official"],
        })
    return out


def from_github_repos(query, keywords):
    """Search repos for the query terms + Claude skill signals; vet by stars/age.
    Runs two targeted searches (topic-scoped, then broad) and merges them."""
    out = []
    kw = " ".join(keywords[:3]) or query
    queries = [
        f"{kw} topic:agent-skills",
        f"{kw} claude skill in:name,description,readme",
    ]
    items, seen = [], set()
    err = None
    for qstr in queries:
        url = ("https://api.github.com/search/repositories?q="
               + urllib.parse.quote(qstr) + "&sort=stars&per_page=10")
        data = _get(url, token_env="GITHUB_TOKEN")
        if isinstance(data, dict) and data.get("__error__"):
            err = data["__error__"]; continue
        for it in (data.get("items", []) if isinstance(data, dict) else []):
            fn = it.get("full_name", "")
            if fn and fn not in seen:
                seen.add(fn); items.append(it)
    if err and not items:
        raise RuntimeError(err)  # surfaced as a skipped source (likely rate limit)
    now = time.time()
    for it in items:
        stars = it.get("stargazers_count", 0)
        created = it.get("created_at", "")
        age_days = 0
        try:
            age_days = (now - time.mktime(time.strptime(created, "%Y-%m-%dT%H:%M:%SZ"))) / 86400
        except Exception:
            pass
        flags, trust = [], 0
        if stars >= 50: trust += 40; flags.append(f"{stars}★")
        elif stars >= 10: trust += 20; flags.append(f"{stars}★")
        if age_days >= 30: trust += 20; flags.append("mature")
        else: flags.append("new(<30d)")
        if it.get("description"): trust += 10
        text = (it.get("description", "") + " " + it.get("name", "")).lower()
        match = sum(1 for k in keywords if k in text)
        out.append({
            "source": "github", "kind": "repo", "name": it.get("full_name", ""),
            "url": it.get("html_url", ""), "stars": stars,
            "install": f"/plugin marketplace add {it.get('full_name','')}",
            "match": match, "trust": trust, "flags": flags,
        })
    return out


def from_mcp_registry(query):
    """Search the official MCP Registry for servers matching a service/tool need.
    The registry does substring matching, so search per-keyword and merge."""
    out = []
    keywords = _kw(query)
    servers, seen = [], set()
    terms = keywords or [query]
    for term in terms[:4]:
        url = ("https://registry.modelcontextprotocol.io/v0/servers?search="
               + urllib.parse.quote(term) + "&limit=8")
        data = _get(url)
        for s in (data.get("servers", []) if isinstance(data, dict) else []):
            meta = s.get("server", s) if isinstance(s, dict) else {}
            nm = meta.get("name", "") or s.get("name", "")
            if nm and nm not in seen:
                seen.add(nm); servers.append(s)
    for s in servers:
        meta = s.get("server", s) if isinstance(s, dict) else {}
        name = meta.get("name", "") or s.get("name", "")
        status = (s.get("_meta", {}) or {}).get("status") or s.get("status", "active")
        if status == "deleted":
            continue
        desc = meta.get("description", "") or ""
        text = (name + " " + desc).lower()
        match = sum(1 for k in keywords if k in text)
        out.append({
            "source": "mcp-registry", "kind": "mcp", "name": name,
            "url": meta.get("repository", {}).get("url", "") if isinstance(meta.get("repository"), dict) else "",
            "desc": desc[:120],
            "install": f"claude mcp add {name.split('/')[-1].split('.')[-1]} ...",
            "match": match, "trust": 60, "flags": ["mcp", status],
        })
    return out


def from_smithery(query):
    """Search Smithery for verified MCP servers (only if SMITHERY_API_KEY is set)."""
    if not os.environ.get("SMITHERY_API_KEY"):
        return []
    out = []
    url = "https://api.smithery.ai/servers?q=" + urllib.parse.quote(query) + "&verified=true&pageSize=10"
    data = _get(url, token_env="SMITHERY_API_KEY")
    for s in (data.get("servers", []) if isinstance(data, dict) else []):
        out.append({
            "source": "smithery", "kind": "mcp", "name": s.get("qualifiedName", ""),
            "url": s.get("homepage", ""), "install": f"npx -y @smithery/cli install {s.get('qualifiedName','')}",
            "match": 2, "trust": 70 if s.get("verified") else 40,
            "flags": ["mcp"] + (["verified"] if s.get("verified") else []),
        })
    return out


def discover(query, limit=10):
    keywords = _kw(query)
    cands, errors = [], {}
    for fn in (from_anthropic_skills, from_github_repos, from_mcp_registry, from_smithery):
        try:
            if fn is from_anthropic_skills:
                res = fn(keywords)
            elif fn is from_github_repos:
                res = fn(query, keywords)
            else:
                res = fn(query)
            cands.extend(res)
        except Exception as e:
            errors[fn.__name__] = str(e)
    # Dedupe by (source, name).
    seen, deduped = set(), []
    for c in cands:
        key = (c.get("source"), c.get("name"))
        if key in seen:
            continue
        seen.add(key); deduped.append(c)
    cands = deduped
    # Rank: relevance dominates (match×100), trust is the tiebreaker. A zero-match
    # official skill can never outrank a real keyword hit from any source.
    cands.sort(key=lambda c: c.get("match", 0) * 100 + c.get("trust", 0), reverse=True)
    return {"query": query, "keywords": keywords,
            "candidates": cands[:limit], "total_found": len(cands), "errors": errors}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query")
    ap.add_argument("--limit", type=int, default=10)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    res = discover(args.query, args.limit)
    if args.json:
        print(json.dumps(res, indent=2))
        return
    print(f"\nDiscovery for: {args.query!r}  ({res['total_found']} candidates)\n")
    for c in res["candidates"]:
        print(f"  [{c['source']:14}] {c['name']}")
        print(f"       trust={c['trust']:>3} match={c.get('match',0)} flags={','.join(c['flags'])}")
        print(f"       install: {c['install']}")
    if res["errors"]:
        print("\n  (sources skipped:", ", ".join(res["errors"].keys()), ")")


if __name__ == "__main__":
    main()

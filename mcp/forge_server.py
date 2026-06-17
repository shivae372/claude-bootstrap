#!/usr/bin/env python3
"""
forge_server.py — a tiny MCP server (stdio, JSON-RPC 2.0, pure stdlib) that exposes
the Forge engine as live tools, so Claude can grow and heal the setup in real time,
mid-session, without leaving the conversation.

Tools:
  discover_skill     search the open ecosystem for a fitting skill/MCP (ranked, vetted)
  capability_audit   what skills/commands/agents/hooks are installed here
  heal_report        diagnose the setup; optionally apply safe auto-fixes
  record_learning    persist a durable, validated project learning

It reuses the tested CLI engine via subprocess (no import-path fragility). Register
it through .mcp.json or a plugin's mcpServers. Protocol: newline-delimited JSON-RPC.
"""
import json
import os
import subprocess
import sys
from pathlib import Path

SERVER = {"name": "forge", "version": "1.0.0"}
PROTOCOL = "2024-11-05"


def engine_dir():
    for c in (os.environ.get("CLAUDE_BOOTSTRAP_ENGINE"),
              ".claude/engine", "engine",
              str(Path(__file__).resolve().parent.parent / "engine")):
        if c and (Path(c) / "doctor.py").exists():
            return c
    return ".claude/engine"


def _run(args, stdin_text=None):
    try:
        r = subprocess.run([sys.executable, *args], input=stdin_text,
                           capture_output=True, text=True, timeout=60)
        return (r.stdout or r.stderr or "").strip()
    except Exception as e:
        return f"error: {e}"


def _txt(s):
    return {"content": [{"type": "text", "text": s}]}


TOOLS = [
    {"name": "discover_skill",
     "description": "Search the open ecosystem (Anthropic skills, GitHub, MCP Registry, Smithery) "
                    "for a skill or MCP server matching a capability. Returns ranked, vetted candidates.",
     "inputSchema": {"type": "object", "properties": {
         "query": {"type": "string", "description": "capability, e.g. 'stripe payments'"},
         "limit": {"type": "integer", "default": 8}}, "required": ["query"]}},
    {"name": "capability_audit",
     "description": "List the skills, commands, agents and hooks currently installed in this project.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "heal_report",
     "description": "Diagnose the Claude Code setup (health score + findings + fixes). "
                    "Set apply=true to perform safe auto-fixes.",
     "inputSchema": {"type": "object", "properties": {
         "apply": {"type": "boolean", "default": False}}}},
    {"name": "record_learning",
     "description": "Persist a durable, validated learning about this project so future "
                    "sessions start smarter.",
     "inputSchema": {"type": "object", "properties": {
         "category": {"type": "string",
                      "enum": ["preference", "stack", "convention", "workflow", "fix", "gap", "fact"]},
         "text": {"type": "string"},
         "tags": {"type": "array", "items": {"type": "string"}}},
         "required": ["category", "text"]}},
]


def call_tool(name, args):
    e = engine_dir()
    if name == "discover_skill":
        return _txt(_run([f"{e}/skill_finder.py", str(args.get("query", "")),
                          "--limit", str(args.get("limit", 8)), "--json"]))
    if name == "capability_audit":
        return _txt(_run([f"{e}/doctor.py", "--manifest", "--json"]))
    if name == "heal_report":
        a = [f"{e}/doctor.py", "--json"]
        if args.get("apply"):
            a.append("--apply")
        return _txt(_run(a))
    if name == "record_learning":
        payload = json.dumps({"category": args.get("category"), "text": args.get("text"),
                              "tags": args.get("tags", [])})
        return _txt(_run([f"{e}/learn.py", "add"], stdin_text=payload))
    return {"content": [{"type": "text", "text": f"unknown tool {name}"}], "isError": True}


def handle(msg):
    mid = msg.get("id")
    method = msg.get("method", "")
    if method == "initialize":
        return {"jsonrpc": "2.0", "id": mid, "result": {
            "protocolVersion": PROTOCOL,
            "capabilities": {"tools": {}},
            "serverInfo": SERVER}}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": mid, "result": {"tools": TOOLS}}
    if method == "tools/call":
        p = msg.get("params", {}) or {}
        try:
            res = call_tool(p.get("name", ""), p.get("arguments", {}) or {})
            return {"jsonrpc": "2.0", "id": mid, "result": res}
        except Exception as ex:
            return {"jsonrpc": "2.0", "id": mid,
                    "result": {"content": [{"type": "text", "text": f"error: {ex}"}], "isError": True}}
    if method.startswith("notifications/"):
        return None  # notifications get no response
    if mid is not None:
        return {"jsonrpc": "2.0", "id": mid,
                "error": {"code": -32601, "message": f"method not found: {method}"}}
    return None


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            continue
        resp = handle(msg)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()

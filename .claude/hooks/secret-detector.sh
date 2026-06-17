#!/usr/bin/env bash
# PreToolUse hook (Write|Edit|MultiEdit): secret-detector.sh
# Stops real credentials from being written to disk — without crying wolf on
# placeholders and examples (the #1 reason secret hooks get disabled).
#
# Correctly inspects every write path:
#   Write      → tool_input.content
#   Edit       → tool_input.new_string
#   MultiEdit  → tool_input.edits[].new_string
# High-confidence provider keys BLOCK (exit 2, reason on stderr — Claude reads stderr).
# Low-confidence "looks secret-ish" findings WARN but allow (exit 0), so routine code
# like `password = "changeme"` never derails you.
#
# Bypass once:  CLAUDE_BOOTSTRAP_ALLOW_SECRETS=1
set -uo pipefail

if [ "${CLAUDE_BOOTSTRAP_ALLOW_SECRETS:-0}" = "1" ]; then exit 0; fi

INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0

# Prefer the robust Python analyzer; fall back to a minimal grep if python is absent.
if command -v python3 >/dev/null 2>&1; then
  VERDICT="$(printf '%s' "$INPUT" | python3 -c '
import sys, json, re

try:
    d = json.load(sys.stdin)
except Exception:
    print("ALLOW"); sys.exit(0)

tool = d.get("tool_name", "")
inp = d.get("tool_input", {}) or {}

chunks = []
if tool == "Write":
    chunks.append(inp.get("content", "") or "")
elif tool in ("Edit", "str_replace_based_edit_tool"):
    chunks.append(inp.get("new_string", inp.get("new_str", "")) or "")
elif tool == "MultiEdit":
    for e in inp.get("edits", []) or []:
        chunks.append(e.get("new_string", "") or "")
else:
    # Unknown writer shape: scan everything we were given.
    chunks.append(json.dumps(inp))
content = "\n".join(chunks)
if not content.strip():
    print("ALLOW"); sys.exit(0)

# High-confidence: provider-issued credentials. These are essentially never placeholders.
HIGH = [
    (r"sk-ant-[A-Za-z0-9_-]{20,}", "Anthropic API key"),
    (r"sk-[A-Za-z0-9]{20,}", "OpenAI-style API key (sk-…)"),
    (r"sk_live_[A-Za-z0-9]{16,}", "Stripe live secret key"),
    (r"rk_live_[A-Za-z0-9]{16,}", "Stripe live restricted key"),
    (r"AKIA[0-9A-Z]{16}", "AWS access key id"),
    (r"ghp_[A-Za-z0-9]{36}", "GitHub personal access token"),
    (r"gh[ousr]_[A-Za-z0-9]{36}", "GitHub token"),
    (r"github_pat_[A-Za-z0-9_]{22,}", "GitHub fine-grained PAT"),
    (r"glpat-[A-Za-z0-9_-]{20}", "GitLab PAT"),
    (r"AIza[0-9A-Za-z_-]{35}", "Google API key"),
    (r"xox[baprs]-[A-Za-z0-9-]{10,}", "Slack token"),
    (r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----", "Private key block"),
]

# Treat these as obviously-not-a-real-secret.
PLACEHOLDER = re.compile(
    r"your[_-]?|changeme|example|sample|dummy|placeholder|redacted|xxxx|"
    r"<[^>]+>|\$\{|process\.env|import\.meta\.env|os\.environ|os\.getenv|"
    r"getenv\(|secrets\.|vault|\bfake\b|\btest[_-]?key\b|0{8,}|abc123", re.I)

# Password-only placeholder check (host/domain may legitimately be example.com).
PW_PLACEHOLDER = re.compile(
    r"^(your[_-]?|changeme|example|sample|dummy|placeholder|redacted|xxxx|"
    r"password|pass|user|pwd|secret|\$\{|<)", re.I)

found = []
for pat, label in HIGH:
    for m in re.finditer(pat, content):
        tok = m.group(0)
        if PLACEHOLDER.search(tok):
            continue
        found.append(label)
        break

# DB URL with inline credentials — judge the PASSWORD, not the whole URL.
for m in re.finditer(
        r"(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?)://([^:\s/]+):([^@\s]+)@[^\s\x22\x27]+",
        content):
    pw = m.group(2)
    if PW_PLACEHOLDER.search(pw) or len(pw) < 5:
        continue
    found.append("DB URL with inline credentials")
    break

if found:
    print("BLOCK:" + "; ".join(sorted(set(found))))
    sys.exit(0)

# Low-confidence generic assignment — warn, never block.
GENERIC = re.compile(
    r"(password|passwd|secret|api[_-]?key|apikey|auth[_-]?token|access[_-]?token)"
    r"\s*[:=]\s*[\x27\"][^\x27\"]{8,}[\x27\"]", re.I)
for m in GENERIC.finditer(content):
    if PLACEHOLDER.search(m.group(0)):
        continue
    print("WARN:hardcoded-credential-pattern")
    sys.exit(0)

print("ALLOW")
' 2>/dev/null || echo "ALLOW")"
else
  # Minimal fallback: only the unmistakable provider prefixes.
  if printf '%s' "$INPUT" | grep -qE 'sk-ant-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
    VERDICT="BLOCK:high-confidence credential"
  else
    VERDICT="ALLOW"
  fi
fi

case "$VERDICT" in
  BLOCK:*)
    {
      echo "🔐 BLOCKED by secret-detector: ${VERDICT#BLOCK:}"
      echo "A real credential appears in this write. Use an env var instead (e.g. process.env.X / os.environ[\"X\"])."
      echo "If this is intentional (test fixture, rotation), re-run with CLAUDE_BOOTSTRAP_ALLOW_SECRETS=1."
    } >&2
    exit 2 ;;
  WARN:*)
    echo "⚠️  secret-detector: a hardcoded credential-like value was written. Verify it is not a real secret." >&2
    exit 0 ;;
  *)
    exit 0 ;;
esac

# Launch kit

Ready-to-post copy for announcing claude-bootstrap. Edit freely; the hooks are designed to be
concrete (what it *does*) rather than hypey — that's what travels.

---

## One-liners (pick one)

- The last Claude Code setup you'll install — because it grows itself.
- Most setups rot. This one heals itself and learns new skills as you work.
- `curl | bash` → a Claude Code setup that finds, installs, or *forges* the skills your project needs, mid-task.

---

## X / Twitter thread

**1/**
I got tired of Claude Code setups that rot, break, and hit a wall the second you need something you didn't pre-install.

So I built one that installs itself, heals itself, and teaches itself new skills *as you work*.

One command. Works for coders and non-coders. 🧵

```
curl -fsSL https://raw.githubusercontent.com/shivae372/claude-bootstrap/master/install.sh | bash
```

**2/**
The install is deterministic — no LLM call, no waiting, no questionnaire. It detects your stack and drops in a curated, tested config: sub-agents, skills, slash-commands, safety hooks, a tailored CLAUDE.md, session memory.

Then the interesting part starts.

**3/**
Ask for something it can't do yet — "add Stripe checkout", "deploy to Fly.io" — and a hook notices the gap mid-task and runs `augment`:

it searches the open ecosystem (Anthropic skills, GitHub, the MCP Registry, Smithery), vets candidates, and installs the best one.

Right then. In the same conversation.

**4/**
Nothing fits? It `forge`s a new skill — and a validator *rejects generic stubs*, so what you get is specific to YOUR project, not boilerplate.

**5/**
It heals itself. `doctor` scores your setup's health, finds broken skills/hooks/config, and applies safe fixes. Repeated tool failures auto-trigger a heal nudge.

**6/**
It learns. Tell it "we deploy via Fly, never Vercel" and it remembers — a SessionStart hook feeds your project's accumulated knowledge back every session. No more re-explaining.

**7/**
My favorite part: discovery is *self-extending*.

If the web search misses something but Claude finds it another way, it records that source — and searches it next time too, alongside the web. Your setup's reach compounds.

**8/**
It's all built on real Claude Code primitives — skills, hooks, an MCP server, plugin packaging — and it's pure-Python stdlib, offline-tolerant, validated before anything is saved. 74 automated tests, CI on Linux + macOS.

**9/**
Free, Apache-2.0, zero dependencies.

⭐ https://github.com/shivae372/claude-bootstrap

Tell it what you're building. Watch it grow into the exact toolkit you need.

---

## Show HN / Reddit title

`Show HN: A Claude Code setup that finds, installs, or forges the skills your project needs — mid-task`

## 60-second demo script (for a screen recording / GIF)

1. `curl … | bash` in a fresh repo → setup lands in seconds.
2. Start Claude: ask "help me add Stripe checkout."
3. The gap hook fires → Claude runs `augment` → finds the official Stripe MCP server → installs it.
4. Ask "is my setup healthy?" → `/doctor` → 100/100.
5. Say "remember we deploy via Fly" → `learn` stores it → show it injected on next session start.
6. End on the tagline: *it grows itself.*

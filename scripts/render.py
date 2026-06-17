#!/usr/bin/env python3
"""
render.py — turn a tier CLAUDE.md template + detected project facts into a final,
tailored CLAUDE.md. Pure, deterministic, no network, no LLM.

Usage:
  python3 render.py --template docs/templates/developer/CLAUDE.md.tpl \\
      --detected-json '<json>' --project-name myapp --tier developer \\
      --stack-key nextjs --version 1.0.0 > CLAUDE.md

Any {{VARIABLE}} left without a value is replaced with a neutral placeholder so the
output never ships raw mustache tags.
"""
import argparse
import json
import re
import sys

# Per package-manager command sets. Keys are best-effort; fall back to language.
PM_COMMANDS = {
    "pnpm":   dict(install="pnpm install", dev="pnpm dev", test="pnpm test", build="pnpm build"),
    "yarn":   dict(install="yarn install", dev="yarn dev", test="yarn test", build="yarn build"),
    "npm":    dict(install="npm install", dev="npm run dev", test="npm test", build="npm run build"),
    "bun":    dict(install="bun install", dev="bun dev", test="bun test", build="bun run build"),
    "pip":    dict(install="pip install -r requirements.txt", dev="python -m app", test="pytest", build="python -m build"),
    "poetry": dict(install="poetry install", dev="poetry run python -m app", test="poetry run pytest", build="poetry build"),
    "uv_or_poetry": dict(install="uv sync", dev="uv run python -m app", test="uv run pytest", build="uv build"),
    "cargo":  dict(install="cargo build", dev="cargo run", test="cargo test", build="cargo build --release"),
    "go":     dict(install="go mod download", dev="go run ./...", test="go test ./...", build="go build ./..."),
    "go_modules": dict(install="go mod download", dev="go run ./...", test="go test ./...", build="go build ./..."),
    "bundler": dict(install="bundle install", dev="bundle exec rails server", test="bundle exec rspec", build="bundle exec rake build"),
    "maven_or_gradle": dict(install="mvn install", dev="mvn spring-boot:run", test="mvn test", build="mvn package"),
}

LANG_FALLBACK = {
    "javascript": "npm", "typescript": "npm", "python": "pip",
    "rust": "cargo", "go": "go", "ruby": "bundler", "java": "maven_or_gradle",
}

DEPLOY_HINT = {
    "Vercel": "Vercel", "GitHub Actions": "your CI pipeline", "GitLab CI": "GitLab CI",
}


def derive_commands(detected):
    pm = detected.get("package_manager", "unknown")
    lang = detected.get("language", "unknown")
    cmds = PM_COMMANDS.get(pm)
    if not cmds:
        cmds = PM_COMMANDS.get(LANG_FALLBACK.get(lang, ""), None)
    if not cmds:
        cmds = dict(install="<install command>", dev="<dev command>",
                    test="<test command>", build="<build command>")
    return cmds


def derive_deploy_target(detected):
    for c in detected.get("ci", []) or []:
        if c in DEPLOY_HINT:
            return DEPLOY_HINT[c]
    return "your configured target"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--template", required=True)
    ap.add_argument("--detected-json", default="{}")
    ap.add_argument("--project-name", default="project")
    ap.add_argument("--tier", default="developer")
    ap.add_argument("--stack-key", default="no-stack")
    ap.add_argument("--version", default="1.0.0")
    args = ap.parse_args()

    try:
        detected = json.loads(args.detected_json) if args.detected_json else {}
    except json.JSONDecodeError:
        detected = {}

    stack_list = detected.get("stack", []) or []
    language = detected.get("language", "unknown")
    stack_str = ", ".join(stack_list) if stack_list else (
        language if language != "unknown" else "general project")

    cmds = derive_commands(detected)
    dbs = detected.get("databases", []) or []

    values = {
        "PROJECT_NAME": args.project_name,
        "STACK": stack_str,
        "LANGUAGE": language,
        "PACKAGE_MANAGER": detected.get("package_manager", "unknown"),
        "INSTALL_CMD": cmds["install"],
        "DEV_CMD": cmds["dev"],
        "TEST_CMD": cmds["test"],
        "BUILD_CMD": cmds["build"],
        "DEPLOY_CMD": cmds["build"],
        "DEPLOY_TARGET": derive_deploy_target(detected),
        "PROJECT_DESCRIPTION": f"A {stack_str} project." if stack_list else
            "Describe your project here so Claude has the right context.",
        "PROJECT_STRUCTURE": "_Run `/analyze-repo` to map the codebase, then refine this section._",
        "KEY_FILES": ", ".join(detected.get("key_files", []) or []) or "_to be mapped_",
        "WORKFLOW": "Describe how you like to work; Claude will follow it.",
        "PRIMARY_GOALS": "ship reliably, move fast, keep quality high",
        "TECH_LEVEL": str(detected.get("tech_level", "")),
        "ROLE": detected.get("role", ""),
        "GOALS": detected.get("goals", ""),
        "DATABASE": ", ".join(dbs) if dbs else "none detected",
        "VERSION": args.version,
    }

    text = open(args.template, encoding="utf-8").read()

    def repl(m):
        key = m.group(1).strip()
        return str(values.get(key, "_(not set)_"))

    text = re.sub(r"\{\{\s*([A-Z_]+)\s*\}\}", repl, text)

    header = (f"<!-- Generated by claude-bootstrap v{args.version} "
              f"(tier: {args.tier}, stack: {args.stack_key}). "
              f"Safe to edit — re-running install backs up before changes. -->\n")
    sys.stdout.write(header + text)


if __name__ == "__main__":
    main()

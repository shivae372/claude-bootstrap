#!/usr/bin/env bash
# bootstrap.sh — backward-compatible entry point.
# The bootstrap is now a deterministic installer. This shim forwards to install.sh
# so older docs/links (`bash claude-bootstrap/scripts/bootstrap.sh`) keep working.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "▸ scripts/bootstrap.sh now delegates to install.sh (deterministic setup)."
echo "  For all options: bash install.sh --help"
echo ""
exec bash "$HERE/../install.sh" "$@"

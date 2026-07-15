#!/usr/bin/env bash
# helix-nav.sh — wrapper for the Helix internal browser (quarantine pipeline).
# Usage: helix-nav.sh <url|search:query> [flags]   (see helix-nav.py --help)
set -uo pipefail
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && \
  source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${HELIX_PYTHON:-python3}" "$SCRIPT_DIR/helix-nav.py" "$@"

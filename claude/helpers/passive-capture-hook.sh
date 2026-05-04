#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# Thin wrapper around passive-capture-hook.py.
# Reads stdin, passes to Python implementation. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/passive-capture-hook.py"

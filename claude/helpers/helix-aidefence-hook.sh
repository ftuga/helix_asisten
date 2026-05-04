#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# Thin wrapper for SEC1 helix-aidefence. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-aidefence-hook.py"

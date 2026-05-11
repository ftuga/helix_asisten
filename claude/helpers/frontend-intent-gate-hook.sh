#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# Thin wrapper around frontend-intent-gate-hook.py. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/frontend-intent-gate-hook.py"

#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# Thin wrapper around helix-egress-audit-hook.py. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-egress-audit-hook.py"

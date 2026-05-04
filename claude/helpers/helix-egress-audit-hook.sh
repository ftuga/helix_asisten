#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# Thin wrapper around helix-egress-audit-hook.py. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "$HOME/.claude/helpers/helix-egress-audit-hook.py"

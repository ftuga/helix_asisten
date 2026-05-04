#!/usr/bin/env bash
# Thin wrapper around helix-egress-audit-hook.py. Always exit 0.
exec python3 "$HOME/.claude/helpers/helix-egress-audit-hook.py"

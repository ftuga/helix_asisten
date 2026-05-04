#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# Thin wrapper around passive-capture-hook.py.
# Reads stdin, passes to Python implementation. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "$HOME/.claude/helpers/passive-capture-hook.py"

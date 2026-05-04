#!/usr/bin/env bash
# Thin wrapper around passive-capture-hook.py.
# Reads stdin, passes to Python implementation. Always exit 0.
exec python3 "$HOME/.claude/helpers/passive-capture-hook.py"

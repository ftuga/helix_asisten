#!/usr/bin/env bash
# Thin wrapper for SEC1 helix-aidefence. Always exit 0.
exec python3 "$HOME/.claude/helpers/helix-aidefence-hook.py"

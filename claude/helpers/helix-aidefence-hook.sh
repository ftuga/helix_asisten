#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# Thin wrapper for SEC1 helix-aidefence. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "$HOME/.claude/helpers/helix-aidefence-hook.py"

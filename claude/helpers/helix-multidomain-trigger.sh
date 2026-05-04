#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# Thin wrapper for D1' multi-domain advisory. Always exit 0.
exec "${HELIX_PYTHON:-python3}" "$HOME/.claude/helpers/helix-multidomain-trigger.py"

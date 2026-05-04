#!/usr/bin/env bash
# Thin wrapper for D1' multi-domain advisory. Always exit 0.
exec python3 "$HOME/.claude/helpers/helix-multidomain-trigger.py"

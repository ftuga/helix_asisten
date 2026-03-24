#!/usr/bin/env bash
# claude-ui.sh — Launcher para la TUI de Claude Flow V3
export TERM=xterm-256color
export COLORTERM=truecolor
exec python3 "$HOME/scripts/claude-ui.py" "$@"

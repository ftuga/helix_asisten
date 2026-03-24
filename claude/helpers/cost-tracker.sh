#!/usr/bin/env bash
# cost-tracker.sh — Contador de tool calls por sesión
# Disparado por PreToolUse(Write|Edit|MultiEdit|Bash|Read|Grep|Glob|Agent)
# Ultra-liviano: solo incrementa un contador en /tmp. Exit 0 siempre.
set -uo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H)}"
COUNTER_FILE="/tmp/helix-cost-${SESSION_ID}"

# Leer + incrementar atómicamente
if [[ -f "$COUNTER_FILE" ]]; then
    COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
    COUNT=$((COUNT + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

exit 0

#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# agents-vector-sync-hook.sh — Re-indexar helix_agents al editar un agente
# Disparado por PostToolUse(Write|Edit|MultiEdit).
# No bloquea: exit 0 inmediato, el sync corre en background con debounce.
set -uo pipefail

export HELIX_PAYLOAD
HELIX_PAYLOAD=$(cat 2>/dev/null || echo "{}")

FILE_PATH=$("${HELIX_PYTHON:-python3}" -c "
import os, json
try:
    d = json.loads(os.environ.get('HELIX_PAYLOAD', '{}'))
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

[[ -z "$FILE_PATH" ]] && exit 0

# Solo reaccionar a agentes globales o sus descriptions on-demand
case "$FILE_PATH" in
  "$HOME/.claude/agents/"*.md) ;;
  "$HOME/.claude/memory/agents/"*.md) ;;
  *) exit 0 ;;
esac

LOG="$HOME/.claude/memory/agents-vector-sync.log"
LOCK="/tmp/helix-agents-vector-sync.lock"
DEBOUNCE_SECS=8

# Debounce: si ya hay un sync pendiente/corriendo en los últimos N segundos, saltamos.
# flock --nonblock evita apilar jobs cuando se editan varios agentes seguidos.
(
  flock -n 9 || { echo "[$(date '+%F %T')] SKIP locked ($FILE_PATH)" >> "$LOG"; exit 0; }
  # Pequeño delay para agrupar ediciones en ráfaga
  sleep "$DEBOUNCE_SECS"

  if ! curl -sf http://localhost:6333/healthz >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] SKIP qdrant-down ($FILE_PATH)" >> "$LOG"
    exit 0
  fi

  echo "[$(date '+%F %T')] SYNC start (trigger: $FILE_PATH)" >> "$LOG"
  if hv index-agents >>"$LOG" 2>&1; then
    echo "[$(date '+%F %T')] SYNC ok" >> "$LOG"
  else
    echo "[$(date '+%F %T')] SYNC fail" >> "$LOG"
  fi
) 9>"$LOCK" >/dev/null 2>&1 &
disown

exit 0

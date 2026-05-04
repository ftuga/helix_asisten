#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# evolve-flush.sh — Procesa la cola de evoluciones al final de cada turno (Stop hook)
# No falla aunque la cola esté vacía o haya errores individuales.
set -uo pipefail

QUEUE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/evolve-queue.jsonl"

[[ -f "$QUEUE" ]] || exit 0
[[ -s "$QUEUE" ]] || exit 0

# Mover cola a temp para procesarla (evita condición de carrera si Claude escribe más)
TMP=$(mktemp)
mv "$QUEUE" "$TMP"
touch "$QUEUE"

processed=0
failed=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  CAT=$(echo "$line" | "${HELIX_PYTHON:-python3}" -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('categoria', 'funcionalidad'))
except:
    print('funcionalidad')
" 2>/dev/null || echo "funcionalidad")

  APRENDIZAJE=$(echo "$line" | "${HELIX_PYTHON:-python3}" -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('aprendizaje', ''))
except:
    print('')
" 2>/dev/null || echo "")

  TRIGGER=$(echo "$line" | "${HELIX_PYTHON:-python3}" -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('trigger', 'auto-queue'))
except:
    print('auto-queue')
" 2>/dev/null || echo "auto-queue")

  [[ -z "$APRENDIZAJE" ]] && continue

  if bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/evolve.sh" learn "$CAT" "$APRENDIZAJE" "$TRIGGER" 2>/dev/null; then
    processed=$((processed + 1))
  else
    failed=$((failed + 1))
    # Re-encolar los fallidos
    echo "$line" >> "$QUEUE"
  fi
done < "$TMP"

rm -f "$TMP"

if [[ "$processed" -gt 0 ]]; then
  echo "[evolve-flush] ✅ $processed evoluciones registradas automáticamente" \
    >> "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/evolution-log.txt"
fi

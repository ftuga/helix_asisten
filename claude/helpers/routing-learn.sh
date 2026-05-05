#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# routing-learn.sh — Registrar decisiones de routing para aprendizaje
# Uso: bash ~/.claude/helpers/routing-learn.sh "<tarea>" "<agente>" "<resultado>"
# Resultado: success | partial | failed
#
# Genera historial en ~/.claude/memory/routing-feedback.jsonl
# session-start.sh lo consulta para sugerir el mejor agente por contexto similar.
set -uo pipefail

TAREA="${1:-}"
AGENTE="${2:-}"
RESULTADO="${3:-success}"  # success | partial | failed

if [[ -z "$TAREA" || -z "$AGENTE" ]]; then
  echo "Uso: bash routing-learn.sh '<tarea>' '<agente>' '[success|partial|failed]'"
  exit 1
fi

DATE=$(date '+%Y-%m-%d %H:%M')
FEEDBACK_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/routing-feedback.jsonl"
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory"

# Auto-detectar proyecto
# Guard portable: dirname(d)==d marca root (Win Git Bash: dirname "C:\x" → ".").
PROJECT=""
dir="$PWD"
prev=""
while [[ -n "$dir" && "$dir" != "$prev" && "$dir" != "/" && "$dir" != "." && "$dir" != "$HOME" ]]; do
  if [[ -f "$dir/CLAUDE.md" && "$dir" != "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ]]; then
    PROJECT=$(basename "$dir")
    break
  fi
  prev="$dir"
  dir=$(dirname "$dir")
done

# Extraer dominio de la tarea (primeras 2 palabras en minúsculas)
DOMINIO=$(echo "$TAREA" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z]+' | head -2 | tr '\n' '_' | sed 's/_$//')

# Escribir entrada JSONL
"${HELIX_PYTHON:-python3}" -c "
import json, sys
entry = {
    'ts': '$DATE',
    'tarea': '$TAREA',
    'dominio': '$DOMINIO',
    'agente': '$AGENTE',
    'resultado': '$RESULTADO',
    'proyecto': '$PROJECT'
}
print(json.dumps(entry, ensure_ascii=False))
" >> "$FEEDBACK_FILE"

echo "✅ Routing registrado: [$AGENTE] → $RESULTADO (dominio: $DOMINIO)"

# ── Mostrar top agentes para este dominio (si hay ≥3 registros) ──
COUNT=$(grep -c "\"dominio\": \"$DOMINIO\"" "$FEEDBACK_FILE" 2>/dev/null || echo "0")
if [[ "$COUNT" -ge 3 ]]; then
  echo ""
  echo "📊 Historial para dominio '$DOMINIO' ($COUNT registros):"
  "${HELIX_PYTHON:-python3}" -c "
import json
from collections import Counter
hits = []
with open('$FEEDBACK_FILE') as f:
    for line in f:
        try:
            d = json.loads(line)
            if d.get('dominio') == '$DOMINIO':
                hits.append((d['agente'], d['resultado']))
        except:
            pass
by_agent = Counter(a for a,_ in hits)
success_by_agent = Counter(a for a,r in hits if r == 'success')
for agent, total in by_agent.most_common(3):
    wins = success_by_agent.get(agent, 0)
    pct = int(wins/total*100)
    print(f'  {agent}: {wins}/{total} éxitos ({pct}%)')
"
fi

exit 0

#!/usr/bin/env bash
# agent-routing-hook.sh — PostToolUse(Agent): captura routing automáticamente
# Variables de entorno disponibles: CLAUDE_TOOL_INPUT, CLAUDE_TOOL_RESULT
set -uo pipefail

FEEDBACK="$HOME/.claude/memory/routing-feedback.jsonl"
mkdir -p "$HOME/.claude/memory"

INPUT="${CLAUDE_TOOL_INPUT:-}"
RESULT="${CLAUDE_TOOL_RESULT:-}"

[[ -z "$INPUT" ]] && exit 0

# Extraer subagent_type y description del input
AGENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(d.get('subagent_type', 'general-purpose'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

DESCRIPCION=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    prompt = d.get('prompt', d.get('description', ''))
    # Primeras 80 chars como resumen de tarea
    print(prompt[:80].replace('\n', ' ').strip())
except:
    print('')
" 2>/dev/null || echo "")

# Inferir resultado: largo/contenido del resultado
RESULTADO=$(echo "$RESULT" | python3 -c "
import sys
r = sys.stdin.read()
if not r or len(r) < 30:
    print('failed')
elif any(w in r.lower()[:200] for w in ['error', 'exception', 'failed', 'traceback']):
    print('partial')
else:
    print('success')
" 2>/dev/null || echo "unknown")

# Auto-detectar proyecto
PROJECT=""
dir="$PWD"
while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
  if [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]]; then
    PROJECT=$(basename "$dir")
    break
  fi
  dir=$(dirname "$dir")
done

DATE=$(date '+%Y-%m-%d %H:%M')

python3 -c "
import json, sys
entry = {
    'ts': '$DATE',
    'agente': '$AGENT',
    'tarea': '$DESCRIPCION',
    'resultado': '$RESULTADO',
    'proyecto': '$PROJECT',
}
print(json.dumps(entry, ensure_ascii=False))
" >> "$FEEDBACK" 2>/dev/null || true

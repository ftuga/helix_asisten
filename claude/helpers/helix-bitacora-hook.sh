#!/usr/bin/env bash
# helix-bitacora-hook.sh — Registrar cambios significativos en bitácora
# Disparado por PostToolUse(Write|Edit|MultiEdit)
# Recibe JSON en stdin. Siempre exit 0 — nunca bloquea a Helix.
set -uo pipefail

DATE=$(date '+%Y-%m-%d %H:%M')

# ── Leer payload y extraer file_path via env var (evita escaping) ──
export HELIX_PAYLOAD
HELIX_PAYLOAD=$(cat 2>/dev/null || echo "{}")

FILE_PATH=$(python3 -c "
import os, json
try:
    data = json.loads(os.environ.get('HELIX_PAYLOAD', '{}'))
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null || echo "")

[[ -z "$FILE_PATH" ]] && exit 0

# ── Filtro: ignorar archivos triviales ───────────────────────
is_trivial() {
  echo "$1" | grep -qE \
    "(node_modules|__pycache__|\.git/|dist/|build/|\.env|CLAUDE\.md|settings\.json|package-lock|yarn\.lock|helix-bitacora|helix-analysis)" \
    && return 0
  echo "$1" | grep -qE "\.(md|lock|log|toml|ini|cfg|json)$" && return 0
  return 1
}

is_trivial "$FILE_PATH" && exit 0

# ── Encontrar raíz del proyecto ───────────────────────────────
find_project_root() {
  local dir
  dir=$(python3 -c "import os; print(os.path.dirname(os.path.abspath('$FILE_PATH')))" 2>/dev/null || dirname "$FILE_PATH")
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]] && echo "$dir" && return 0
    dir=$(dirname "$dir")
  done
  # Fallback: usar PWD
  [[ -f "$PWD/CLAUDE.md" ]] && echo "$PWD" && return 0
  return 1
}

PROJECT_ROOT=$(find_project_root 2>/dev/null) || exit 0

BITACORA="$PROJECT_ROOT/.claude/memory/helix-bitacora.md"
[[ ! -f "$BITACORA" ]] && exit 0

# ── Nombre corto del archivo ──────────────────────────────────
SHORT_FILE=$(echo "$FILE_PATH" | sed "s|$PROJECT_ROOT/||" | sed "s|$HOME/||")
SESSION=$(date '+%Y-%m-%d')

# ── Insertar fila en tabla de cambios ─────────────────────────
export HELIX_ROW="| $DATE | \`$SHORT_FILE\` | modificado | $SESSION |"
export HELIX_BITACORA="$BITACORA"

python3 -c "
import os

file = os.environ['HELIX_BITACORA']
row  = os.environ['HELIX_ROW']

with open(file, 'r') as f:
    content = f.read()

header = '| Fecha | Archivo(s) | Cambio | Sesión |'
sep    = '|-------|-----------|--------|--------|'

if header in content:
    content = content.replace(
        header + '\n' + sep,
        header + '\n' + sep + '\n' + row,
        1
    )
    with open(file, 'w') as f:
        f.write(content)
" 2>/dev/null || true

exit 0

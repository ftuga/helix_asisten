#!/usr/bin/env bash
# scope-guard.sh — Guardia de scope para Helix
# Disparado por PreToolUse(Write|Edit|MultiEdit)
# Avisa cuando se edita un archivo fuera del proyecto activo.
# NUNCA bloquea (exit 0 siempre). Solo crea fricción visible.
set -uo pipefail

# ── Leer file_path del payload JSON (stdin) ───────────────────
export HELIX_PAYLOAD
HELIX_PAYLOAD=$(cat 2>/dev/null || echo "{}")

FILE_PATH=$(python3 -c "
import os, json
try:
    data = json.loads(os.environ.get('HELIX_PAYLOAD', '{}'))
    inp = data.get('tool_input', {})
    print(inp.get('file_path', inp.get('path', '')))
except:
    print('')
" 2>/dev/null || echo "")

[[ -z "$FILE_PATH" ]] && exit 0

# ── Siempre permitido ─────────────────────────────────────────
HOME_CLAUDE="$HOME/.claude"
HELIX_REPO="$HOME/helix_asisten"

is_always_allowed() {
  local p="$1"
  [[ "$p" == "$HOME_CLAUDE"/* ]] && return 0
  [[ "$p" == "$HELIX_REPO"/* ]] && return 0
  [[ "$p" == /tmp/* ]] && return 0
  return 1
}

is_always_allowed "$FILE_PATH" && exit 0

# ── Detectar raíz del proyecto activo ────────────────────────
PROJECT_ROOT=""

# 1. CLAUDE_PROJECT_DIR tiene prioridad
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
else
  # 2. Auto-detectar desde el directorio del archivo
  dir=$(python3 -c "import os; print(os.path.dirname(os.path.abspath('$FILE_PATH')))" 2>/dev/null || dirname "$FILE_PATH")
  while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
    if [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME_CLAUDE" ]]; then
      PROJECT_ROOT="$dir"
      break
    fi
    dir=$(dirname "$dir")
  done
fi

# Sin proyecto detectado → permitir (no tenemos contexto para juzgar)
[[ -z "$PROJECT_ROOT" ]] && exit 0

# ── Verificar si el archivo está en scope ────────────────────
ABS_FILE=$(python3 -c "import os; print(os.path.abspath('$FILE_PATH'))" 2>/dev/null || echo "$FILE_PATH")
ABS_PROJECT=$(python3 -c "import os; print(os.path.abspath('$PROJECT_ROOT'))" 2>/dev/null || echo "$PROJECT_ROOT")

if [[ "$ABS_FILE" == "$ABS_PROJECT"/* ]]; then
  exit 0  # En scope — silencioso
fi

# ── Fuera de scope — advertencia visible ─────────────────────
SHORT_FILE=$(echo "$ABS_FILE" | sed "s|$HOME/||")
SHORT_PROJECT=$(echo "$ABS_PROJECT" | sed "s|$HOME/||")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  Helix · Scope Guard"
echo ""
echo "   Archivo:  $SHORT_FILE"
echo "   Proyecto: $SHORT_PROJECT"
echo ""
echo "   Este archivo está FUERA del proyecto activo."
echo "   ¿Es intencional? Si no → Ctrl+C para cancelar."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0  # Advertir pero NO bloquear

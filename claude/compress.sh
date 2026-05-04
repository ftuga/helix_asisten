#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# .claude/compress.sh — Compresión de memoria de Helix
# Mantiene CLAUDE.md liviano archivando historial a ~/.claude/memory/topics/
# Uso: bash ~/.claude/compress.sh [--dry-run]
set -euo pipefail

GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
TOPICS_DIR="$HOME/.claude/memory/topics"
SCRIPT="$HOME/.claude/compress_logic.py"
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

mkdir -p "$TOPICS_DIR"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]] && echo "$dir" && return 0
    dir="$(dirname "$dir")"
  done
  return 1
}

PROJECT_CLAUDE_MD=""
if PROJECT_ROOT=$(find_project_root 2>/dev/null); then
  PROJECT_CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   🗜️  Helix — Compresión de Memoria                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
$DRY_RUN && echo -e "\033[1;33m  MODO DRY-RUN — no se escribirá nada\033[0m" && echo ""

"${HELIX_PYTHON:-python3}" "$SCRIPT" \
  "$GLOBAL_CLAUDE_MD" \
  "${PROJECT_CLAUDE_MD:-}" \
  "$TOPICS_DIR" \
  "$DRY_RUN"

echo ""
echo -e "${GREEN}Archivos de tema: $TOPICS_DIR${NC}"
echo ""

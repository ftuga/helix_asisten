#!/usr/bin/env bash
# ============================================================
# helix.sh — Launcher de Helix para Claude Code v3.0
#
# Uso: helix [args para claude]
# ============================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Banner ────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}  ⬡  Helix — Agente Auto-Evolutivo v3.0${NC}"
echo -e "${CYAN}  ────────────────────────────────────────${NC}"
echo ""

# ── Verificar que claude esté disponible ─────────────────────
if ! command -v claude &>/dev/null; then
  echo -e "${YELLOW}⚠️  'claude' no está en el PATH. Instalar Claude Code primero.${NC}"
  echo "   https://docs.anthropic.com/claude-code"
  exit 1
fi

# ── Prompt TUI ────────────────────────────────────────────────
printf "  ${CYAN}¿Iniciar con TUI (panel visual)?${NC} ${BOLD}[y/n]${NC} "
read -r USE_TUI 2>/dev/null || USE_TUI="n"

if [[ "$USE_TUI" =~ ^[Yy]$ ]]; then
  TUI_SCRIPT="$HOME/scripts/claude-ui.sh"
  if [[ ! -f "$TUI_SCRIPT" ]]; then
    echo -e "${YELLOW}⚠️  No se encontró ~/scripts/claude-ui.sh${NC}"
    echo -e "  Continuando en modo normal...\n"
  elif ! python3 -c "import textual" &>/dev/null; then
    echo -e "${YELLOW}⚠️  Falta textual. Instalar con: pip install textual rich psutil gitpython${NC}"
    echo -e "  Continuando en modo normal...\n"
  else
    echo -e "  ${GREEN}Levantando TUI...${NC}\n"
    exec bash "$TUI_SCRIPT"
  fi
fi

# ── Iniciar Helix (modo normal) ───────────────────────────────
echo -e "  ${GREEN}Iniciando Helix...${NC}"
echo ""
exec claude "$@"

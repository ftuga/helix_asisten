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

# ── Prompt tmux ───────────────────────────────────────────────
printf "  ${CYAN}¿Iniciar con tmux?${NC} ${BOLD}[y/n]${NC} "
read -r USE_TMUX 2>/dev/null || USE_TMUX="n"

if [[ "$USE_TMUX" =~ ^[Yy]$ ]]; then
  if ! command -v tmux &>/dev/null; then
    echo -e "${YELLOW}⚠️  tmux no está instalado. Instalar con: sudo apt install tmux${NC}"
    echo -e "  Continuando en modo normal...\n"
  elif [[ -n "${TMUX:-}" ]]; then
    echo -e "${YELLOW}⚠️  Ya estás dentro de tmux. Iniciando claude directo.${NC}\n"
    exec claude "$@"
  else
    LAYOUT_SCRIPT="$HOME/scripts/dev-claude.sh"
    if [[ ! -f "$LAYOUT_SCRIPT" ]]; then
      echo -e "${YELLOW}⚠️  No se encontró ~/scripts/dev-claude.sh${NC}"
      echo -e "  Continuando en modo normal...\n"
    else
      echo -e "  ${GREEN}Levantando entorno tmux...${NC}\n"
      exec bash "$LAYOUT_SCRIPT"
    fi
  fi
fi

# ── Iniciar Helix (modo normal) ───────────────────────────────
echo -e "  ${GREEN}Iniciando Helix...${NC}"
echo ""
exec claude "$@"

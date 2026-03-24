#!/usr/bin/env bash
# ============================================================
# helix.sh — Launcher de Helix para Claude Code v3.0
#
# Layout:
#   ┌──────┬──────┬──────┬──────┐
#   │ s-1  │ s-2  │ s-3  │ s-4  │  ~35% — slots para agentes en paralelo
#   ├──────┴──────┴──────┴──────┤
#   │       claude (principal)   │  ~65% — conversación + prompt
#   └────────────────────────────┘
#
# Ventanas: claude (layout completo) | bash
#
# Uso: helix [args para claude]
# ============================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SESSION_NAME="helix"

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

# ── Preguntar modo ───────────────────────────────────────────
echo -e "  ${GREEN}¿Usar tmux? Abre panel de agentes (4 slots) + barra de estado.${NC}"
echo -ne "  Modo tmux [y/n]: "
read -r USE_TMUX

echo ""

# ── Modo sin tmux ─────────────────────────────────────────────
if [[ "$USE_TMUX" != "y" && "$USE_TMUX" != "Y" ]]; then
  echo -e "  ${GREEN}Iniciando Helix en modo simple...${NC}"
  echo ""
  exec claude "$@"
fi

# ── Verificar tmux disponible ─────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo -e "${YELLOW}⚠️  tmux no está instalado.${NC}"
  echo -ne "  ¿Instalar ahora? (sudo apt install tmux) [y/n]: "
  read -r INSTALL_TMUX
  if [[ "$INSTALL_TMUX" == "y" || "$INSTALL_TMUX" == "Y" ]]; then
    sudo apt-get install -y tmux
    if ! command -v tmux &>/dev/null; then
      echo -e "${YELLOW}  Instalación falló. Iniciando en modo simple.${NC}"
      exec claude "$@"
    fi
    echo -e "  ${GREEN}✓ tmux instalado.${NC}"
  else
    exec claude "$@"
  fi
fi

# ── Manejar sesión tmux anidada ───────────────────────────────
if [[ -n "${TMUX:-}" ]]; then
  echo -e "${YELLOW}Ya estás dentro de tmux. Abriendo en ventana nueva...${NC}"
  tmux new-window -n "claude" "claude $*"
  exit 0
fi

# ── Capturar directorio del proyecto ─────────────────────────
PROJECT_DIR=$(pwd)

# ── Matar sesión anterior si existe ──────────────────────────
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# LAYOUT — ventana "claude"
# ═══════════════════════════════════════════════════════════════

tmux new-session -d -s "$SESSION_NAME" -n "claude" -x "220" -y "50"

# Pane inicial = claude (100%)
CLAUDE_PANE=$(tmux display-message -t "$SESSION_NAME:claude.1" -p '#{pane_id}')

# ── Paso 1: fila de agentes ENCIMA de claude (35%) ───────────
AGENT_ROW=$(tmux split-window -v -b -p 35 -t "$CLAUDE_PANE" \
  -P -F '#{pane_id}')

# ── Paso 2: dividir fila de agentes en 4 columnas iguales ────
A1=$AGENT_ROW
A2=$(tmux split-window -h -p 75 -t "$A1" -P -F '#{pane_id}')
A3=$(tmux split-window -h -p 67 -t "$A2" -P -F '#{pane_id}')
A4=$(tmux split-window -h -p 50 -t "$A3" -P -F '#{pane_id}')

# Títulos y mensaje de espera en cada slot
for slot_num in 1 2 3 4; do
  varname="A${slot_num}"
  PANE="${!varname}"
  tmux select-pane -t "$PANE" -T "⬡ slot-${slot_num} · libre"
  tmux send-keys -t "$PANE" \
    "printf '\033[2J\033[H\033[38;2;99;110;132m  ⬡ slot-${slot_num} — libre\033[0m\n'" Enter
done

# ── Paso 3: arrancar claude en el panel principal ─────────────
tmux select-pane -t "$CLAUDE_PANE" -T "claude"
tmux send-keys -t "$CLAUDE_PANE" "claude $*" Enter

# ═══════════════════════════════════════════════════════════════
# VENTANAS ADICIONALES
# ═══════════════════════════════════════════════════════════════

# Ventana "bash" — terminal libre para comandos
tmux new-window -t "$SESSION_NAME" -n "bash"
tmux send-keys -t "$SESSION_NAME:bash" "cd \"$PROJECT_DIR\" && clear && echo '  bash — directorio: $PROJECT_DIR'" Enter

# ── Volver a ventana claude, panel principal ──────────────────
tmux select-window -t "$SESSION_NAME:claude"
tmux select-pane -t "$CLAUDE_PANE"

# ── Mostrar layout al usuario ─────────────────────────────────
echo -e "  ${GREEN}Layout Helix v3.0 listo:${NC}"
echo ""
echo "   ┌──────────┬──────────┬──────────┬──────────┐  ← tmux status bar"
echo "   │  slot-1  │  slot-2  │  slot-3  │  slot-4  │  ~35%  agentes paralelos"
echo "   ├──────────┴──────────┴──────────┴──────────┤"
echo "   │         claude  (principal ~65%)           │  prompt fijo"
echo "   └────────────────────────────────────────────┘"
echo ""
echo -e "  ${CYAN}Ventanas:${NC}"
echo "   claude (layout completo)  |  bash"
echo ""
echo -e "  ${CYAN}Slots de agentes:${NC}"
echo "   helix-panel-attach 'Título' 'comando'   — asignar agente al primer slot libre"
echo "   helix-panel-attach --slot 2 'Título' 'cmd'  — slot específico"
echo "   helix-panel-attach --list               — ver estado de slots"
echo "   helix-panel-attach --free 1             — liberar slot"
echo ""
echo -e "  ${CYAN}Navegación:${NC}"
echo "   Ctrl+B → ↑↓←→  Cambiar panel   |  Ctrl+B → z  Zoom"
echo "   Ctrl+B → hjkl  Idem (vi)        |  Ctrl+B → r  Recargar config"
echo "   Ctrl+B → [     Modo scroll       |  Ctrl+B → d  Detach"
echo "   Ctrl+B → n/p   Siguiente/Prev ventana"
echo ""
echo -e "  ${GREEN}Iniciando...${NC}"
echo ""

# ── Attachear ────────────────────────────────────────────────
exec tmux attach-session -t "$SESSION_NAME"

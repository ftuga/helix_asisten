#!/usr/bin/env bash
# ============================================================
# helix.sh — Launcher de Helix para Claude Code v2.0
#
# Layout Option C: claude ancho completo + barra inferior de estado.
# Más espacio para la conversación, métricas compactas abajo.
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
echo -e "${CYAN}${BOLD}  ⬡  Helix — Agente Auto-Evolutivo v3.3.0${NC}"
echo -e "${CYAN}  ────────────────────────────────────────${NC}"
echo ""

# ── Verificar que claude esté disponible ─────────────────────
if ! command -v claude &>/dev/null; then
  echo -e "${YELLOW}⚠️  'claude' no está en el PATH. Instalar Claude Code primero.${NC}"
  echo "   https://docs.anthropic.com/claude-code"
  exit 1
fi

# ── Preguntar modo ───────────────────────────────────────────
echo -e "  ${GREEN}¿Usar tmux? Abre barra de estado (costo, routing, evoluciones) bajo la conversación.${NC}"
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
  echo -ne "  ¿Querés que lo instale ahora? (sudo apt install tmux) [y/n]: "
  read -r INSTALL_TMUX
  if [[ "$INSTALL_TMUX" == "y" || "$INSTALL_TMUX" == "Y" ]]; then
    echo ""
    echo -e "  ${CYAN}Instalando tmux...${NC}"
    sudo apt-get install -y tmux
    if ! command -v tmux &>/dev/null; then
      echo -e "${YELLOW}  Instalación falló. Iniciando en modo simple.${NC}"
      echo ""
      exec claude "$@"
    fi
    echo -e "  ${GREEN}✓ tmux instalado correctamente.${NC}"
    echo ""
  else
    echo -e "  ${YELLOW}Iniciando en modo simple (sin tmux).${NC}"
    echo ""
    exec claude "$@"
  fi
fi

# ── Manejar sesión tmux anidada ───────────────────────────────
if [[ -n "${TMUX:-}" ]]; then
  echo -e "${YELLOW}Ya estás dentro de tmux. Abriendo en ventana nueva...${NC}"
  tmux new-window -n "claude" "claude $*"
  exit 0
fi

# ── Matar sesión anterior si existe ──────────────────────────
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# ── Crear nueva sesión ────────────────────────────────────────
tmux new-session -d -s "$SESSION_NAME" -x "220" -y "50"

# ── Panel principal: claude (ancho completo, ~82% altura) ─────
tmux rename-window -t "$SESSION_NAME:0" "claude"
tmux select-pane -t "$SESSION_NAME:0.0" -T "claude"
tmux send-keys -t "$SESSION_NAME:0.0" "claude $*" Enter

# ── Panel inferior: helix status (18% de altura) ─────────────
tmux split-window -v -t "$SESSION_NAME:0.0" -p 18
tmux select-pane -t "$SESSION_NAME:0.1" -T "⬡ helix status"
tmux send-keys -t "$SESSION_NAME:0.1" \
  "watch -n 2 -t 'bash $HOME/.claude/helpers/helix-swarm-panel.sh'" Enter

# ── Volver al panel principal ─────────────────────────────────
tmux select-pane -t "$SESSION_NAME:0.0"

# ── Mostrar layout al usuario ─────────────────────────────────
echo -e "  ${GREEN}Layout Helix v2 listo:${NC}"
echo ""
echo "   ┌─────────────────────────────────────────┐  ← tmux status bar"
echo "   │                                         │"
echo "   │         claude  (principal)             │"
echo "   │                                         │"
echo "   ├─────────────────────────────────────────┤"
echo "   │   ⬡ helix status  (métricas + routing)  │"
echo "   └─────────────────────────────────────────┘"
echo ""
echo -e "  ${CYAN}Atajos tmux:${NC}"
echo "   Ctrl+B → ↑↓    Cambiar entre paneles"
echo "   Ctrl+B → z      Zoom al panel actual (toggle)"
echo "   Ctrl+B → r      Recargar tmux.conf"
echo "   Ctrl+B → d      Detach (helix sigue en background)"
echo "   tmux attach -t helix   Volver a la sesión"
echo ""
echo -e "  ${GREEN}Iniciando...${NC}"
echo ""

# ── Attachear ────────────────────────────────────────────────
exec tmux attach-session -t "$SESSION_NAME"

#!/usr/bin/env bash
# ============================================================
# helix.sh — Launcher de Helix para Claude Code
#
# Uso: helix [args para claude]
#
# Pregunta si usar tmux o no.
# Con tmux: layout con panel principal (claude) + panel de estado del swarm.
# Sin tmux: lanza claude directamente.
# ============================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SWARM_STATUS_FILE="/tmp/helix-swarm-status.txt"
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
echo -e "  ${GREEN}¿Usar tmux? Abre el panel de estado del swarm junto a la conversación.${NC}"
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
  tmux new-window -n "helix" "claude $*"
  exit 0
fi

# ── Inicializar archivo de estado del swarm ───────────────────
cat > "$SWARM_STATUS_FILE" << 'STATUSEOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━
⬡  Helix Swarm Status
━━━━━━━━━━━━━━━━━━━━━━━━━━

Sin agentes activos.

Para registrar una decisión:
  bash ~/.claude/helpers/routing-learn.sh \
    "<tarea>" "<agente>" "success"

━━━━━━━━━━━━━━━━━━━━━━━━━━
STATUSEOF

# ── Crear sesión tmux con layout Helix ───────────────────────
# Matar sesión anterior si existe
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Crear nueva sesión (sin attachear todavía)
tmux new-session -d -s "$SESSION_NAME" -x "220" -y "50"

# ── Panel principal (izquierda): claude ───────────────────────
tmux send-keys -t "$SESSION_NAME" "claude $*" Enter

# ── Dividir verticalmente: panel derecho para estado ─────────
tmux split-window -h -t "$SESSION_NAME" -p 30

# ── Panel derecho: watch del estado del swarm ────────────────
tmux send-keys -t "$SESSION_NAME" \
  "watch -n 2 'bash $HOME/.claude/helpers/helix-swarm-panel.sh'" Enter

# ── Dividir panel derecho: panel inferior para métricas ──────
tmux split-window -v -t "$SESSION_NAME" -p 35

# ── Panel inferior derecho: evolution-log en vivo ─────────────
tmux send-keys -t "$SESSION_NAME" \
  "tail -f $HOME/.claude/memory/session-log.txt 2>/dev/null || echo 'Sin log de sesión'" Enter

# ── Volver al panel principal ─────────────────────────────────
tmux select-pane -t "$SESSION_NAME:0.0"

# ── Mostrar atajos rápidos ─────────────────────────────────────
echo -e "  ${GREEN}Layout Helix listo:${NC}"
echo ""
echo "   ┌─────────────────────────┬────────────┐"
echo "   │                         │   Swarm    │"
echo "   │   claude (principal)    │   Status   │"
echo "   │                         ├────────────┤"
echo "   │                         │  Sesiones  │"
echo "   └─────────────────────────┴────────────┘"
echo ""
echo -e "  ${CYAN}Atajos tmux útiles:${NC}"
echo "   Ctrl+B → flechas     Moverse entre paneles"
echo "   Ctrl+B → z           Zoom al panel actual"
echo "   Ctrl+B → d           Detach (tmux sigue en background)"
echo "   tmux attach -t helix Volver a la sesión"
echo ""
echo -e "  ${GREEN}Iniciando...${NC}"
echo ""

# ── Attachear ────────────────────────────────────────────────
exec tmux attach-session -t "$SESSION_NAME"

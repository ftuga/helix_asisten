#!/usr/bin/env bash
# ============================================================
# helix-panel-attach.sh — Gestiona los slots de agentes en el
#                          panel superior de Helix tmux
#
# Uso:
#   helix-panel-attach 'Título' 'comando'          → primer slot libre
#   helix-panel-attach --slot 2 'Título' 'cmd'     → slot específico
#   helix-panel-attach --list                      → ver estado de slots
#   helix-panel-attach --free N                    → liberar slot N
# ============================================================

SESSION="helix"
WINDOW="claude"
SLOT_COUNT=4

# ── Colores ───────────────────────────────────────────────────
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────

# Devuelve el pane_id del slot N (busca por título "slot-N")
get_slot_pane() {
  local slot=$1
  tmux list-panes -t "$SESSION:$WINDOW" -F '#{pane_id} #{pane_title}' \
    2>/dev/null | grep " ⬡ slot-${slot}" | awk '{print $1}' | head -1
}

# True si el slot está libre
slot_is_free() {
  local slot=$1
  tmux list-panes -t "$SESSION:$WINDOW" -F '#{pane_title}' \
    2>/dev/null | grep -q "slot-${slot} · libre"
}

# Devuelve el número del primer slot libre, o vacío si no hay
find_free_slot() {
  for i in $(seq 1 $SLOT_COUNT); do
    if slot_is_free "$i"; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

# ── Subcomandos ───────────────────────────────────────────────

cmd_list() {
  # Verificar que la sesión exista
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Sesión '$SESSION' no encontrada. ¿Iniciaste helix?${NC}"
    exit 1
  fi

  echo ""
  echo -e "  ${CYAN}⬡ Estado de slots — $SESSION:$WINDOW${NC}"
  echo "  ┌──────────┬────────────────────────────────────┐"
  for i in $(seq 1 $SLOT_COUNT); do
    PANE=$(get_slot_pane "$i")
    if [[ -z "$PANE" ]]; then
      STATUS="${RED}[no encontrado]${NC}"
    elif slot_is_free "$i"; then
      STATUS="${CYAN}libre${NC}"
    else
      TITLE=$(tmux list-panes -t "$SESSION:$WINDOW" -F '#{pane_id} #{pane_title}' \
        2>/dev/null | grep " ⬡ slot-${i}" | sed 's/[^ ]* ⬡ slot-[0-9]* · //')
      STATUS="${GREEN}${TITLE}${NC}"
    fi
    printf "  │  slot-%-2s  │  %-34b│\n" "$i" "$STATUS"
  done
  echo "  └──────────┴────────────────────────────────────┘"
  echo ""
  echo -e "  ${CYAN}Comandos:${NC}"
  echo "   helix-panel-attach 'Título' 'cmd'          → asignar a slot libre"
  echo "   helix-panel-attach --slot N 'Título' 'cmd' → slot específico"
  echo "   helix-panel-attach --free N                → liberar slot"
  echo ""
}

cmd_free() {
  local slot=$1
  if [[ -z "$slot" || ! "$slot" =~ ^[1-4]$ ]]; then
    echo -e "${YELLOW}Uso: helix-panel-attach --free <1-4>${NC}"
    exit 1
  fi

  PANE=$(get_slot_pane "$slot")
  if [[ -z "$PANE" ]]; then
    echo -e "${YELLOW}⚠️  slot-${slot} no encontrado en $SESSION:$WINDOW${NC}"
    exit 1
  fi

  # Interrumpir proceso actual
  tmux send-keys -t "$PANE" "" ""
  sleep 0.1
  tmux send-keys -t "$PANE" "clear" Enter
  sleep 0.1
  tmux send-keys -t "$PANE" \
    "printf '\033[2J\033[H\033[38;2;99;110;132m  ⬡ slot-${slot} — libre\033[0m\n'" Enter
  tmux select-pane -t "$PANE" -T "⬡ slot-${slot} · libre"

  echo -e "  ${GREEN}✓ slot-${slot} liberado${NC}"
}

cmd_attach() {
  local slot=$1
  local title=$2
  local cmd=$3

  # Verificar sesión
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Sesión '$SESSION' no encontrada. ¿Iniciaste helix?${NC}"
    exit 1
  fi

  # Validar slot
  if [[ -z "$slot" || ! "$slot" =~ ^[1-4]$ ]]; then
    echo -e "${RED}Error: slot debe ser 1-4${NC}"
    exit 1
  fi

  PANE=$(get_slot_pane "$slot")
  if [[ -z "$PANE" ]]; then
    echo -e "${RED}Error: slot-${slot} no encontrado en $SESSION:$WINDOW${NC}"
    echo -e "       Ejecuta ${CYAN}helix-panel-attach --list${NC} para ver el estado"
    exit 1
  fi

  # Si el slot está ocupado, avisar pero permitir sobrescribir
  if ! slot_is_free "$slot"; then
    CURRENT=$(tmux list-panes -t "$SESSION:$WINDOW" -F '#{pane_id} #{pane_title}' \
      2>/dev/null | grep " ⬡ slot-${slot}" | sed 's/[^ ]* ⬡ slot-[0-9]* · //')
    echo -e "${YELLOW}⚠️  slot-${slot} ya tiene: '$CURRENT'${NC}"
    echo -ne "  ¿Reemplazar? [y/n]: "
    read -r CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && exit 0
  fi

  # Asignar agente al slot
  tmux send-keys -t "$PANE" "" ""
  sleep 0.1
  tmux send-keys -t "$PANE" "clear" Enter
  sleep 0.1
  tmux select-pane -t "$PANE" -T "⬡ slot-${slot} · ${title}"
  tmux send-keys -t "$PANE" "$cmd" Enter

  echo -e "  ${GREEN}✓ '${title}' asignado a slot-${slot} (pane ${PANE})${NC}"
}

# ═══════════════════════════════════════════════════════════════
# MAIN — parseo de argumentos
# ═══════════════════════════════════════════════════════════════

case "${1:-}" in

  --list|-l)
    cmd_list
    ;;

  --free|-f)
    cmd_free "${2:-}"
    ;;

  --slot|-s)
    SLOT="${2:-}"
    TITLE="${3:-agente}"
    CMD="${4:-bash}"
    cmd_attach "$SLOT" "$TITLE" "$CMD"
    ;;

  --help|-h|"")
    echo ""
    echo -e "  ${CYAN}helix-panel-attach${NC} — gestiona slots de agentes en el panel Helix"
    echo ""
    echo "  Uso:"
    echo "   helix-panel-attach 'Título' 'comando'            primer slot libre"
    echo "   helix-panel-attach --slot N 'Título' 'comando'   slot específico (1-4)"
    echo "   helix-panel-attach --list                        estado de todos los slots"
    echo "   helix-panel-attach --free N                      liberar slot N"
    echo ""
    echo "  Ejemplos:"
    echo "   helix-panel-attach 'backend-dev' 'claude --model sonnet'"
    echo "   helix-panel-attach --slot 3 'logs' 'tail -f /tmp/helix.log'"
    echo "   helix-panel-attach --slot 1 'tests' 'npm test -- --watch'"
    echo "   helix-panel-attach --free 2"
    echo ""
    ;;

  *)
    # Primer arg = título, segundo = comando → slot libre automático
    TITLE="${1:-agente}"
    CMD="${2:-bash}"

    SLOT=$(find_free_slot)
    if [[ $? -ne 0 ]]; then
      echo -e "${YELLOW}⚠️  No hay slots libres (máx 4 visibles).${NC}"
      echo -e "   Usa ${CYAN}helix-panel-attach --list${NC} para ver el estado."
      echo -e "   Usa ${CYAN}helix-panel-attach --free N${NC} para liberar uno."
      exit 1
    fi

    cmd_attach "$SLOT" "$TITLE" "$CMD"
    ;;

esac

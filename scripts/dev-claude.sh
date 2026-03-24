#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════
# dev-claude.sh — Layout tmux para Helix + Claude Code
# Layout: helix (izq, full) | agente-A / git (centro) | agente-B / monitor (der)
# ══════════════════════════════════════════════════════════════
export TERM=xterm-256color
export COLORTERM=truecolor

SESSION="dev"
CWD="$(pwd)"

# Si ya existe → attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach-session -t "$SESSION"
fi

# ── Crear sesión ──────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -n "helix"

# ── PANEL 1: helix (izquierda, full height, ~55%) ─────────────
tmux select-pane -t "${SESSION}:helix.1" -T "orquestador"
tmux send-keys -t "${SESSION}:helix.1" "helix" Enter

# ── COLUMNA CENTRO (top: agente-A | bottom: git) ──────────────
tmux split-window -t "${SESSION}:helix.1" -h -p 45
tmux select-pane -t "${SESSION}:helix.2" -T "agente-A"

# Panel agente-A: bash listo para claude u otro agente
# (vacío — el usuario lanza lo que necesite)

# Git diff / status abajo del agente-A
tmux split-window -t "${SESSION}:helix.2" -v -p 40 -c "$CWD"
tmux select-pane -t "${SESSION}:helix.3" -T "git"
tmux send-keys -t "${SESSION}:helix.3" \
  "watch -n 5 'echo \"\033[38;2;166;227;161m── git status ────────────────────────────\033[0m\" && git -C $CWD status -sb 2>/dev/null && echo && echo \"\033[38;2;88;91;112m── últimos commits ───────────────────────\033[0m\" && git -C $CWD log --oneline --graph -6 2>/dev/null'" \
  Enter

# ── COLUMNA DERECHA (top: agente-B | bottom: monitor) ─────────
tmux select-pane -t "${SESSION}:helix.2"
tmux split-window -t "${SESSION}:helix.2" -h -p 50
tmux select-pane -t "${SESSION}:helix.4" -T "agente-B"

# Monitor abajo del agente-B
tmux split-window -t "${SESSION}:helix.4" -v -p 40 -c "$CWD"
tmux select-pane -t "${SESSION}:helix.5" -T "monitor"

MONITOR='watch -n 2 '"'"'
BLUE="\033[38;2;137;180;250m"
GREEN="\033[38;2;166;227;161m"
YELLOW="\033[38;2;249;226;175m"
RED="\033[38;2;243;139;168m"
MUTED="\033[38;2;88;91;112m"
BOLD="\033[1m"
NC="\033[0m"
printf "${MUTED}── helix ──────────────────────────────────${NC}\n"
PROCS=$(ps aux | grep -E "[c]laude" | wc -l | tr -d " ")
[ "$PROCS" -gt 0 ] && printf " ${GREEN}● claude activo ($PROCS proc)${NC}\n" || printf " ${MUTED}○ claude inactivo${NC}\n"
printf "${MUTED}── agentes ────────────────────────────────${NC}\n"
ps aux | grep -E "[c]laude|[n]ode" | grep -v "watch" | awk "{printf \" ${BLUE}%-22s${NC} ${MUTED}%s%%${NC}\n\", \$11, \$3}" 2>/dev/null || printf " ${MUTED}ninguno corriendo${NC}\n"
printf "${MUTED}── sistema ────────────────────────────────${NC}\n"
free -h 2>/dev/null | awk "NR==2{printf \" RAM  ${YELLOW}%s${NC} / %s\n\", \$3, \$2}"
uptime | awk -F"load average:" "{printf \" CPU  ${YELLOW}%s${NC}\n\", \$2}"
printf "${MUTED}── git ────────────────────────────────────${NC}\n"
git -C '"$CWD"' log --oneline -3 2>/dev/null || echo " no es repo git"
'"'"

tmux send-keys -t "${SESSION}:helix.5" "$MONITOR" Enter

# ── Foco: orquestador ────────────────────────────────────────
tmux select-pane -t "${SESSION}:helix.1"

# ── Attach ───────────────────────────────────────────────────
export TERM=xterm-256color
export COLORTERM=truecolor
exec tmux attach-session -t "$SESSION"

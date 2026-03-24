#!/usr/bin/env bash
# ============================================================
# dev-claude.sh — Layout tmux para Helix + Claude Code
# Session: "dev"  |  3 columnas  |  6 paneles
# ============================================================
export TERM=xterm-256color
export COLORTERM=truecolor

SESSION="dev"
CWD="$(pwd)"

# Si la sesión ya existe → attach y salir
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "→ Sesión '$SESSION' ya existe. Haciendo attach..."
  exec tmux attach-session -t "$SESSION"
fi

# ── Crear sesión ─────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -n "main"

# ── COLUMNA IZQUIERDA (50%) ───────────────────────────────────

# Panel 1: orquestador — arriba izquierda (88%)
tmux select-pane -t "${SESSION}:main.1" -T "claude code [orquestador]"
tmux send-keys -t "${SESSION}:main.1" "claude" Enter

# Panel 2: input fijo — abajo izquierda (12%)
tmux split-window -t "${SESSION}:main.1" -v -p 12 -c "$CWD"
tmux select-pane -t "${SESSION}:main.2" -T "input"
tmux send-keys -t "${SESSION}:main.2" \
  "printf '\033[38;2;203;166;247m─── input fijo ───────────────────────────────────────────\033[0m\n'; printf '\033[38;2;88;91;112m ↑↓ historial   esc: cancelar   enter: enviar   ctrl+c: stop\033[0m\n'; printf '\033[38;2;88;91;112m scroll: ver mensajes  │  shift+mouse: seleccionar texto\033[0m\n'; bash" Enter

# ── COLUMNA MEDIO-DERECHA (25%) ───────────────────────────────

# Volver al panel 1 para hacer el split horizontal
tmux select-pane -t "${SESSION}:main.1"

# Panel 3: agente A — top medio-derecha
tmux split-window -t "${SESSION}:main.1" -h -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.3" -T "agente A [backend]"

# Panel 5: nvim — bottom medio-derecha (split del panel 3)
tmux split-window -t "${SESSION}:main.3" -v -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.5" -T "nvim"
tmux send-keys -t "${SESSION}:main.5" "nvim ." Enter

# ── COLUMNA EXTREMO-DERECHA (25%) ─────────────────────────────

# Volver al panel 3 para hacer el split horizontal
tmux select-pane -t "${SESSION}:main.3"

# Panel 4: agente B — top extremo-derecha
tmux split-window -t "${SESSION}:main.3" -h -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.4" -T "agente B [frontend]"

# Panel 6: monitor — bottom extremo-derecha
tmux split-window -t "${SESSION}:main.4" -v -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.6" -T "monitor"

MONITOR_CMD='watch -n 2 '"'"'clear
printf "\033[38;2;88;91;112m── agentes ─────────────────────────────\033[0m\n"
printf "\033[38;2;137;180;250mA backend\033[0m\n"
printf "\033[38;2;166;227;161mB frontend\033[0m\n"
printf "\033[38;2;88;91;112m── procesos claude ─────────────────────\033[0m\n"
ps aux | grep -E "claude|node" | grep -v "grep\|watch" | awk "{printf \"%-25s \033[38;2;137;180;250m%s%%\033[0m\n\", \$11, \$3}" 2>/dev/null || printf "\033[38;2;88;91;112mninguno corriendo\033[0m\n"
printf "\033[38;2;88;91;112m── git ─────────────────────────────────\033[0m\n"
git log --oneline -4 2>/dev/null || echo "no es repo git"'"'"''

tmux send-keys -t "${SESSION}:main.6" "$MONITOR_CMD" Enter

# ── Foco final: orquestador ───────────────────────────────────
tmux select-pane -t "${SESSION}:main.1"

# ── Attach ───────────────────────────────────────────────────
export TERM=xterm-256color
export COLORTERM=truecolor
exec tmux attach-session -t "$SESSION"

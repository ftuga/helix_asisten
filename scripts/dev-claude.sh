#!/usr/bin/env bash
# ============================================================
# dev-claude.sh — Layout tmux para Helix + Claude Code
# Session: "dev"  |  2 columnas  |  6 paneles
# ============================================================

SESSION="dev"
CWD="$(pwd)"

# Si la sesión ya existe → attach y salir
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "→ Sesión '$SESSION' ya existe. Haciendo attach..."
  exec tmux attach-session -t "$SESSION"
fi

# ── Crear sesión (sin adjuntar aún) ──────────────────────────
tmux new-session -d -s "$SESSION" -n "main" -x 220 -y 50

# ── Columna IZQUIERDA (50%) ───────────────────────────────────
# Panel 1: orquestador (claude) — arriba izquierda
tmux select-pane -t "${SESSION}:main.1"
tmux send-keys -t "${SESSION}:main.1" "claude" ""
tmux select-pane -t "${SESSION}:main.1" -T "orquestador"

# Panel 2: input fijo — abajo izquierda (12% de la columna izq.)
tmux split-window -t "${SESSION}:main.1" -v -p 12 -c "$CWD"
tmux select-pane -t "${SESSION}:main.2" -T "input"
tmux send-keys -t "${SESSION}:main.2" \
  "echo '─── input fijo ── esc:cancel  ctrl+c:stop  ↑↓:historial ───'" ""

# ── Columna DERECHA (50%) ────────────────────────────────────
# Volver al panel orquestador para hacer el split derecho
tmux select-pane -t "${SESSION}:main.1"

# Panel 3: agente-A — top right
tmux split-window -t "${SESSION}:main.1" -h -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.3" -T "agente-A"

# Panel 4: agente-B — top far-right (split del agente-A)
tmux split-window -t "${SESSION}:main.3" -h -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.4" -T "agente-B"

# Panel 5: editor — bottom right (split del agente-A)
tmux split-window -t "${SESSION}:main.3" -v -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.5" -T "editor"
tmux send-keys -t "${SESSION}:main.5" "nvim ." ""

# Panel 6: monitor — bottom far-right (split del agente-B)
tmux split-window -t "${SESSION}:main.4" -v -p 50 -c "$CWD"
tmux select-pane -t "${SESSION}:main.6" -T "monitor"
MONITOR_CMD="watch -n 2 'echo \"── monitor ──────────────────────────\" && ps aux | grep -E \"claude|node\" | grep -v grep | awk \"{printf \\\"%-20s %s\\\n\\\", \\\$11, \\\$3\\\"% CPU\\\"}\" && echo \"\" && echo \"── git ──────────────────────────────\" && git -C \$HOME log --oneline -5 2>/dev/null'"
tmux send-keys -t "${SESSION}:main.6" "$MONITOR_CMD" ""

# ── Foco final: orquestador ───────────────────────────────────
tmux select-pane -t "${SESSION}:main.1"

# ── Attach ───────────────────────────────────────────────────
exec tmux attach-session -t "$SESSION"

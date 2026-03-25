#!/usr/bin/env bash
# helix-swarm-panel.sh v2.0 — Barra de estado inferior para Helix
# Layout: ancho completo, ~7 líneas. Ejecutado via: watch -n 2 -t '...'
# Secciones: costo · tool calls · top routing agent · última evolución

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

DATE=$(date '+%H:%M:%S')
DAY=$(date '+%a %d %b')
MEMORY_DIR="$HOME/.claude/memory"
FEEDBACK_FILE="$MEMORY_DIR/routing-feedback.jsonl"
COLS=$(tput cols 2>/dev/null || echo 100)

# ── Helper: línea divisoria ───────────────────────────────────
divider() {
  printf "${DIM}"
  printf '─%.0s' $(seq 1 "$COLS")
  printf "${NC}\n"
}

# ── Header ────────────────────────────────────────────────────
divider
printf "${CYAN}${BOLD} ⬡  HELIX${NC}  ${DIM}${DATE} · ${DAY}${NC}\n"
divider

# ── Sección: costo ────────────────────────────────────────────
COST_FILE=""
if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
  COST_FILE="/tmp/helix-cost-${CLAUDE_SESSION_ID}"
elif ls /tmp/helix-cost-* 2>/dev/null | head -1 | grep -q helix; then
  COST_FILE=$(ls -t /tmp/helix-cost-* 2>/dev/null | head -1)
fi

if [[ -n "$COST_FILE" && -f "$COST_FILE" ]]; then
  CALLS=$(tr -d '[:space:]' < "$COST_FILE" 2>/dev/null || echo "0")
  COST=$(python3 -c "n=int('$CALLS') if '$CALLS'.isdigit() else 0; print(f'\${n*0.014:.2f}')" 2>/dev/null || echo "?")
  printf " ${GREEN}💰 ~\$${COST}${NC}"
else
  printf " ${DIM}💰 sin sesión${NC}"
fi

printf "  ${DIM}│${NC}  "

# ── Sección: tool calls / compact ─────────────────────────────
COMPACT_SESSION="${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H)}"
COMPACT_FILE="/tmp/helix-tool-count-${COMPACT_SESSION}"
COUNT=0
[[ -f "$COMPACT_FILE" ]] && COUNT=$(cat "$COMPACT_FILE" 2>/dev/null || echo "0")
THRESHOLD=50

if [[ "$COUNT" -ge "$THRESHOLD" ]]; then
  printf "${YELLOW}⚡ ${COUNT}/${THRESHOLD} → /compact${NC}"
else
  printf "${DIM}⚡ ${COUNT}/${THRESHOLD}${NC}"
fi

printf "  ${DIM}│${NC}  "

# ── Sección: top routing agent ────────────────────────────────
if [[ -f "$FEEDBACK_FILE" ]]; then
  python3 -q -c "
import json, sys
from collections import Counter
hits = []
with open('$FEEDBACK_FILE') as f:
    for line in f:
        try:
            d = json.loads(line)
            hits.append((d['agente'], d['resultado']))
        except:
            pass
if hits:
    by_agent = Counter(a for a, _ in hits)
    success  = Counter(a for a, r in hits if r == 'success')
    agent, total = by_agent.most_common(1)[0]
    pct  = int(success.get(agent, 0) / total * 100)
    bar  = chr(0x2588) * (pct // 20) + chr(0x2591) * (5 - pct // 20)
    print(f'\033[0;32m🎯 {agent}\033[0m \033[2m{bar} {pct}% ({total} dec)\033[0m', end='')
else:
    print('\033[2m🎯 sin routing data\033[0m', end='')
" 2>/dev/null || printf "${DIM}🎯 sin datos${NC}"
else
  printf "${DIM}🎯 sin routing data${NC}"
fi

printf "  ${DIM}│${NC}  "

# ── Sección: última evolución ─────────────────────────────────
if [[ -f "$MEMORY_DIR/evolution-log.txt" ]]; then
  LAST=$(tail -1 "$MEMORY_DIR/evolution-log.txt" 2>/dev/null \
    | sed 's/^\[[^]]*\] \[LEARN\] //' | cut -c1-42)
  if [[ -n "$LAST" ]]; then
    printf "${DIM}📈 ${LAST}…${NC}"
  else
    printf "${DIM}📈 sin evoluciones${NC}"
  fi
else
  printf "${DIM}📈 sin evoluciones${NC}"
fi

echo ""
divider
printf "${DIM}  Ctrl+B ↑↓ paneles  ·  Ctrl+B z zoom  ·  Ctrl+B d detach  ·  Ctrl+B r recargar tmux${NC}\n"

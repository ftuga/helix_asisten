#!/usr/bin/env bash
# helix-swarm-panel.sh — Panel de estado del swarm para tmux
# Ejecutado por watch -n 2 en el panel lateral de la sesión helix.
# Muestra: agentes activos, routing feedback, reglas activas, costo de sesión.

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'
DIM='\033[2m'

DATE=$(date '+%H:%M:%S')
MEMORY_DIR="$HOME/.claude/memory"
FEEDBACK_FILE="$MEMORY_DIR/routing-feedback.jsonl"

# ── Header ────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}⬡  Helix Panel${NC} ${DIM}$DATE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ── Costo de sesión actual ────────────────────────────────────
SESSION_ID="${CLAUDE_SESSION_ID:-}"
COST_FILE=""
if [[ -n "$SESSION_ID" ]]; then
  COST_FILE="/tmp/helix-cost-${SESSION_ID}"
elif ls /tmp/helix-cost-* 2>/dev/null | head -1 | grep -q helix; then
  COST_FILE=$(ls -t /tmp/helix-cost-* 2>/dev/null | head -1)
fi

if [[ -n "$COST_FILE" && -f "$COST_FILE" ]]; then
  CALLS=$(tr -d '[:space:]' < "$COST_FILE" 2>/dev/null || echo "0")
  COST=$(python3 -c "n=int('$CALLS') if '$CALLS'.isdigit() else 0; print(f'~\${n*0.014:.2f}')" 2>/dev/null || echo "~\$?")
  echo -e "${GREEN}💰 Sesión activa${NC}"
  echo "   Tool calls: $CALLS"
  echo "   Costo est:  $COST USD"
else
  echo -e "${DIM}💰 Sin sesión activa${NC}"
fi
echo ""

# ── Compact counter ───────────────────────────────────────────
COMPACT_SESSION="${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H)}"
COMPACT_FILE="/tmp/helix-tool-count-${COMPACT_SESSION}"
if [[ -f "$COMPACT_FILE" ]]; then
  COUNT=$(cat "$COMPACT_FILE" 2>/dev/null || echo "0")
  THRESHOLD=50
  if [[ "$COUNT" -ge "$THRESHOLD" ]]; then
    echo -e "${YELLOW}⚡ Tool calls: $COUNT (>$THRESHOLD → /compact?)${NC}"
  else
    echo -e "${DIM}⚡ Tool calls: $COUNT / $THRESHOLD${NC}"
  fi
  echo ""
fi

# ── Active rules (últimas 3) ──────────────────────────────────
RULES_FILE="$MEMORY_DIR/active-rules.md"
if [[ -f "$RULES_FILE" ]]; then
  RULE_COUNT=$(grep -c "^- \[" "$RULES_FILE" 2>/dev/null || echo "0")
  echo -e "${GREEN}🧠 Reglas activas: $RULE_COUNT${NC}"
  grep "^- \[" "$RULES_FILE" | head -3 | while IFS= read -r line; do
    # Mostrar solo la parte después de la categoría
    short=$(echo "$line" | sed 's/^- \[[^]]*\] \[[^]]*\] //' | cut -c1-30)
    echo "   · $short..."
  done
  echo ""
fi

# ── Routing feedback (top agentes) ───────────────────────────
if [[ -f "$FEEDBACK_FILE" ]]; then
  TOTAL=$(wc -l < "$FEEDBACK_FILE" 2>/dev/null | tr -d ' ')
  echo -e "${GREEN}🎯 Routing ($TOTAL decisiones)${NC}"
  python3 -c "
import json
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
    by_agent = Counter(a for a,_ in hits)
    success = Counter(a for a,r in hits if r == 'success')
    for agent, total in by_agent.most_common(3):
        wins = success.get(agent,0)
        pct = int(wins/total*100) if total else 0
        bar = '█' * (pct // 20) + '░' * (5 - pct // 20)
        print(f'   {bar} {agent} ({pct}%)')
else:
    print('   Sin datos aún')
" 2>/dev/null || echo "   Sin datos"
  echo ""
fi

# ── Última evolución ──────────────────────────────────────────
if [[ -f "$MEMORY_DIR/evolution-log.txt" ]]; then
  LAST=$(tail -1 "$MEMORY_DIR/evolution-log.txt" 2>/dev/null)
  if [[ -n "$LAST" ]]; then
    echo -e "${DIM}📈 Última evolución:${NC}"
    echo "$LAST" | sed 's/^\[.*\] \[LEARN\] //' | cut -c1-28 | while IFS= read -r l; do
      echo "   $l..."
    done
  fi
fi

echo ""
echo -e "${DIM}Ctrl+B → flechas: mover panel${NC}"
echo -e "${DIM}Ctrl+B → z: zoom${NC}"

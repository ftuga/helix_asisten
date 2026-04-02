#!/usr/bin/env bash
# skill-tracker.sh — Registrar uso real de skills y agentes por sesión
# Modo: append-only log que retrospectiva analiza para detectar skills sin uso
#
# Uso:
#   log    "<skill_o_agente>" "<tipo: skill|agent>" [proyecto]
#   report [--limit N]  → top N más usados + lista de nunca usados
#   prune  --dry-run    → sugiere skills a desactivar (0 usos en 30 días)
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
USAGE_LOG="$GLOBAL_DIR/memory/skill-usage.jsonl"
SKILLS_DIR="$GLOBAL_DIR/skills"

cmd="${1:-report}"
shift || true

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

case "$cmd" in

# ─────────────────────────────────────────────────────────────
log)
    NAME="${1:-}"
    TIPO="${2:-skill}"   # skill | agent | mcp
    PROYECTO="${3:-}"
    [[ -z "$NAME" ]] && exit 0  # silencioso si no hay nombre

    DATE=$(date '+%Y-%m-%d %H:%M')
    SHORT=$(date '+%Y-%m-%d')

    # Auto-detectar proyecto si no se pasó
    if [[ -z "$PROYECTO" ]]; then
        dir="$PWD"
        while [[ "$dir" != "/" && "$dir" != "$HOME" ]]; do
            [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]] && {
                PROYECTO=$(basename "$dir"); break
            }
            dir=$(dirname "$dir")
        done
    fi

    python3 -c "
import json, sys
entry = {
    'ts': sys.argv[1],
    'date': sys.argv[2],
    'name': sys.argv[3],
    'tipo': sys.argv[4],
    'proyecto': sys.argv[5],
}
with open('$USAGE_LOG', 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
" "$DATE" "$SHORT" "$NAME" "$TIPO" "$PROYECTO"
    ;;

# ─────────────────────────────────────────────────────────────
report)
    LIMIT="${1:-20}"

    if [[ ! -f "$USAGE_LOG" ]]; then
        echo "Sin datos de uso. Skills/agentes aún no registrados."
        exit 0
    fi

    echo -e "${BLUE}⬡ Skill & Agent Usage Report${NC}"
    echo ""

    python3 - "$USAGE_LOG" "$SKILLS_DIR" "$LIMIT" <<'PYEOF'
import json, sys, os
from datetime import datetime, timedelta
from pathlib import Path
from collections import Counter

log_file   = Path(sys.argv[1])
skills_dir = Path(sys.argv[2])
limit      = int(sys.argv[3])

entries = []
with open(log_file) as f:
    for line in f:
        line = line.strip()
        if line:
            try:
                entries.append(json.loads(line))
            except:
                pass

now = datetime.now()
last_30 = (now - timedelta(days=30)).strftime('%Y-%m-%d')
last_7  = (now - timedelta(days=7)).strftime('%Y-%m-%d')

recent_entries = [e for e in entries if e.get('date', '') >= last_30]
skill_entries  = [e for e in recent_entries if e.get('tipo') == 'skill']
agent_entries  = [e for e in recent_entries if e.get('tipo') == 'agent']

GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
RED    = '\033[0;31m'
BLUE   = '\033[0;34m'
GRAY   = '\033[0;37m'
NC     = '\033[0m'

# Top skills
skill_count = Counter(e['name'] for e in skill_entries)
print(f"{BLUE}Top Skills (últimos 30 días):{NC}")
for name, count in skill_count.most_common(limit // 2):
    bar = '█' * min(count, 20)
    print(f"  {name:<35} {bar} {count}")

print()

# Top agents
agent_count = Counter(e['name'] for e in agent_entries)
print(f"{BLUE}Top Agentes (últimos 30 días):{NC}")
for name, count in agent_count.most_common(limit // 2):
    bar = '█' * min(count, 20)
    print(f"  {name:<35} {bar} {count}")

# Skills del directorio que NUNCA aparecen en el log
all_skills = {f.stem for f in skills_dir.glob('*.md')} if skills_dir.exists() else set()
used_skills = set(skill_count.keys())
never_used  = all_skills - used_skills

print()
if never_used:
    print(f"{YELLOW}⚠️  Skills nunca usadas ({len(never_used)}):{NC}")
    for s in sorted(never_used)[:20]:
        print(f"  {GRAY}{s}{NC}")
else:
    print(f"{GREEN}✅ Todas las skills tienen al menos 1 uso registrado{NC}")

print()
print(f"Total registros: {len(entries)} | últimos 30 días: {len(recent_entries)}")
PYEOF
    ;;

# ─────────────────────────────────────────────────────────────
prune)
    DRY_RUN="${1:---dry-run}"

    if [[ ! -f "$USAGE_LOG" ]]; then
        echo "Sin datos suficientes para pruning."
        exit 0
    fi

    echo -e "${BLUE}Análisis de pruning (skills sin uso en 30 días):${NC}"

    python3 - "$USAGE_LOG" "$SKILLS_DIR" <<'PYEOF'
import json, sys
from datetime import datetime, timedelta
from pathlib import Path
from collections import Counter

log_file   = Path(sys.argv[1])
skills_dir = Path(sys.argv[2])

entries = []
with open(log_file) as f:
    for line in f:
        try: entries.append(json.loads(line.strip()))
        except: pass

last_30 = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
recent_skills = set(
    e['name'] for e in entries
    if e.get('date', '') >= last_30 and e.get('tipo') == 'skill'
)
all_skills = {f.stem: f for f in skills_dir.glob('*.md')} if skills_dir.exists() else {}
prune_candidates = {name: path for name, path in all_skills.items() if name not in recent_skills}

YELLOW = '\033[1;33m'; GREEN = '\033[0;32m'; NC = '\033[0m'

if not prune_candidates:
    print(f"{GREEN}✅ Sin candidatos para pruning{NC}")
else:
    print(f"Candidatos ({len(prune_candidates)}) — sin uso en 30 días:")
    for name, path in sorted(prune_candidates.items()):
        age_days = (datetime.now().timestamp() - path.stat().st_mtime) / 86400
        print(f"  {YELLOW}{name}{NC} (última mod: {int(age_days)} días atrás)")
    print()
    print("Para desactivar: mover a ~/.claude/skills/archive/")
    print("Esto es --dry-run. Los archivos NO fueron modificados.")
PYEOF
    ;;

*)
    echo "Uso: skill-tracker.sh [log|report|prune] [opciones]"
    ;;
esac

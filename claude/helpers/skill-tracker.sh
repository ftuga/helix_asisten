#!/usr/bin/env bash
# skill-tracker.sh — Registrar uso real de skills, agentes y MCPs por sesión
# Uso:
#   log    "<nombre>" "<tipo: skill|agent|mcp>" [proyecto]
#   report [--limit N]
#   prune  --dry-run        → lista candidatos sin tocar nada
#   prune  --execute        → archiva candidatos con confirmación interactiva
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
USAGE_LOG="$GLOBAL_DIR/memory/skill-usage.jsonl"
SKILLS_DIR="$GLOBAL_DIR/skills"
ARCHIVE_DIR="$GLOBAL_DIR/skills/archive"

cmd="${1:-report}"
shift || true

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; GRAY='\033[0;37m'; NC='\033[0m'

# ─── Función compartida: detectar todos los skills del directorio ────────────
_get_all_skills_py() {
cat <<'PYEOF'
from pathlib import Path
import sys

skills_dir = Path(sys.argv[1])
all_skills = {}

# Formato subdirectorio: skills/nombre/SKILL.md
for skill_md in skills_dir.glob('*/SKILL.md'):
    name = skill_md.parent.name
    if not name.startswith('_') and name != 'archive':
        all_skills[name] = skill_md

# Formato organizado: skills/_categoria/nombre/SKILL.md
for skill_md in skills_dir.glob('_*/*/SKILL.md'):
    name = skill_md.parent.name
    all_skills[name] = skill_md

PYEOF
}

case "$cmd" in

# ─────────────────────────────────────────────────────────────────────────────
log)
    NAME="${1:-}"
    TIPO="${2:-skill}"
    PROYECTO="${3:-}"
    [[ -z "$NAME" ]] && exit 0

    DATE=$(date '+%Y-%m-%d %H:%M')
    SHORT=$(date '+%Y-%m-%d')

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
entry = {'ts': sys.argv[1], 'date': sys.argv[2], 'name': sys.argv[3], 'tipo': sys.argv[4], 'proyecto': sys.argv[5]}
with open('$USAGE_LOG', 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
" "$DATE" "$SHORT" "$NAME" "$TIPO" "$PROYECTO"
    ;;

# ─────────────────────────────────────────────────────────────────────────────
report)
    LIMIT="${1:-20}"

    if [[ ! -f "$USAGE_LOG" ]]; then
        echo "Sin datos de uso aún."
        exit 0
    fi

    echo -e "${BLUE}⬡ Helix Usage Report${NC}"
    echo ""

    python3 - "$USAGE_LOG" "$SKILLS_DIR" "$LIMIT" <<PYEOF
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
        try: entries.append(json.loads(line.strip()))
        except: pass

now     = datetime.now()
last_30 = (now - timedelta(days=30)).strftime('%Y-%m-%d')
last_7  = (now - timedelta(days=7)).strftime('%Y-%m-%d')

recent = [e for e in entries if e.get('date','') >= last_30]

GREEN  = '\033[0;32m'; YELLOW = '\033[1;33m'; RED = '\033[0;31m'
BLUE   = '\033[0;34m'; GRAY   = '\033[0;37m'; NC  = '\033[0m'

def bar(n, mx=20): return '█' * min(n, mx)
def section(title, tipo):
    items = Counter(e['name'] for e in recent if e.get('tipo') == tipo)
    print(f"{BLUE}{title} (últimos 30 días):{NC}")
    if items:
        for name, count in items.most_common(limit // 3):
            week = sum(1 for e in entries if e.get('tipo')==tipo and e.get('name')==name and e.get('date','')>=last_7)
            print(f"  {name:<38} {bar(count)} {count:>3}  (7d: {week})")
    else:
        print(f"  {GRAY}sin datos{NC}")
    print()
    return items

skill_count = section("Skills", "skill")
agent_count = section("Agentes", "agent")
mcp_count   = section("MCPs", "mcp")

# Skills instaladas que NUNCA aparecen en el log (detección correcta)
all_skills = {}
for skill_md in skills_dir.glob('*/SKILL.md'):
    name = skill_md.parent.name
    if not name.startswith('_') and name != 'archive':
        all_skills[name] = skill_md
for skill_md in skills_dir.glob('_*/*/SKILL.md'):
    all_skills[skill_md.parent.name] = skill_md

used    = set(skill_count.keys())
never   = {n: p for n,p in all_skills.items() if n not in used}
stale   = {n: p for n,p in all_skills.items() if n in used and skill_count[n] == 0}

if never:
    print(f"{YELLOW}⚠️  Skills instaladas sin uso registrado ({len(never)}):{NC}")
    for name in sorted(never)[:25]:
        age = int((datetime.now().timestamp() - never[name].stat().st_mtime) / 86400)
        print(f"  {GRAY}{name:<38}{NC} instalada hace {age}d")
    print()
else:
    print(f"{GREEN}✅ Todas las skills tienen uso registrado{NC}\n")

total_30 = len(recent)
total    = len(entries)
print(f"Total registros: {total} | últimos 30 días: {total_30}")
PYEOF
    ;;

# ─────────────────────────────────────────────────────────────────────────────
prune)
    MODE="${1:---dry-run}"

    if [[ ! -f "$USAGE_LOG" ]]; then
        echo "Sin datos suficientes para pruning (mínimo 30 días de datos)."
        exit 0
    fi

    echo -e "${BLUE}⬡ Helix Prune Analysis${NC}"
    echo ""

    CANDIDATES=$(python3 - "$USAGE_LOG" "$SKILLS_DIR" <<'PYEOF'
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
recent_skills = set(e['name'] for e in entries if e.get('date','') >= last_30 and e.get('tipo') == 'skill')

all_skills = {}
for skill_md in skills_dir.glob('*/SKILL.md'):
    name = skill_md.parent.name
    if not name.startswith('_') and name != 'archive':
        all_skills[name] = skill_md.parent
for skill_md in skills_dir.glob('_*/*/SKILL.md'):
    all_skills[skill_md.parent.name] = skill_md.parent

prune_candidates = {n: p for n,p in all_skills.items() if n not in recent_skills}

for name, path in sorted(prune_candidates.items()):
    age = int((datetime.now().timestamp() - path.stat().st_mtime) / 86400)
    print(f"{name}|{path}|{age}")
PYEOF
)

    if [[ -z "$CANDIDATES" ]]; then
        echo -e "${GREEN}✅ Sin candidatos para pruning — todas las skills tienen uso reciente.${NC}"
        exit 0
    fi

    echo -e "${YELLOW}Candidatos sin uso en 30 días:${NC}"
    echo ""
    while IFS='|' read -r name path age; do
        echo -e "  ${YELLOW}${name}${NC} (sin uso en 30d, modificada hace ${age}d)"
        echo -e "  ${GRAY}  → ${path}${NC}"
        echo ""
    done <<< "$CANDIDATES"

    COUNT=$(echo "$CANDIDATES" | wc -l | tr -d ' ')

    if [[ "$MODE" == "--dry-run" ]]; then
        echo -e "${GRAY}Modo --dry-run. Para archivar: bash skill-tracker.sh prune --execute${NC}"
        exit 0
    fi

    # ── Modo --execute: archivar con confirmación ──────────────────────────
    echo -e "${RED}⚠️  Se van a mover ${COUNT} skill(s) a ${ARCHIVE_DIR}/${NC}"
    echo -e "   Los archivos no se eliminan — podés restaurarlos desde archive/"
    echo ""
    read -r -p "¿Continuar? [s/N] " confirm
    [[ "$confirm" != "s" && "$confirm" != "S" ]] && { echo "Cancelado."; exit 0; }

    mkdir -p "$ARCHIVE_DIR"
    ARCHIVED=0

    while IFS='|' read -r name path age; do
        if [[ -d "$path" ]]; then
            # Confirmación individual para skills que nunca se usaron (podrían ser recientes)
            if [[ "$age" -lt 7 ]]; then
                read -r -p "  '${name}' tiene solo ${age}d de antigüedad. ¿Archivar igual? [s/N] " confirm2
                [[ "$confirm2" != "s" && "$confirm2" != "S" ]] && continue
            fi
            mv "$path" "$ARCHIVE_DIR/${name}"
            echo -e "  ${GREEN}✅ Archivado:${NC} ${name}"
            ARCHIVED=$((ARCHIVED + 1))
        fi
    done <<< "$CANDIDATES"

    echo ""
    echo -e "${GREEN}✅ ${ARCHIVED} skill(s) archivadas en ${ARCHIVE_DIR}/${NC}"
    echo -e "${GRAY}   Para restaurar: mv ${ARCHIVE_DIR}/<nombre> ${SKILLS_DIR}/${NC}"
    ;;

# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
quality)
    # Registrar feedback de calidad sobre un skill/agente usado
    # Uso: skill-tracker.sh quality <nombre> <1|2|3> [razón]
    # 1=falló/incorrecto  2=parcial/requirió corrección  3=correcto al primer intento
    NAME="${1:-}"
    SCORE="${2:-}"
    REASON="${3:-}"
    [[ -z "$NAME" || -z "$SCORE" ]] && { echo "Uso: quality <nombre> <1|2|3> [razón]"; exit 1; }

    QUALITY_LOG="$GLOBAL_DIR/memory/skill-quality.jsonl"
    DATE=$(date '+%Y-%m-%d %H:%M')

    python3 -c "
import json, sys
entry = {'ts': sys.argv[1], 'name': sys.argv[2], 'score': int(sys.argv[3]), 'reason': sys.argv[4]}
with open('$QUALITY_LOG', 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
print(f'Quality registrado: {sys.argv[2]} → score {sys.argv[3]}')
" "$DATE" "$NAME" "$SCORE" "$REASON"
    ;;

# ─────────────────────────────────────────────────────────────────────────────
quality-report)
    QUALITY_LOG="$GLOBAL_DIR/memory/skill-quality.jsonl"
    [[ ! -f "$QUALITY_LOG" ]] && echo "Sin datos de calidad aún." && exit 0

    echo -e "${BLUE}⬡ Quality Report${NC}"
    echo ""

    python3 - "$QUALITY_LOG" <<'PYEOF'
import json, sys
from pathlib import Path
from collections import defaultdict

log = Path(sys.argv[1])
entries = [json.loads(l) for l in log.read_text().splitlines() if l.strip()]

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

scores = defaultdict(list)
for e in entries:
    scores[e['name']].append(e['score'])

print(f"{'Nombre':<38} {'Avg':>5}  {'Usos':>5}  Indicador")
print("─" * 65)
for name, s in sorted(scores.items(), key=lambda x: sum(x[1])/len(x[1])):
    avg = sum(s) / len(s)
    indicator = f"{GREEN}✅ Correcto{NC}" if avg >= 2.5 else f"{YELLOW}⚠️  Parcial{NC}" if avg >= 1.5 else f"{RED}❌ Problemático{NC}"
    print(f"  {name:<36} {avg:>5.1f}  {len(s):>5}  {indicator}")
PYEOF
    ;;

*)
    echo "Uso: skill-tracker.sh [log|report|prune|quality|quality-report] [opciones]"
    echo "  log <nombre> <skill|agent|mcp> [proyecto]"
    echo "  report [--limit N]"
    echo "  prune --dry-run | --execute"
    echo "  quality <nombre> <1|2|3> [razón]   — 1=falló 2=parcial 3=correcto"
    echo "  quality-report                      — resumen de calidad"
    ;;
esac

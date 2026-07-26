#!/usr/bin/env bash
# Auto-detect Python binary on first run (handles Windows where `python3` is the MS Store stub)
if [[ ! -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" && -x "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-python-detect.sh" ]]; then
    bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-python-detect.sh" >/dev/null 2>&1 || true
fi
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# .claude/session-start.sh — Ejecutar al inicio de cada sesión
# Auto-detecta proyecto, carga contexto global + proyecto
set -euo pipefail

DATE=$(date '+%Y-%m-%d %H:%M')
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

GLOBAL_CLAUDE_MD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
GLOBAL_MEMORY_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory"
GLOBAL_SKILLS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"

# ── Auto-detección de raíz del proyecto ──────────────────────
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" && "$dir" != "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

PROJECT_ROOT=""
PROJECT_CLAUDE_MD=""
PROJECT_MEMORY_DIR=""
PROJECT_SKILLS_DIR=""

if PROJECT_ROOT=$(find_project_root 2>/dev/null); then
  PROJECT_CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
  PROJECT_MEMORY_DIR="$PROJECT_ROOT/.claude/memory"
  PROJECT_SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
fi

mkdir -p "$GLOBAL_MEMORY_DIR"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ⬡  Helix — Agente Auto-Evolutivo                      ║${NC}"
echo -e "${BLUE}║   Iniciando sesión: $DATE                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Mostrar proyecto detectado ────────────────────────────────
if [[ -n "$PROJECT_ROOT" ]]; then
  echo -e "${GREEN}📁 Proyecto:${NC} $PROJECT_ROOT"
else
  echo -e "${YELLOW}📁 Sin proyecto detectado — contexto global únicamente${NC}"
fi
echo ""

# ── Contar skills (global recursivo + proyecto) ───────────────
TOTAL_SKILLS=$(find "$GLOBAL_SKILLS_DIR" -name "*.md" 2>/dev/null | wc -l)
if [[ -n "$PROJECT_SKILLS_DIR" && -d "$PROJECT_SKILLS_DIR" ]]; then
  PROJECT_SKILLS=$(find "$PROJECT_SKILLS_DIR" -name "*.md" 2>/dev/null | wc -l)
  TOTAL_SKILLS=$((TOTAL_SKILLS + PROJECT_SKILLS))
fi

# ── Contar evoluciones (desde global) ────────────────────────
TOTAL_EVOLUTIONS=$(grep -c "^\| [0-9]" "$GLOBAL_CLAUDE_MD" 2>/dev/null || echo "0")

echo -e "${GREEN}📊 Estado del agente:${NC}"
echo "   Skills disponibles: $TOTAL_SKILLS"
echo "   Evoluciones registradas: $TOTAL_EVOLUTIONS"
echo ""

# ── Pendientes de sesión anterior ────────────────────────────
PENDING_FILE="${PROJECT_MEMORY_DIR:-$GLOBAL_MEMORY_DIR}/pending.md"
if [[ -f "$PENDING_FILE" && -s "$PENDING_FILE" ]]; then
  echo -e "${YELLOW}⏳ PENDIENTES DE SESIÓN ANTERIOR:${NC}"
  cat "$PENDING_FILE"
  echo ""
fi

# ── Zonas de riesgo ALTO (proyecto primero, sino global) ─────
RISK_SOURCE="${PROJECT_CLAUDE_MD:-$GLOBAL_CLAUDE_MD}"
RIESGOS=$(grep "🔴 ALTO" "$RISK_SOURCE" 2>/dev/null | head -5 || true)
if [[ -n "$RIESGOS" ]]; then
  echo -e "${YELLOW}⚠️  ZONAS DE RIESGO ACTIVAS (🔴 ALTO):${NC}"
  echo "$RIESGOS"
  echo ""
fi

# ── Última evolución (desde global) ──────────────────────────
LAST=$("${HELIX_PYTHON:-python3}" -c "
import re
with open('${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md') as f:
    content = f.read()
m = re.search(r'<!-- LAST_EVOLUTION -->(.*?)<!-- /LAST_EVOLUTION -->', content)
print(m.group(1) if m else 'No registrada')
" 2>/dev/null || echo "No registrada")
echo -e "${GREEN}🕐 Última evolución:${NC} $LAST"
echo ""

# ── Health-check silencioso — alerta solo si hay problemas ───
HEALTH_RESULT=$(bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/health-check.sh" 2>&1 | tail -3) || true
if echo "$HEALTH_RESULT" | grep -q "❌"; then
  echo -e "${RED}⚠️  ALERTA: Ecosistema con problemas críticos — ejecutar: bash ~/.claude/health-check.sh${NC}"
  echo ""
fi

# ── Drift agents-index ↔ disco (advisory — audit 2026-06-10 P0-2) ──
AGENTS_DRIFT=$(bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-agents-audit.sh" 2>/dev/null | "${HELIX_PYTHON:-python3}" -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
o=d.get('orphans',{})
n=len(o.get('indexed_without_file',[]))+len(o.get('file_without_index_entry',[]))
if n: print(n)
" 2>/dev/null) || true
if [[ -n "${AGENTS_DRIFT:-}" ]]; then
  echo -e "${YELLOW}⚠️  agents-index desincronizado del disco (${AGENTS_DRIFT} orphans) — bash helpers/helix-agents-audit.sh${NC}"
  echo ""
fi

# ── L4 integrity verify (advisory — H-2 / TASK-022) ──────────
# Surface tamper/drift in core files (settings, CLAUDE.md, helpers .sh/.py,
# lifecycle & council scripts) every session — previously integrity-check.sh
# ran ONLY when invoked by hand (audit finding H-2: dead defense). ADVISORY
# ONLY: never blocks session-start (set -e safe via '|| true'); exports
# CLAUDE_CONFIG_DIR so manifest keys match the live tree. Re-baseline after a
# legitimate evolution with: integrity-check.sh update.
INTEGRITY_SH="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/integrity-check.sh"
if [[ -f "$INTEGRITY_SH" ]]; then
  INTEG_OUT=$(CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" bash "$INTEGRITY_SH" verify 2>/dev/null) || true
  if echo "$INTEG_OUT" | grep -q "cambios detectados"; then
    echo -e "${YELLOW}⬡  Integridad core: cambios detectados — revisar si son legítimos:${NC}"
    echo "$INTEG_OUT" | grep -E '^[[:space:]]+[~+-] ' | head -8
    echo -e "${YELLOW}   Si son tuyos: bash \"\$CLAUDE_CONFIG_DIR/helpers/integrity-check.sh\" update${NC}"
    echo ""
  fi
fi

# ── Registrar inicio de sesión ────────────────────────────────
echo "$DATE — SESIÓN INICIADA${PROJECT_ROOT:+ [$PROJECT_ROOT]}" >> "$GLOBAL_MEMORY_DIR/session-log.txt"

# ── Detectar alerta de salud de Helix ────────────────────────
ALERTA_FILE="${PROJECT_MEMORY_DIR:-$GLOBAL_MEMORY_DIR}/helix-alerta.md"
if [[ -f "$ALERTA_FILE" ]]; then
  echo -e "\033[0;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo "[HELIX-NECESITAMOS-HABLAR]"
  echo "Problemas detectados al cerrar la sesión anterior."
  echo "Helix: leer helix-alerta.md y comunicarlos ANTES de responder cualquier tarea."
  cat "$ALERTA_FILE"
  echo -e "\033[0;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
  echo ""
fi

# ── User profile — contexto de quién trabaja con Helix ───────
USER_PROFILE="$GLOBAL_MEMORY_DIR/user-profile.md"
if [[ -f "$USER_PROFILE" ]]; then
  PROFILE_CONTENT=$("${HELIX_PYTHON:-python3}" -c "
from pathlib import Path
content = Path('$USER_PROFILE').read_text()
lines = content.splitlines()
filled = [l for l in lines if l.strip() and not l.startswith('#') and not l.startswith('>') and '<!--' not in l]
for l in filled[:6]:
    print('   ' + l.strip()[:100])
" 2>/dev/null || true)
  if [[ -n "\$PROFILE_CONTENT" ]]; then
    echo -e "\${GREEN}👤 Perfil de usuario cargado:\${NC}"
    echo "\$PROFILE_CONTENT"
    echo ""
  else
    echo -e "\${YELLOW}👤 user-profile.md existe pero está vacío — completar para personalizar Helix.\${NC}"
    echo ""
  fi
fi

# ── Detectar modo economía persistente ───────────────────────
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude/memory/.helix-economia" ]]; then
  echo -e "${YELLOW}💰 [HELIX-ECONOMIA-ACTIVO] Modo economía persistente.${NC}"
  echo "   Sin subagentes · Sin swarm · Grep antes que Read · Respuestas cortas"
  echo ""
fi

# ── Detectar si proyecto necesita análisis inicial ────────────
if [[ -n "$PROJECT_ROOT" ]]; then
  ANALYSIS_FILE="$PROJECT_ROOT/.claude/memory/helix-analysis.md"
  DECLINED_FILE="$PROJECT_ROOT/.claude/memory/.analysis-declined"

  if [[ ! -f "$ANALYSIS_FILE" ]] && [[ ! -f "$DECLINED_FILE" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "[HELIX-SUGGEST-ANALYSIS]"
    echo "Este proyecto no tiene análisis inicial ni bitácora guardados."
    echo "Helix: al final de tu primer mensaje, sugerir /helix-analiza al usuario."
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
  elif [[ -f "$ANALYSIS_FILE" ]]; then
    # Verificar obsolescencia (>30 días)
    ANALYSIS_AGE=$("${HELIX_PYTHON:-python3}" -c "
import os, time
mtime = os.path.getmtime('$ANALYSIS_FILE')
days = (time.time() - mtime) / 86400
print(int(days))
" 2>/dev/null || echo "0")
    if [[ "$ANALYSIS_AGE" -gt 30 ]]; then
      echo -e "${YELLOW}⚠️  Análisis del proyecto tiene ${ANALYSIS_AGE} días — considerar /helix-actualiza${NC}"
    else
      echo -e "${GREEN}🔍 Análisis del proyecto en memoria (${ANALYSIS_AGE} días).${NC}"
    fi
    echo ""
  fi
fi

# ── Reglas activas (últimas 5 evoluciones instaladas) ────────
ACTIVE_RULES="$GLOBAL_MEMORY_DIR/active-rules.md"
if [[ -f "$ACTIVE_RULES" ]]; then
  RULE_COUNT=$(grep -c "^- \[" "$ACTIVE_RULES" 2>/dev/null || echo "0")
  if [[ "$RULE_COUNT" -gt 0 ]]; then
    echo -e "${GREEN}🧠 Reglas activas (${RULE_COUNT} instaladas — últimas 5):${NC}"
    grep "^- \[" "$ACTIVE_RULES" | head -5 | sed 's/^- \[/   · [/'
    echo ""
  fi
fi

# ── Contexto rápido del proyecto (si hay análisis) ────────────
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude/memory/helix-analysis.md" ]]; then
  echo -e "${GREEN}📋 Contexto del proyecto:${NC}"
  "${HELIX_PYTHON:-python3}" -c "
from pathlib import Path
content = Path('$PROJECT_ROOT/.claude/memory/helix-analysis.md').read_text()
# Extraer sección de resumen o primeras líneas con contenido
lines = [l for l in content.splitlines() if l.strip() and not l.startswith('#')]
for line in lines[:6]:
    print('   ' + line[:100])
" 2>/dev/null || true
  echo ""
fi

# ── Roadmap — milestone activo ───────────────────────────────
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude/memory/helix-roadmap.md" ]]; then
  MILESTONE=$("${HELIX_PYTHON:-python3}" -c "
from pathlib import Path
content = Path('$PROJECT_ROOT/.claude/memory/helix-roadmap.md').read_text()
lines = content.splitlines()
in_progress = False
for line in lines:
    if '## 🔵 En Progreso' in line: in_progress = True
    elif line.startswith('## '): in_progress = False
    elif in_progress and line.strip().startswith('|') and not line.strip().startswith('|--') and 'Milestone' not in line:
        cols = [c.strip() for c in line.split('|') if c.strip()]
        if cols and cols[0] != '—' and len(cols) >= 2:
            print(f'{cols[0]} — {cols[1][:60]}')
            break
" 2>/dev/null || true)
  if [[ -n "$MILESTONE" ]]; then
    echo -e "${BLUE}🗺️  Milestone activo:${NC} $MILESTONE"
    echo ""
  fi
fi

# ── Backlog del proyecto (en progreso + bloqueados) ──────────
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude/memory/helix-backlog.md" ]]; then
  BACKLOG_ITEMS=$("${HELIX_PYTHON:-python3}" -c "
from pathlib import Path
content = Path('$PROJECT_ROOT/.claude/memory/helix-backlog.md').read_text()
lines = content.splitlines()
section = ''
items = []
for line in lines:
    if '## 🔵 En Progreso' in line: section = 'progreso'
    elif '## 🔴 Bloqueado' in line: section = 'bloqueado'
    elif line.startswith('## '): section = ''
    elif section and line.strip().startswith('|') and not line.strip().startswith('|--') and 'ID' not in line and line.strip() != '|':
        cols = [c.strip() for c in line.split('|') if c.strip()]
        if len(cols) >= 2 and cols[0] != '—':
            emoji = '🔵' if section == 'progreso' else '🔴'
            items.append(f'   {emoji} {cols[0]}: {cols[1][:60]}')
for item in items[:5]:
    print(item)
" 2>/dev/null || true)

  if [[ -n "$BACKLOG_ITEMS" ]]; then
    echo -e "${BLUE}📋 Backlog activo:${NC}"
    echo "$BACKLOG_ITEMS"
    echo ""
  fi
fi

# ── Bitácora reciente del proyecto ───────────────────────────
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude/memory/helix-bitacora.md" ]]; then
  BITACORA_ROWS=$("${HELIX_PYTHON:-python3}" -c "
from pathlib import Path
content = Path('$PROJECT_ROOT/.claude/memory/helix-bitacora.md').read_text()
# Extraer filas de tabla con datos (no headers ni separadores)
rows = [
    l.strip() for l in content.splitlines()
    if l.strip().startswith('|')
    and not l.strip().startswith('|--')
    and 'Fecha' not in l
    and 'Tipo' not in l
]
# Últimas 5 entradas
for row in rows[-5:]:
    print('   ' + row[:120])
" 2>/dev/null || true)

  if [[ -n "$BITACORA_ROWS" ]]; then
    echo -e "${GREEN}📓 Bitácora reciente (últimas entradas):${NC}"
    echo "$BITACORA_ROWS"
    echo ""
  fi
fi

# ── Alerta de calidad — agentes problemáticos ─────────────────
QUALITY_LOG="$GLOBAL_MEMORY_DIR/skill-quality.jsonl"
if [[ -f "$QUALITY_LOG" ]]; then
  PROBLEMATIC=$("${HELIX_PYTHON:-python3}" -c "
import json
from collections import defaultdict
scores = defaultdict(list)
for line in open('$QUALITY_LOG'):
    try:
        e = json.loads(line.strip())
        scores[e['name']].append(e['score'])
    except: pass
bad = [(n, sum(s)/len(s), len(s)) for n, s in scores.items() if sum(s)/len(s) < 1.5 and len(s) >= 2]
for name, avg, n in sorted(bad, key=lambda x: x[1]):
    print(f'   ⚠️  {name}: avg={avg:.1f} ({n} usos) — revisar o reemplazar')
" 2>/dev/null || true)
  if [[ -n "$PROBLEMATIC" ]]; then
    echo -e "${YELLOW}🔴 Agentes con calidad baja (avg < 1.5):${NC}"
    echo "$PROBLEMATIC"
    echo "   → Ver detalle: bash ~/.claude/helpers/skill-tracker.sh quality-report"
    echo ""
  fi
fi

# ── Routing feedback — agentes más efectivos del proyecto ─────
FEEDBACK_FILE="$GLOBAL_MEMORY_DIR/routing-feedback.jsonl"
if [[ -f "$FEEDBACK_FILE" ]]; then
  FEEDBACK_COUNT=$(wc -l < "$FEEDBACK_FILE" 2>/dev/null | tr -d ' ' || echo "0")
  if [[ "$FEEDBACK_COUNT" -gt 5 ]]; then
    echo -e "${GREEN}🎯 Routing aprendido ($FEEDBACK_COUNT decisiones registradas):${NC}"
    "${HELIX_PYTHON:-python3}" -c "
import json
from collections import Counter
hits = []
proj = '$(basename ${PROJECT_ROOT:-global})'
with open('$FEEDBACK_FILE') as f:
    for line in f:
        try:
            d = json.loads(line)
            if proj == 'global' or d.get('proyecto','') == proj:
                hits.append((d['agente'], d['resultado']))
        except:
            pass
if hits:
    by_agent = Counter(a for a,_ in hits)
    success = Counter(a for a,r in hits if r == 'success')
    top = by_agent.most_common(3)
    for agent, total in top:
        wins = success.get(agent, 0)
        pct = int(wins/total*100) if total else 0
        print(f'   {agent}: {wins}/{total} éxitos ({pct}%)')
" 2>/dev/null || true
    echo ""
  fi
fi

# ── Recuperación proactiva de Qdrant ─────────────────────────
if [[ -n "$PROJECT_ROOT" ]]; then
  REFLEXION_SCRIPT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-reflexion.sh"
  if [[ -f "$REFLEXION_SCRIPT" ]] && curl -sf "http://localhost:6333/healthz" &>/dev/null; then
    # Construir query desde nombre del proyecto + stack detectado
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
    STACK_HINT=""
    [[ -f "$PROJECT_ROOT/requirements.txt" || -f "$PROJECT_ROOT/pyproject.toml" ]] && STACK_HINT="python fastapi"
    [[ -f "$PROJECT_ROOT/package.json" ]] && STACK_HINT="$STACK_HINT react typescript"
    [[ -f "$PROJECT_ROOT/docker-compose.yml" || -f "$PROJECT_ROOT/docker-compose.yaml" ]] && STACK_HINT="$STACK_HINT docker"
    QUERY="errores resueltos $PROJECT_NAME $STACK_HINT"

    MEMORIES=$(bash "$REFLEXION_SCRIPT" search "$QUERY" 2>/dev/null | grep -v '^$' | head -6 || true)
    if [[ -n "$MEMORIES" ]]; then
      echo -e "${BLUE}🧠 Memorias relevantes para este proyecto:${NC}"
      echo "$MEMORIES" | sed 's/^/   /'
      echo ""
    fi
  fi
fi

# ── Detección de memoria stale vs git log ────────────────────
if [[ -n "$PROJECT_ROOT" && -d "$PROJECT_ROOT/.git" ]]; then
  STALENESS_SCRIPT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-staleness.sh"
  STALE_FOUND=false
  STALE_MSGS=()
  if [[ -f "$STALENESS_SCRIPT" ]]; then
    while IFS= read -r -d '' mem_file; do
      msg=$(bash "$STALENESS_SCRIPT" "$mem_file" 2>/dev/null || true)
      if [[ -n "$msg" ]]; then
        STALE_FOUND=true
        STALE_MSGS+=("   $msg")
      fi
    done < <(find "$PROJECT_ROOT/.claude/memory" -maxdepth 1 -name "helix-*.md" -print0 2>/dev/null)
  fi
  if [[ "$STALE_FOUND" == "true" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "[HELIX-SUGGEST-ACTUALIZA]"
    echo "Archivos de memoria desactualizados respecto a commits recientes:"
    for msg in "${STALE_MSGS[@]}"; do echo "$msg"; done
    echo "Helix: antes de responder sobre estado/pendientes, verificar git log y recomendar /helix-actualiza."
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
  fi
fi

# ── D5.C — Detectar council REJECTED sin override-log entry (HELIX-OVERRIDE-UNDOCUMENTED) ──
# Backstop institucional del protocolo D4 overrides ejecutivos.
# Detecta: archivos en council/log/*.yaml con decision: REJECTED que no tengan
# entry correspondiente en council/overrides-log/*.yaml.
# Caso "limpio" (no override): REJECTED sin override-log es OK — significa que NO se overrideó.
# El warning solo se emite si hay >0 REJECTED sin override Y el creator quiere revisar.
# Filosofía: chequeo defensivo, no enforcement. El creator interpreta.
COUNCIL_LOG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/council/log"
OVERRIDES_LOG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/council/overrides-log"
if [[ -d "$COUNCIL_LOG_DIR" ]]; then
  REJECTED_COUNCILS=()
  while IFS= read -r -d '' council_file; do
    # Extraer session_id (campo session_id: del YAML)
    sid=$(grep -E '^session_id:' "$council_file" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || true)
    [[ -z "$sid" ]] && continue
    # Verificar decision REJECTED
    if grep -qE '^decision:\s*REJECTED' "$council_file" 2>/dev/null; then
      # Match por contenido: buscar overridden_council_id: <sid> dentro de overrides-log/
      has_override_entry=false
      if [[ -d "$OVERRIDES_LOG_DIR" ]]; then
        if grep -rqE "^overridden_council_id:\s*\"?${sid}\"?" "$OVERRIDES_LOG_DIR" 2>/dev/null; then
          has_override_entry=true
        fi
      fi
      if [[ "$has_override_entry" == "false" ]]; then
        REJECTED_COUNCILS+=("$sid ($(basename "$council_file"))")
      fi
    fi
  done < <(find "$COUNCIL_LOG_DIR" -maxdepth 1 -name "*.yaml" -print0 2>/dev/null)

  if [[ ${#REJECTED_COUNCILS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "[HELIX-OVERRIDE-UNDOCUMENTED]"
    echo "Council(s) REJECTED sin entry correspondiente en overrides-log/:"
    for entry in "${REJECTED_COUNCILS[@]}"; do echo "   - $entry"; done
    echo ""
    echo "Caso normal: REJECTED sin override = NO se overrideó. No requiere acción."
    echo "Caso a investigar: si la doctrina (CLAUDE.md o topics/) cambió tras alguno"
    echo "  de estos REJECTED implementando lo opuesto al voto, registrar en"
    echo "  ~/.helix/council/overrides-log/ siguiendo el protocolo D5.C."
    echo "  Doctrina: ~/.helix/memory/topics/overrides-ejecutivos.md"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
  fi
fi

# ── D5 — Deadline tracker council preconditions (D2.1 sin cron) ──
# Emite warning cuando se alcanza fecha de precondition del council 20260610T161758Z-ianr.
# Reversibility: crear flag ~/.helix/memory/.deadline-acked-<id> apaga el warning.
TODAY_ISO=$(date -u +%Y-%m-%d)
MEMORY_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory"
mkdir -p "$MEMORY_DIR" 2>/dev/null

check_deadline() {
  local id="$1" deadline="$2" action="$3" detail="$4"
  local flag="$MEMORY_DIR/.deadline-acked-${id}"
  [[ -f "$flag" ]] && return 0  # acknowledged
  # Solo emitir si hoy >= deadline
  if [[ "$TODAY_ISO" > "$deadline" || "$TODAY_ISO" == "$deadline" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "[HELIX-DEADLINE-${id}]"
    echo "Deadline alcanzada: $deadline (hoy: $TODAY_ISO)"
    echo "Acción requerida: $action"
    echo "Detalle: $detail"
    echo ""
    echo "Para marcar como hecho: touch $flag"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
  fi
}

# P1 #1 — Bench retrospectivo HELIX-LANG (council D5.B, 30d post-cementación)
check_deadline "BENCH-LANG" "2026-07-10" \
  "Ejecutar bench retrospectivo HELIX-LANG (régimen mixto vs #84 universal)" \
  "Comparar tokens consumidos en councils 2026-05-07 → 2026-06-09 vs 2026-06-10 → 2026-07-10 con tiktoken cl100k. Si NO baja ≥15% → re-council. Ver topics/helix-lang-regimen-mixto.md §Bench retrospectivo."

# P1 #2 — Verificación calendárica gate A4 Capa 2 (council D5.A, 90d post-cementación)
check_deadline "GATE-A4" "2026-09-10" \
  "Verificar gate A4 (Capa 2 propia) — chequear si capa2-bypass-counter.jsonl tiene ≥10 entries en últimos 30d" \
  "cat ~/.helix/memory/audit/capa2-bypass-counter.jsonl | wc -l. Si 0 con sesiones activas → bug del hook (anti-BUG-G2). Si <10 → mantener A3. Si ≥10 → re-council. Ver topics/capa2-status.md."

# ── Detectar snapshot conversacional reciente (HELIX-SUGGEST-RESUME) ─
SNAPSHOT_PROJECT="${PROJECT_ROOT:+$(basename "$PROJECT_ROOT")}"
SNAPSHOT_PROJECT="${SNAPSHOT_PROJECT:-global}"
SNAPSHOT_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/snapshots/$SNAPSHOT_PROJECT"
if [[ -d "$SNAPSHOT_DIR" ]]; then
  LATEST_SNAPSHOT=$(ls -t "$SNAPSHOT_DIR"/*.yaml 2>/dev/null | head -1)
  if [[ -n "$LATEST_SNAPSHOT" ]]; then
    SNAP_AGE_H=$(( ($(date +%s) - $(stat -c %Y "$LATEST_SNAPSHOT")) / 3600 ))
    SNAP_SUMMARY=$(grep "^summary:" "$LATEST_SNAPSHOT" | head -1 | sed 's/^summary:\s*//' | tr -d '"' | cut -c 1-100)
    if (( SNAP_AGE_H < 168 )); then  # <7 días, mostrar
      echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo "[HELIX-SUGGEST-RESUME]"
      echo "Snapshot disponible — proyecto: $SNAPSHOT_PROJECT, hace ${SNAP_AGE_H}h"
      echo "Resumen: ${SNAP_SUMMARY}"
      echo "Helix: ofrecer al final del primer mensaje (1) retomar / (2) nuevo chat / (3) ver detalle."
      echo "Comando detalle: bash ~/.claude/helpers/helix-snapshot.sh resume $SNAPSHOT_PROJECT"
      echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo ""
    fi
  fi
fi

echo -e "${GREEN}✅ Contexto cargado. Listo para trabajar.${NC}"
echo ""
# ── Vector memory sync (silencioso) ──────────────────────────
HV_SCRIPT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hv.sh"
if [[ -f "$HV_SCRIPT" ]]; then
  if curl -sf "http://localhost:6333/healthz" &>/dev/null; then
    bash "$HV_SCRIPT" sync &>/dev/null &
    echo -e "${GREEN}🧠 Vector store sincronizando...${NC}"
  else
    (docker start helix-qdrant &>/dev/null && sleep 2 && bash "$HV_SCRIPT" sync &>/dev/null) &
    echo -e "${YELLOW}⚠️  Vector store offline — intentando iniciar...${NC}"
  fi
  echo ""
fi

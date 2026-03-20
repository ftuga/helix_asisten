#!/usr/bin/env bash
# .claude/session-start.sh — Ejecutar al inicio de cada sesión
# Auto-detecta proyecto, carga contexto global + proyecto
set -euo pipefail

DATE=$(date '+%Y-%m-%d %H:%M')
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'

GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
GLOBAL_MEMORY_DIR="$HOME/.claude/memory"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

# ── Auto-detección de raíz del proyecto ──────────────────────
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]]; then
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
LAST=$(python3 -c "
import re
with open('$HOME/.claude/CLAUDE.md') as f:
    content = f.read()
m = re.search(r'<!-- LAST_EVOLUTION -->(.*?)<!-- /LAST_EVOLUTION -->', content)
print(m.group(1) if m else 'No registrada')
" 2>/dev/null || echo "No registrada")
echo -e "${GREEN}🕐 Última evolución:${NC} $LAST"
echo ""

# ── Health-check silencioso — alerta solo si hay problemas ───
HEALTH_RESULT=$(bash "$HOME/.claude/health-check.sh" 2>&1 | tail -3)
if echo "$HEALTH_RESULT" | grep -q "❌"; then
  echo -e "${RED}⚠️  ALERTA: Ecosistema con problemas críticos — ejecutar: bash ~/.claude/health-check.sh${NC}"
  echo ""
fi

# ── Registrar inicio de sesión ────────────────────────────────
echo "$DATE — SESIÓN INICIADA${PROJECT_ROOT:+ [$PROJECT_ROOT]}" >> "$GLOBAL_MEMORY_DIR/session-log.txt"

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
    ANALYSIS_AGE=$(python3 -c "
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

echo -e "${GREEN}✅ Contexto cargado. Listo para trabajar.${NC}"
echo ""

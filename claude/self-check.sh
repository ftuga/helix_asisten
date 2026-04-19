#!/usr/bin/env bash
# .claude/self-check.sh — Checklist pre-cierre de tarea de Helix
# Stack-aware: detecta el tipo de proyecto y activa solo los checks relevantes
set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; WARN=0; FAIL=0

check()   { echo -e "  ${GREEN}✅${NC} $1"; PASS=$((PASS + 1)); }
warn()    { echo -e "  ${YELLOW}⚠️ ${NC} $1"; WARN=$((WARN + 1)); }
fail()    { echo -e "  ${RED}❌${NC} $1"; FAIL=$((FAIL + 1)); }
section() { echo -e "\n${BLUE}▶ $1${NC}"; }
skip()    { echo -e "  \033[2m–  $1 (omitido)\033[0m"; }

# ── Auto-detección de proyecto ────────────────────────────────
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]] && echo "$dir" && return 0
    dir="$(dirname "$dir")"
  done
  return 1
}

GLOBAL_MEMORY_DIR="$HOME/.claude/memory"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
PROJECT_ROOT=""

if PROJECT_ROOT=$(find_project_root 2>/dev/null); then
  PROJECT_SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
else
  PROJECT_SKILLS_DIR="$GLOBAL_SKILLS_DIR"
fi

# ── Detección de stack del proyecto ──────────────────────────
HAS_DOCKER=false; HAS_FASTAPI=false; HAS_CELERY=false
HAS_FRONTEND=false; HAS_TYPESCRIPT=false; HAS_PYTHON=false

if [[ -n "$PROJECT_ROOT" ]]; then
  [[ -f "$PROJECT_ROOT/compose.yml" || -f "$PROJECT_ROOT/docker-compose.yml" || -f "$PROJECT_ROOT/docker-compose.yaml" ]] && HAS_DOCKER=true
  [[ -f "$PROJECT_ROOT/pyproject.toml" || -f "$PROJECT_ROOT/requirements.txt" ]] && HAS_PYTHON=true
  if $HAS_PYTHON; then
    grep -qiE "fastapi|starlette" "$PROJECT_ROOT/requirements.txt" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null && HAS_FASTAPI=true
    grep -qiE "celery" "$PROJECT_ROOT/requirements.txt" "$PROJECT_ROOT/pyproject.toml" 2>/dev/null && HAS_CELERY=true
    [[ -f "$PROJECT_ROOT/backend/app/tasks.py" || -f "$PROJECT_ROOT/app/tasks.py" ]] && HAS_CELERY=true
  fi
  [[ -f "$PROJECT_ROOT/package.json" ]] && HAS_FRONTEND=true
  [[ -f "$PROJECT_ROOT/tsconfig.json" ]] && HAS_TYPESCRIPT=true
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ⬡  Helix — Checklist Pre-Cierre de Tarea              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
if [[ -n "$PROJECT_ROOT" ]]; then
  echo -e "  Proyecto: $PROJECT_ROOT"
  STACK_TAGS=""
  $HAS_FASTAPI  && STACK_TAGS="${STACK_TAGS} FastAPI"
  $HAS_DOCKER   && STACK_TAGS="${STACK_TAGS} Docker"
  $HAS_CELERY   && STACK_TAGS="${STACK_TAGS} Celery"
  $HAS_FRONTEND && STACK_TAGS="${STACK_TAGS} Frontend"
  $HAS_TYPESCRIPT && STACK_TAGS="${STACK_TAGS} TS"
  echo -e "  Stack detectado:${STACK_TAGS:-  (genérico)}"
else
  echo -e "  Sin proyecto detectado"
fi

# ════════════════════════════════════════════════════════════
section "BACKEND"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  GIT_DIFF=$(git -C "$PROJECT_ROOT" diff HEAD 2>/dev/null || true)

  if $HAS_DOCKER && $HAS_FASTAPI; then
    COMPOSE_FILE="$PROJECT_ROOT/compose.yml"
    [[ ! -f "$COMPOSE_FILE" ]] && COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

    if docker compose -f "$COMPOSE_FILE" ps backend 2>/dev/null | grep -q "Up"; then
      check "Backend container corriendo"
      RECENT_ERRORS=$(docker compose -f "$COMPOSE_FILE" logs backend --since 5m 2>/dev/null \
        | grep -ciE "error|exception|traceback" || true)
      RECENT_ERRORS="${RECENT_ERRORS//[[:space:]]/}"; RECENT_ERRORS="${RECENT_ERRORS:-0}"
      [[ "$RECENT_ERRORS" -eq 0 ]] && check "Sin errores en logs recientes" || fail "$RECENT_ERRORS errores en logs recientes"
    else
      warn "Backend container no detectado corriendo"
    fi
  elif $HAS_PYTHON; then
    skip "Checks Docker (sin Docker en este proyecto)"
  else
    skip "Checks de backend (proyecto sin Python)"
  fi

  if $HAS_FASTAPI; then
    if echo "$CHANGED" | grep -q "models.py"; then
      echo "$CHANGED" | grep -q "schemas.py" && check "models.py y schemas.py modificados juntos" || warn "models.py modificado — ¿actualizaste schemas.py?"
    fi
    if echo "$GIT_DIFF" | grep -q "relationship\|joinedload" && ! echo "$GIT_DIFF" | grep -q "selectinload"; then
      warn "Relación sin selectinload() — posible N+1 query"
    fi
    if echo "$GIT_DIFF" | grep -qE "@router\.(put|post|delete|patch)" && ! echo "$GIT_DIFF" | grep -q "AuditLog"; then
      warn "Endpoint mutante sin AuditLog"
    fi
  fi
else
  skip "Checks de backend (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "FRONTEND"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]] && $HAS_FRONTEND; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  GIT_DIFF_TS=$(git -C "$PROJECT_ROOT" diff HEAD -- "*.ts" "*.tsx" "*.js" 2>/dev/null || true)

  if $HAS_FASTAPI; then
    if echo "$CHANGED" | grep -q "schemas.py"; then
      echo "$CHANGED" | grep -q "types.ts" && check "schemas.py y types.ts sincronizados" || warn "schemas.py modificado — ¿sincronizaste types.ts?"
    fi
    if echo "$CHANGED" | grep -qE "routers/"; then
      echo "$CHANGED" | grep -q "api/index.ts" && check "Endpoint registrado en api/index.ts" || warn "Router modificado — ¿actualizaste api/index.ts?"
    fi
  fi

  DIRECT_FETCH=$(echo "$GIT_DIFF_TS" | grep "^+" | grep -vE "^\+\+\+" | grep -E "fetch\(|axios\." | grep -v "api/index.ts" || true)
  [[ -n "$DIRECT_FETCH" ]] && fail "fetch/axios directo en TS — usar api/index.ts" || true

  if $HAS_TYPESCRIPT; then
    if echo "$GIT_DIFF_TS" | grep -q "user\.area === 'admin'"; then
      fail "CRITICO: user.area === 'admin' — debe ser user.rol === 'admin'"
    else
      check "Detección de admin correcta"
    fi
  fi
elif [[ -n "$PROJECT_ROOT" ]]; then
  skip "Checks de frontend (sin package.json en este proyecto)"
else
  skip "Checks de frontend (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "SEGURIDAD"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  GIT_DIFF=$(git -C "$PROJECT_ROOT" diff HEAD 2>/dev/null || true)
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)

  if echo "$GIT_DIFF" | grep -qiE "password\s*=\s*['\"][^'\"]{3,}|secret\s*=\s*['\"]|api_key\s*=\s*['\"]"; then
    fail "Posible credencial hardcodeada"
  else
    check "Sin credenciales hardcodeadas"
  fi

  echo "$CHANGED" | grep -q "^\.env$" && fail ".env en los cambios — NO commitear" || true

  if $HAS_FASTAPI; then
    grep -q "login/test" "$PROJECT_ROOT/backend/app/routers/auth.py" 2>/dev/null && warn "Endpoint /login/test activo — remover en producción" || true
    if echo "$CHANGED" | grep -q "config.py" && ! echo "$CHANGED" | grep -q ".env.example"; then
      warn "config.py modificado — ¿actualizaste .env.example?"
    fi
  fi
else
  skip "Checks de seguridad (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "DOCKER / OPERATIVIDAD"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]] && $HAS_DOCKER; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  COMPOSE_FILE="$PROJECT_ROOT/compose.yml"
  [[ ! -f "$COMPOSE_FILE" ]] && COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

  if $HAS_CELERY && echo "$CHANGED" | grep -q "tasks.py"; then
    docker compose -f "$COMPOSE_FILE" ps celery_worker 2>/dev/null | grep -q "Up" && check "Celery worker corriendo" || warn "tasks.py modificado — celery_worker no detectado"
  fi
elif [[ -n "$PROJECT_ROOT" ]]; then
  skip "Checks de Docker (sin Docker en este proyecto)"
else
  skip "Checks de Docker (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "DEFINITION OF DONE (helix-team.md)"
# ════════════════════════════════════════════════════════════

TEAM_FILE="${PROJECT_ROOT:+$PROJECT_ROOT/.claude/memory/helix-team.md}"
if [[ -n "${TEAM_FILE:-}" && -f "$TEAM_FILE" ]]; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  GIT_DIFF_CODE=$(git -C "$PROJECT_ROOT" diff HEAD -- "*.ts" "*.tsx" "*.js" "*.py" 2>/dev/null || true)

  if echo "$CHANGED" | grep -qE "\.(test|spec)\.(ts|tsx|py|js)$"; then
    check "Tests modificados para el cambio"
  elif [[ -n "$CHANGED" ]]; then
    warn "DoD: sin tests para este cambio"
  fi

  echo "$GIT_DIFF_CODE" | grep -qiE "password\s*=\s*['\"][^'\"]{3,}|secret\s*=\s*['\"]|api_key\s*=\s*['\"]" \
    && fail "DoD: credencial hardcodeada" || check "DoD: sin secrets hardcodeados"

  if echo "$CHANGED" | grep -qE "\.(tsx|jsx|css|html)$"; then
    warn "DoD: UI modificada — verificar con puppeteer en 375px, 768px, 1280px"
  fi

  BITACORA="$PROJECT_ROOT/.claude/memory/helix-bitacora.md"
  if [[ -f "$BITACORA" ]]; then
    BITACORA_AGE=$(python3 -c "import os,time; print('ok' if (time.time()-os.path.getmtime('$BITACORA'))/3600 < 2 else 'stale')" 2>/dev/null || echo "unknown")
    [[ "$BITACORA_AGE" == "ok" ]] && check "DoD: bitácora actualizada" || warn "DoD: bitácora no actualizada en las últimas 2h"
  fi

  warn "DoD (manual): ¿code-reviewer aprobó antes de cerrar?"
else
  skip "DoD check (sin helix-team.md)"
fi

# ════════════════════════════════════════════════════════════
section "PLANES COMPLETADOS"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  PLANS_DIR="$PROJECT_ROOT/.claude/memory"
  BACKLOG="$PROJECT_ROOT/.claude/memory/helix-backlog.md"

  if [[ -f "$BACKLOG" ]]; then
    # Detectar IDs en "Completado" del backlog
    COMPLETED_IDS=$(python3 -c "
from pathlib import Path
content = Path('$BACKLOG').read_text()
lines = content.splitlines()
in_done = False
ids = []
for line in lines:
    if '🟢 Completado' in line: in_done = True
    elif line.startswith('## '): in_done = False
    elif in_done and line.strip().startswith('|') and 'REQ-' in line:
        cols = [c.strip() for c in line.split('|') if c.strip()]
        if cols and cols[0].startswith('REQ-'): ids.append(cols[0])
print('\n'.join(ids))
" 2>/dev/null || true)

    if [[ -n "$COMPLETED_IDS" ]]; then
      PURGED=0
      while IFS= read -r req_id; do
        PLAN_FILE="$PLANS_DIR/helix-plan-${req_id}.md"
        if [[ -f "$PLAN_FILE" ]]; then
          rm "$PLAN_FILE"
          echo -e "  ${GREEN}🗑️  ${NC}Plan eliminado: helix-plan-${req_id}.md (req completado)"
          PURGED=$((PURGED + 1))
        fi
      done <<< "$COMPLETED_IDS"
      [[ "$PURGED" -eq 0 ]] && skip "Sin planes de reqs completados para eliminar"
    else
      skip "Sin reqs completados en el backlog aún"
    fi
  else
    skip "Planes (sin backlog en este proyecto)"
  fi
fi

# ════════════════════════════════════════════════════════════
section "EVOLUCION Y MEMORIA"
# ════════════════════════════════════════════════════════════

TODAY_LEARNS=$(grep -c "$(date '+%Y-%m-%d')" "$GLOBAL_MEMORY_DIR/evolution-log.txt" 2>/dev/null || true)
TODAY_LEARNS="${TODAY_LEARNS//[[:space:]]/}"; TODAY_LEARNS="${TODAY_LEARNS:-0}"
[[ "$TODAY_LEARNS" -gt 0 ]] && check "$TODAY_LEARNS aprendizaje(s) registrados hoy" || warn "Sin aprendizajes hoy — ¿hubo algo nuevo?"

SKILL_COUNT=$(find "$GLOBAL_SKILLS_DIR" -name "SKILL.md" 2>/dev/null | wc -l | tr -d '[:space:]')
check "${SKILL_COUNT:-0} skill(s) disponibles"

LINES=$(wc -l < "$HOME/.claude/CLAUDE.md" | tr -d '[:space:]')
if [[ "$LINES" -gt 450 ]]; then
  fail "CLAUDE.md en $LINES líneas — revisar secciones archivables"
elif [[ "$LINES" -gt 350 ]]; then
  warn "CLAUDE.md en $LINES líneas — considerar archivar evoluciones antiguas"
else
  check "CLAUDE.md en $LINES líneas"
fi

# ════════════════════════════════════════════════════════════
section "PERFORMANCE (recordatorios)"
# ════════════════════════════════════════════════════════════
warn "¿Reads/Greps independientes se ejecutaron en paralelo? (manual)"
warn "¿Tareas triviales autoaplicaron modo economía? (manual)"

# ════════════════════════════════════════════════════════════
# RESULTADO FINAL
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "  ✅ OK: $PASS   ⚠️  Advertencias: $WARN   ❌ Fallos: $FAIL"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}❌ PROBLEMAS CRÍTICOS — resolver antes de cerrar${NC}"; exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Hay advertencias — revisar antes de cerrar${NC}"; exit 0
else
  echo -e "${GREEN}✅ Todo en orden — tarea lista para cerrar${NC}"; exit 0
fi

#!/usr/bin/env bash
# .claude/self-check.sh — Checklist pre-cierre de tarea de Helix
set -euo pipefail

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

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ⬡  Helix — Checklist Pre-Cierre de Tarea              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
[[ -n "$PROJECT_ROOT" ]] && echo -e "  Proyecto: $PROJECT_ROOT" || echo -e "  Sin proyecto detectado"

# ════════════════════════════════════════════════════════════
section "BACKEND"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  # ¿Docker backend corriendo?
  if docker compose -f "$PROJECT_ROOT/compose.yml" ps backend 2>/dev/null | grep -q "Up"; then
    check "Backend container corriendo"
  else
    warn "Backend no detectado corriendo"
  fi

  # ¿Errores en logs recientes? — trim para evitar "0\n0" de wc -l
  RECENT_ERRORS=$(docker compose -f "$PROJECT_ROOT/compose.yml" logs backend --since 5m 2>/dev/null \
    | grep -ciE "error|exception|traceback" || true)
  RECENT_ERRORS="${RECENT_ERRORS//[[:space:]]/}"
  RECENT_ERRORS="${RECENT_ERRORS:-0}"
  if [[ "$RECENT_ERRORS" -eq 0 ]]; then
    check "Sin errores en logs recientes del backend"
  else
    fail "$RECENT_ERRORS líneas de error en logs recientes"
  fi

  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  GIT_DIFF=$(git -C "$PROJECT_ROOT" diff HEAD 2>/dev/null || true)

  if echo "$CHANGED" | grep -q "models.py"; then
    if echo "$CHANGED" | grep -q "schemas.py"; then
      check "models.py y schemas.py modificados en conjunto"
    else
      warn "models.py modificado — ¿actualizaste schemas.py?"
    fi
  fi

  if echo "$GIT_DIFF" | grep -q "relationship\|joinedload" && \
     ! echo "$GIT_DIFF" | grep -q "selectinload"; then
    warn "Relación sin selectinload() — posible N+1 query"
  fi

  if echo "$GIT_DIFF" | grep -qE "@router\.(put|post|delete|patch)" && \
     ! echo "$GIT_DIFF" | grep -q "AuditLog"; then
    warn "Endpoint mutante sin AuditLog"
  fi
else
  skip "Checks de backend (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "FRONTEND"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  # Solo diff de archivos TS/TSX/JS para evitar falsos positivos con CLAUDE.md
  GIT_DIFF_TS=$(git -C "$PROJECT_ROOT" diff HEAD -- "*.ts" "*.tsx" "*.js" 2>/dev/null || true)

  if echo "$CHANGED" | grep -q "schemas.py"; then
    if echo "$CHANGED" | grep -q "types.ts"; then
      check "schemas.py y types.ts sincronizados"
    else
      warn "schemas.py modificado — ¿sincronizaste types.ts?"
    fi
  fi

  if echo "$CHANGED" | grep -qE "routers/"; then
    if echo "$CHANGED" | grep -q "api/index.ts"; then
      check "Endpoint registrado en api/index.ts"
    else
      warn "Router modificado — ¿actualizaste api/index.ts?"
    fi
  fi

  # Solo buscar fetch directo en archivos TS/TSX (no en CLAUDE.md)
  DIRECT_FETCH=$(echo "$GIT_DIFF_TS" | grep "^+" | grep -vE "^\+\+\+" \
    | grep -E "fetch\(|axios\." | grep -v "api/index.ts" || true)
  if [[ -n "$DIRECT_FETCH" ]]; then
    fail "fetch/axios directo en TS — usar api/index.ts"
  fi

  # Detección de admin incorrecta — solo en archivos TS/TSX
  if echo "$GIT_DIFF_TS" | grep -q "user\.area === 'admin'"; then
    fail "CRITICO: user.area === 'admin' en TS — debe ser user.rol === 'admin'"
  else
    check "Detección de admin correcta en frontend"
  fi
else
  skip "Checks de frontend (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "SEGURIDAD"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  GIT_DIFF=$(git -C "$PROJECT_ROOT" diff HEAD 2>/dev/null || true)
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)

  if echo "$GIT_DIFF" | grep -qiE "password\s*=\s*['\"][^'\"]{3,}|secret\s*=\s*['\"]"; then
    fail "Posible credencial hardcodeada"
  else
    check "Sin credenciales hardcodeadas"
  fi

  if echo "$CHANGED" | grep -q "^\.env$"; then
    fail ".env en los cambios — NO commitear"
  fi

  if grep -q "login/test" "$PROJECT_ROOT/backend/app/routers/auth.py" 2>/dev/null; then
    warn "Endpoint /api/auth/login/test activo — remover en producción"
  fi

  if echo "$CHANGED" | grep -q "config.py" && ! echo "$CHANGED" | grep -q ".env.example"; then
    warn "config.py modificado — ¿actualizaste .env.example?"
  fi
else
  skip "Checks de seguridad (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "DOCKER / OPERATIVIDAD"
# ════════════════════════════════════════════════════════════

if [[ -n "$PROJECT_ROOT" ]]; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  if echo "$CHANGED" | grep -q "tasks.py"; then
    if docker compose -f "$PROJECT_ROOT/compose.yml" ps celery_worker 2>/dev/null | grep -q "Up"; then
      check "Celery worker corriendo"
    else
      warn "tasks.py modificado — celery_worker no detectado"
    fi
  fi
else
  skip "Checks de Docker (sin proyecto)"
fi

# ════════════════════════════════════════════════════════════
section "EVOLUCION Y MEMORIA"
# ════════════════════════════════════════════════════════════

TODAY_LEARNS=$(grep -c "$(date '+%Y-%m-%d')" "$GLOBAL_MEMORY_DIR/evolution-log.txt" 2>/dev/null || true)
TODAY_LEARNS="${TODAY_LEARNS//[[:space:]]/}"; TODAY_LEARNS="${TODAY_LEARNS:-0}"
if [[ "$TODAY_LEARNS" -gt 0 ]]; then
  check "$TODAY_LEARNS aprendizaje(s) registrados hoy"
else
  warn "Sin aprendizajes hoy — ¿hubo algo nuevo?"
fi

SKILL_COUNT=$(find "$GLOBAL_SKILLS_DIR" "$PROJECT_SKILLS_DIR" -name "*.md" 2>/dev/null \
  | sort -u | wc -l | tr -d '[:space:]')
check "${SKILL_COUNT:-0} skill(s) disponibles"

LINES=$(wc -l < "$HOME/.claude/CLAUDE.md" | tr -d '[:space:]')
if [[ "$LINES" -gt 220 ]]; then
  fail "CLAUDE.md en $LINES líneas — EJECUTAR: bash ~/.claude/compress.sh AHORA"
elif [[ "$LINES" -gt 180 ]]; then
  warn "CLAUDE.md en $LINES líneas — ejecutar compress.sh pronto"
else
  check "CLAUDE.md en $LINES líneas (dentro del límite)"
fi

# ════════════════════════════════════════════════════════════
section "DEFINITION OF DONE (helix-team.md)"
# ════════════════════════════════════════════════════════════

TEAM_FILE="${PROJECT_ROOT:+$PROJECT_ROOT/.claude/memory/helix-team.md}"
if [[ -n "$TEAM_FILE" && -f "$TEAM_FILE" ]]; then
  CHANGED=$(git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null || true)
  GIT_DIFF_TS=$(git -C "$PROJECT_ROOT" diff HEAD -- "*.ts" "*.tsx" "*.js" "*.py" 2>/dev/null || true)

  # ¿Tests escritos para el cambio?
  if echo "$CHANGED" | grep -qE "\.(test|spec)\.(ts|tsx|py|js)$"; then
    check "Tests modificados para el cambio"
  elif [[ -n "$CHANGED" ]]; then
    warn "Sin tests para este cambio — DoD: tests escritos y pasando"
  fi

  # ¿Secrets hardcodeados? (ya cubierto en SEGURIDAD — solo recordatorio)
  if echo "$GIT_DIFF_TS" | grep -qiE "password\s*=\s*['\"][^'\"]{3,}|secret\s*=\s*['\"]|api_key\s*=\s*['\"]"; then
    fail "DoD: credencial hardcodeada detectada"
  else
    check "DoD: sin secrets hardcodeados"
  fi

  # ¿UI modificada? → recordar puppeteer
  if echo "$CHANGED" | grep -qE "\.(tsx|jsx|css|html)$"; then
    warn "DoD: UI modificada — verificar con puppeteer en 375px, 768px, 1280px"
  fi

  # ¿Bitácora actualizada? (modificada en las últimas 2 horas)
  BITACORA="$PROJECT_ROOT/.claude/memory/helix-bitacora.md"
  if [[ -f "$BITACORA" ]]; then
    BITACORA_AGE=$(python3 -c "
import os, time
age = (time.time() - os.path.getmtime('$BITACORA')) / 3600
print('ok' if age < 2 else 'stale')
" 2>/dev/null || echo "unknown")
    if [[ "$BITACORA_AGE" == "ok" ]]; then
      check "DoD: bitácora actualizada recientemente"
    else
      warn "DoD: bitácora no actualizada hoy — agregar entrada"
    fi
  fi

  # Recordatorio no automatizable
  warn "DoD (manual): ¿code-reviewer aprobó antes de cerrar?"

else
  skip "DoD check (sin helix-team.md en el proyecto)"
fi

# ════════════════════════════════════════════════════════════
# RESULTADO FINAL
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "  ✅ OK: $PASS   ⚠️  Advertencias: $WARN   ❌ Fallos: $FAIL"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}❌ PROBLEMAS CRÍTICOS — resolver antes de cerrar${NC}"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Hay advertencias — revisar antes de cerrar${NC}"
  exit 0
else
  echo -e "${GREEN}✅ Todo en orden — tarea lista para cerrar${NC}"
  exit 0
fi

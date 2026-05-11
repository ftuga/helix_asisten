#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# .claude/health-check.sh — Diagnóstico de integridad del ecosistema Helix
# Verifica scripts, archivos, markers y estructura de memoria
# Uso: bash ~/.claude/health-check.sh
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
OK=0; WARN=0; FAIL=0

ok()      { echo -e "  ${GREEN}✅${NC} $1"; OK=$((OK + 1)); }
warn()    { echo -e "  ${YELLOW}⚠️ ${NC} $1"; WARN=$((WARN + 1)); }
fail()    { echo -e "  ${RED}❌${NC} $1"; FAIL=$((FAIL + 1)); }
section() { echo -e "\n${BLUE}▶ $1${NC}"; }

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
GLOBAL_MD="$CLAUDE_HOME/CLAUDE.md"
MEMORY_DIR="$CLAUDE_HOME/memory"
SKILLS_DIR="$CLAUDE_HOME/skills"
TOPICS_DIR="$MEMORY_DIR/topics"

# Auto-detección de proyecto
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" && "$dir" != "$CLAUDE_HOME" ]] && echo "$dir" && return 0
    dir="$(dirname "$dir")"
  done
  return 1
}
PROJECT_ROOT=""
PROJECT_MD=""
if PROJECT_ROOT=$(find_project_root 2>/dev/null); then
  PROJECT_MD="$PROJECT_ROOT/CLAUDE.md"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ⬡  Helix — Diagnóstico de Salud del Ecosistema        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
[[ -n "$PROJECT_ROOT" ]] && echo -e "  Proyecto: $PROJECT_ROOT" || echo -e "  Sin proyecto detectado"

# ════════════════════════════════════════════════════════════
section "SCRIPTS DEL ECOSISTEMA"
# ════════════════════════════════════════════════════════════

for script in session-start.sh session-end.sh evolve.sh self-check.sh compress.sh health-check.sh; do
  path="$CLAUDE_HOME/$script"
  if [[ ! -f "$path" ]]; then
    fail "$script — no encontrado"
  elif [[ ! -x "$path" ]]; then
    warn "$script — existe pero sin permisos de ejecución"
    chmod +x "$path" && ok "$script — permisos corregidos automáticamente"
  else
    ok "$script"
  fi
done

# compress_logic.py
if [[ -f "$CLAUDE_HOME/compress_logic.py" ]]; then
  ok "compress_logic.py"
else
  fail "compress_logic.py — no encontrado (compress.sh no funcionará)"
fi

# ════════════════════════════════════════════════════════════
section "ARCHIVOS DE MEMORIA"
# ════════════════════════════════════════════════════════════

for f in "$GLOBAL_MD" "$MEMORY_DIR/evolution-log.txt" "$MEMORY_DIR/session-log.txt"; do
  if [[ -f "$f" ]]; then
    ok "$(basename $f)"
  else
    warn "$(basename $f) — no encontrado (se creará en próxima sesión)"
  fi
done

# Topics dir
if [[ -d "$TOPICS_DIR" ]]; then
  TOPIC_COUNT=$(find "$TOPICS_DIR" -name "*.md" | wc -l | tr -d '[:space:]')
  ok "topics/ — $TOPIC_COUNT archivos"
else
  warn "topics/ — directorio no existe aún"
fi

# obsolete.md (opcional)
[[ -f "$MEMORY_DIR/obsolete.md" ]] && ok "obsolete.md" || ok "obsolete.md — no existe aún (normal)"

# project.md del proyecto
if [[ -n "$PROJECT_ROOT" ]]; then
  PROJ_DOC="$PROJECT_ROOT/.claude/memory/project.md"
  if [[ -f "$PROJ_DOC" ]]; then
    ok "project.md del proyecto"
  else
    warn "project.md no encontrado — documentación estática no migrada"
  fi
fi

# ════════════════════════════════════════════════════════════
section "INTEGRIDAD DE CLAUDE.md GLOBAL"
# ════════════════════════════════════════════════════════════

"${HELIX_PYTHON:-python3}" - "$GLOBAL_MD" << 'PYEOF'
import sys, re

file = sys.argv[1]
ok_count = 0; warn_count = 0; fail_count = 0

def chk(cond, msg_ok, msg_fail, is_warn=False):
    global ok_count, warn_count, fail_count
    if cond:
        print(f"  \033[0;32m✅\033[0m {msg_ok}")
        ok_count += 1
    elif is_warn:
        print(f"  \033[1;33m⚠️ \033[0m {msg_fail}")
        warn_count += 1
    else:
        print(f"  \033[0;31m❌\033[0m {msg_fail}")
        fail_count += 1

with open(file) as f:
    content = f.read()

# Markers obligatorios
required_markers = [
    "METRICS_START", "METRICS_END",
    "RISK_MAP_START", "RISK_MAP_END",
    "REASONING_START", "REASONING_END",
    "SKILLS_INDEX_START", "SKILLS_INDEX_END",
    "SESSIONS_START", "SESSIONS_END",
    "EVOLUTION_LOG_START", "EVOLUTION_LOG_END",
    "OPERABILITY_START", "OPERABILITY_END",
    "SECURITY_START", "SECURITY_END",
    "LAST_EVOLUTION",
]
missing = [m for m in required_markers if f"<!-- {m} -->" not in content]
chk(not missing, f"Todos los markers presentes ({len(required_markers)})",
    f"Markers faltantes: {', '.join(missing)}")

# JSON de métricas válido
import json
m = re.search(r'<!-- METRICS_START -->\n```json\n(.*?)\n```\n<!-- METRICS_END -->', content, re.DOTALL)
if m:
    try:
        json.loads(m.group(1))
        chk(True, "Métricas JSON válido", "")
    except:
        chk(False, "", "Métricas JSON inválido — corrupción detectada")
else:
    chk(False, "", "Bloque de métricas no encontrado")

# Tamaño
lines = content.count('\n')
chk(lines <= 350, f"Tamaño: {lines} líneas (dentro de rango)",
    f"Tamaño: {lines} líneas — ejecutar compress.sh", is_warn=True)

# Sin secciones estáticas de proyecto
has_static = "## Project Overview" in content or "## Stack" in content
chk(not has_static, "Sin documentación estática embebida",
    "Documentación estática aún en CLAUDE.md — ejecutar migración", is_warn=True)

print(f"\n  Resultado markers: {ok_count} ok, {warn_count} advertencias, {fail_count} fallos")

# Exit code para que bash lo capture
if fail_count > 0:
    sys.exit(1)
PYEOF

# ════════════════════════════════════════════════════════════
section "SKILLS"
# ════════════════════════════════════════════════════════════

TOTAL_SKILLS=$(find "$SKILLS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
ok "$TOTAL_SKILLS skills en directorio global"

if [[ -n "$PROJECT_ROOT" ]]; then
  PROJ_SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
  PROJ_SKILLS=$(find "$PROJ_SKILLS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]' || echo 0)
  ok "$PROJ_SKILLS skills en directorio del proyecto"
fi

# ════════════════════════════════════════════════════════════
section "PESO DE CONTEXTO (proxy de tokens)"
# ════════════════════════════════════════════════════════════

"${HELIX_PYTHON:-python3}" - "$GLOBAL_MD" "$MEMORY_DIR" << 'PYEOF'
import sys, os
from pathlib import Path

global_md   = Path(sys.argv[1])
memory_dir  = Path(sys.argv[2])
topics_dir  = memory_dir / "topics"

def kb(path):
    try: return os.path.getsize(path) / 1024
    except: return 0

def approx_tokens(path):
    """Aprox: 1 token ≈ 4 chars"""
    try:
        with open(path) as f: text = f.read()
        return len(text) // 4
    except: return 0

sizes = {
    "CLAUDE.md global (siempre cargado)": global_md,
    "evolution-log.txt":   memory_dir / "evolution-log.txt",
    "sessions.md":         memory_dir / "sessions.md",
}

total_tokens = 0
for label, path in sizes.items():
    t = approx_tokens(path)
    total_tokens += t
    status = "✅" if t < 2000 else ("⚠️ " if t < 5000 else "❌")
    print(f"  {status} {label}: ~{t:,} tokens ({kb(path):.1f} KB)")

# Topics (carga bajo demanda)
topic_tokens = 0
if topics_dir.exists():
    for f in topics_dir.glob("*.md"):
        topic_tokens += approx_tokens(f)

print(f"  📦 topics/ (bajo demanda): ~{topic_tokens:,} tokens")
print(f"\n  Total contexto activo:    ~{total_tokens:,} tokens")
print(f"  Total memoria completa:   ~{total_tokens + topic_tokens:,} tokens")

threshold = 8000
if total_tokens < threshold:
    print(f"  \033[0;32m✅ Contexto activo saludable (< {threshold:,} tokens)\033[0m")
elif total_tokens < threshold * 2:
    print(f"  \033[1;33m⚠️  Contexto elevado — considerar compresión\033[0m")
else:
    print(f"  \033[0;31m❌ Contexto crítico — comprimir urgente\033[0m")
PYEOF

# ════════════════════════════════════════════════════════════
# RESULTADO FINAL
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "  ✅ OK: $OK   ⚠️  Advertencias: $WARN   ❌ Fallos: $FAIL"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}❌ ECOSISTEMA CON PROBLEMAS CRÍTICOS${NC}"
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  echo -e "${YELLOW}⚠️  Ecosistema funcional con advertencias${NC}"
else
  echo -e "${GREEN}✅ Ecosistema Helix en perfecto estado${NC}"
fi

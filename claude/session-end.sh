#!/usr/bin/env bash
# .claude/session-end.sh — Cerrar sesión de Helix
# Registra resumen, pendientes y comprime memoria si es necesario
set -euo pipefail

GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
GLOBAL_MEMORY_DIR="$HOME/.claude/memory"
DATE=$(date '+%Y-%m-%d %H:%M')
SHORT_DATE=$(date '+%Y-%m-%d')
GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

mkdir -p "$GLOBAL_MEMORY_DIR"

RESUMEN="${1:-Sin resumen proporcionado}"
shift || true
PENDIENTES=("$@")

# ── Auto-detección de proyecto ────────────────────────────────
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/CLAUDE.md" && "$dir" != "$HOME/.claude" ]] && echo "$dir" && return 0
    dir="$(dirname "$dir")"
  done
  return 1
}

PROJECT_CLAUDE_MD=""
PROJECT_MEMORY_DIR=""
if PROJECT_ROOT=$(find_project_root 2>/dev/null); then
  PROJECT_CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
  PROJECT_MEMORY_DIR="$PROJECT_ROOT/.claude/memory"
  mkdir -p "$PROJECT_MEMORY_DIR"
fi

# ── Contar aprendizajes de esta sesión (desde global) ────────
SESSION_LEARNS=$(grep "$SHORT_DATE" "$GLOBAL_MEMORY_DIR/evolution-log.txt" 2>/dev/null | grep "\[LEARN\]" | wc -l || echo "0")
SESSION_SKILLS=$(grep "$SHORT_DATE" "$GLOBAL_MEMORY_DIR/evolution-log.txt" 2>/dev/null | grep "\[SKILL\]" | wc -l || echo "0")

# ── Número de sesión ──────────────────────────────────────────
SESSION_NUM=$(grep -c "SESIÓN INICIADA" "$GLOBAL_MEMORY_DIR/session-log.txt" 2>/dev/null || echo "1")

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   📝 Cerrando sesión #$SESSION_NUM — $DATE    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Registrar sesión en AMBOS CLAUDE.md ──────────────────────
SESSION_ROW="| #$SESSION_NUM | $SHORT_DATE | $RESUMEN | $SESSION_LEARNS | $SESSION_SKILLS |"

_register_session() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  PYINSERT_MARKER="<!-- SESSIONS_END -->" PYINSERT_CONTENT="$SESSION_ROW" python3 - "$file" << 'PYEOF'
import os, sys
file = sys.argv[1]
marker = os.environ['PYINSERT_MARKER']
content = os.environ['PYINSERT_CONTENT']
with open(file, 'r') as f:
    text = f.read()
if marker in text:
    text = text.replace(marker, content + '\n' + marker, 1)
    with open(file, 'w') as f:
        f.write(text)
PYEOF
}

_register_session "$GLOBAL_CLAUDE_MD"
if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
  _register_session "$PROJECT_CLAUDE_MD"
fi

# ── Actualizar métricas (solo global) ────────────────────────
python3 - "$GLOBAL_CLAUDE_MD" << 'PYEOF'
import re, json, sys
file = sys.argv[1]
with open(file, 'r') as f:
    content = f.read()
match = re.search(r'<!-- METRICS_START -->\n```json\n(.*?)\n```\n<!-- METRICS_END -->', content, re.DOTALL)
if match:
    metrics = json.loads(match.group(1))
    metrics['total_sesiones'] = metrics.get('total_sesiones', 0) + 1
    new_json = json.dumps(metrics, indent=2, ensure_ascii=False)
    new_block = f'<!-- METRICS_START -->\n```json\n{new_json}\n```\n<!-- METRICS_END -->'
    content = re.sub(r'<!-- METRICS_START -->.*?<!-- METRICS_END -->', new_block, content, flags=re.DOTALL)
    with open(file, 'w') as f:
        f.write(content)
PYEOF

# ── Guardar resumen en memoria ────────────────────────────────
cat >> "$GLOBAL_MEMORY_DIR/sessions.md" << SESSIONEOF

## Sesion #$SESSION_NUM — $DATE
**Resumen:** $RESUMEN
**Aprendizajes:** $SESSION_LEARNS | **Skills:** $SESSION_SKILLS
SESSIONEOF

# ── Guardar pendientes ────────────────────────────────────────
PENDING_FILE="${PROJECT_MEMORY_DIR:-$GLOBAL_MEMORY_DIR}/pending.md"
if [ ${#PENDIENTES[@]} -gt 0 ]; then
  {
    echo "# Pendientes sesion #$SESSION_NUM — $DATE"
    echo ""
    for item in "${PENDIENTES[@]}"; do
      echo "- [ ] $item"
    done
  } > "$PENDING_FILE"
  echo -e "${GREEN}Pendientes guardados: ${#PENDIENTES[@]} items${NC}"
else
  echo "" > "$PENDING_FILE"
fi

# ── Log de cierre ─────────────────────────────────────────────
echo "$DATE — SESION #$SESSION_NUM CERRADA — $RESUMEN" >> "$GLOBAL_MEMORY_DIR/session-log.txt"

echo -e "${GREEN}Sesion #$SESSION_NUM registrada.${NC}"
echo "   Resumen: $RESUMEN"
echo "   Aprendizajes: $SESSION_LEARNS | Skills: $SESSION_SKILLS"
echo ""

# ── Auto-compresion si CLAUDE.md supera 200 lineas ───────────
LINES=$(wc -l < "$GLOBAL_CLAUDE_MD")
if [[ "$LINES" -gt 200 ]]; then
  echo -e "\033[1;33mCLAUDE.md tiene $LINES lineas — comprimiendo memoria...\033[0m"
  bash "$HOME/.claude/compress.sh"
fi

# ── Evaluar salud de Helix — escribir alerta si hay problemas ─
ALERTA_FILE="${PROJECT_MEMORY_DIR:-$GLOBAL_MEMORY_DIR}/helix-alerta.md"
METRICS=$(bash "$HOME/.claude/helpers/helix-metricas.sh" "${PROJECT_ROOT:-}" 2>/dev/null || echo "")

if [[ -n "$METRICS" ]]; then
  TIENE_ALERTA=$(echo "$METRICS" | python3 -c "import sys,json; d=json.load(sys.stdin); print('si' if d.get('alerta') else 'no')" 2>/dev/null || echo "no")

  if [[ "$TIENE_ALERTA" == "si" ]]; then
    echo "$METRICS" | python3 - "$ALERTA_FILE" <<'PYEOF'
import sys, json
from pathlib import Path

data = json.load(sys.stdin)
out  = Path(sys.argv[1])
out.parent.mkdir(parents=True, exist_ok=True)

lines = [
    f"# Helix Alerta — {data['fecha']}",
    f"> Proyecto: {data['proyecto']}",
    f"> Generada al cerrar sesión. Helix la leerá al inicio de la próxima.",
    "",
    "## Problemas detectados",
]
i = 1
for dim, info in data['scores'].items():
    for p in info.get('problemas', []):
        lines.append(f"{i}. [{dim}] {p}")
        i += 1

lines += [
    "",
    "## Scores",
    f"| Dimensión | Score | Estado |",
    f"|-----------|-------|--------|",
]
for dim, info in data['scores'].items():
    estado = "✅" if info['ok'] else "❌"
    lines.append(f"| {dim} | {info['valor']}/100 | {estado} |")

lines += [
    "",
    "## Acción recomendada",
    "- Si contexto ❌ → `/helix-actualiza`",
    "- Si calidad ❌  → revisar errores en `helix-bitacora.md`",
    "- Si overhead ❌ → `/helix-actualiza` + evaluar agentes/skills activos",
]
out.write_text('\n'.join(lines) + '\n')
print(f"[HELIX] Alerta escrita → {out}")
PYEOF
    echo -e "\033[1;33m⚠️  Helix detectó problemas — te avisará al inicio de la próxima sesión.\033[0m"
  else
    # Todo bien — limpiar alerta anterior si existía
    [[ -f "$ALERTA_FILE" ]] && rm "$ALERTA_FILE" && echo -e "${GREEN}✅ Alerta anterior resuelta — eliminada.${NC}"
  fi
fi

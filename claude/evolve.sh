#!/usr/bin/env bash
# ============================================================
# .claude/evolve.sh — Orquestador de Auto-Evolución
# Uso:
#   bash .claude/evolve.sh learn "<categoría>" "<aprendizaje>" "<trigger>"
#   bash .claude/evolve.sh skill "<nombre>" "<descripción>" "<contenido-opcional>"
#   bash .claude/evolve.sh risk "<archivo>" "<zona>" "<nivel:ALTO|MEDIO|BAJO>" "<descripción>"
#   bash .claude/evolve.sh reasoning "<título>" "<decisión>" "<por-qué>" "<descartado>"
#   bash .claude/evolve.sh codemap "<archivo>" "<fragilidad>"
#
# Escribe en DOS archivos:
#   - CLAUDE.md del proyecto (aprendizajes específicos, auto-detectado)
#   - ~/.claude/CLAUDE.md   (aprendizajes globales cross-proyecto, métricas)
# ============================================================
set -euo pipefail

DATE=$(date '+%Y-%m-%d %H:%M')
SHORT_DATE=$(date '+%Y-%m-%d')

# ── Colores ──────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[EVOLVE]${NC} $1"; }
warn() { echo -e "${YELLOW}[EVOLVE]${NC} $1"; }
info() { echo -e "${BLUE}[EVOLVE]${NC} $1"; }
err()  { echo -e "${RED}[EVOLVE ERROR]${NC} $1"; }

# ── Rutas globales (siempre disponibles) ─────────────────────
GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
GLOBAL_MEMORY_DIR="$HOME/.claude/memory"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$GLOBAL_MEMORY_DIR" "$GLOBAL_SKILLS_DIR"

# ── Auto-detección de raíz del proyecto ──────────────────────
# Busca CLAUDE.md subiendo desde $PWD (como git busca .git)
find_project_root() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    # No contar el CLAUDE.md global como raíz de proyecto
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
  mkdir -p "$PROJECT_MEMORY_DIR" "$PROJECT_SKILLS_DIR"
  info "Proyecto detectado: $PROJECT_ROOT"
else
  warn "No se encontró CLAUDE.md de proyecto — solo se actualizará el global"
fi

# ── Helper: insertar línea antes de un marcador (por env vars) ──
# Uso: py_insert <file> <marker> <content>
# Usa variables de entorno para evitar problemas de escaping
py_insert() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  PYINSERT_MARKER="$2" PYINSERT_CONTENT="$3" python3 - "$file" <<'PYEOF'
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

# ── Helper: insertar en AMBOS CLAUDE.md ──────────────────────
py_insert_both() {
  local marker="$1"
  local content="$2"
  py_insert "$GLOBAL_CLAUDE_MD" "$marker" "$content"
  if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
    py_insert "$PROJECT_CLAUDE_MD" "$marker" "$content"
  fi
}

# ── Helper: actualizar fecha de última evolución ─────────────
update_last_evolution() {
  _update_last_in() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    PYDATE="$DATE" python3 - "$file" <<'PYEOF'
import os, re, sys
file = sys.argv[1]
date = os.environ['PYDATE']
with open(file, 'r') as f:
    content = f.read()
content = re.sub(
    r'<!-- LAST_EVOLUTION -->.*?<!-- /LAST_EVOLUTION -->',
    f'<!-- LAST_EVOLUTION -->{date}<!-- /LAST_EVOLUTION -->',
    content
)
with open(file, 'w') as f:
    f.write(content)
PYEOF
  }
  _update_last_in "$GLOBAL_CLAUDE_MD"
  if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
    _update_last_in "$PROJECT_CLAUDE_MD"
  fi
}

# ── Helper: incrementar métrica (solo en CLAUDE.md global) ───
increment_metric() {
  local categoria="$1"
  PYCAT="$categoria" python3 - "$GLOBAL_CLAUDE_MD" <<'PYEOF'
import os, re, json, sys
file = sys.argv[1]
cat = os.environ['PYCAT']
with open(file, 'r') as f:
    content = f.read()
match = re.search(r'<!-- METRICS_START -->\n```json\n(.*?)\n```\n<!-- METRICS_END -->', content, re.DOTALL)
if not match:
    print("No se encontró bloque de métricas en global")
    sys.exit(0)
metrics = json.loads(match.group(1))
metrics['total_aprendizajes'] = metrics.get('total_aprendizajes', 0) + 1
if cat in metrics.get('errores_por_categoria', {}):
    metrics['errores_por_categoria'][cat] += 1
new_json = json.dumps(metrics, indent=2, ensure_ascii=False)
new_block = f'<!-- METRICS_START -->\n```json\n{new_json}\n```\n<!-- METRICS_END -->'
content = re.sub(r'<!-- METRICS_START -->.*?<!-- METRICS_END -->', new_block, content, flags=re.DOTALL)
with open(file, 'w') as f:
    f.write(content)
print(f"Métrica '{cat}' incrementada en global")
PYEOF
}

# ════════════════════════════════════════════════════════════
# COMANDO: learn — Registrar aprendizaje
# ════════════════════════════════════════════════════════════
cmd_learn() {
  local categoria="${1:-funcionalidad}"
  local aprendizaje="${2:-}"
  local trigger="${3:-manual}"

  if [[ -z "$aprendizaje" ]]; then
    err "Uso: bash .claude/evolve.sh learn <categoría> <aprendizaje> <trigger>"
    exit 1
  fi

  # ── Evolve guard — rechazar aprendizajes con instrucciones ejecutables ──
  # Protege contra prompt injection que usa evolve.sh como vector persistente
  if GUARD_TEXT="$aprendizaje" python3 - <<'PYGUARD'
import os, re, sys
text = os.environ.get("GUARD_TEXT", "")
BAD = [
    (r"(?i)\bcurl\s+\S+\s*\|\s*(bash|sh|zsh|python)", "pipe-to-shell"),
    (r"(?i)\bwget\s+\S+\s*-O-?\s*\|\s*(bash|sh)", "wget-pipe"),
    (r"(?i)\b(rm|dd|mkfs|shutdown|reboot)\s+-", "destructive"),
    (r"(?i)\beval\s*\(\s*(atob|base64)", "eval-obfuscated"),
    (r"(?i)ignore\s+(all\s+)?previous\s+instructions", "jailbreak"),
    (r"(?i)you\s+are\s+now\s+(a|an)\s+\w+\s+(assistant|ai)", "role-reset"),
    (r"[\u200b-\u200f\u202a-\u202e\u2060-\u206f]", "zero-width"),
    (r"(?<![A-Za-z0-9+/=])[A-Za-z0-9+/]{200,}={0,2}(?![A-Za-z0-9+/=])", "long-b64"),
]
hits = []
for pat, tag in BAD:
    if re.search(pat, text):
        hits.append(tag)
if hits:
    print(f"🛡️  EVOLVE GUARD: rechazado — patrones peligrosos: {sorted(set(hits))}", file=sys.stderr)
    print(f"   Texto: {text[:140]}", file=sys.stderr)
    sys.exit(1)
PYGUARD
  then :; else
    err "Aprendizaje rechazado por evolve-guard (ver mensaje arriba)"
    exit 1
  fi

  # Mapeo categoría español → nombre de marcador en CLAUDE.md (inglés)
  local marker_name
  case "$categoria" in
    seguridad)    marker_name="SECURITY" ;;
    interfaz)     marker_name="UI" ;;
    funcionalidad) marker_name="FUNCTIONALITY" ;;
    operatividad) marker_name="OPERABILITY" ;;
    arquitectura) marker_name="ARCHITECTURE" ;;
    performance)  marker_name="PERFORMANCE" ;;
    testing)      marker_name="TESTING" ;;
    datos)        marker_name="DATA" ;;
    docker)       marker_name="DOCKER" ;;
    celery)       marker_name="CELERY" ;;
    auth)         marker_name="AUTH" ;;
    *)            marker_name=$(echo "$categoria" | tr '[:lower:]' '[:upper:]') ;;
  esac

  local new_entry="- [$SHORT_DATE] $aprendizaje"

  log "Registrando aprendizaje en categoría: $categoria (marcador: $marker_name)"

  # Insertar en sección de categoría (ambos CLAUDE.md)
  py_insert_both "<!-- ${marker_name}_END -->" "$new_entry"

  # Calcular número de entrada para el log de evoluciones
  local num
  num=$(grep -c "^| [0-9]" "$GLOBAL_CLAUDE_MD" 2>/dev/null || echo "1")
  local log_entry="| $num | $SHORT_DATE | $categoria | $aprendizaje | $trigger |"

  # Insertar en historial de evoluciones (ambos CLAUDE.md)
  py_insert_both "<!-- EVOLUTION_LOG_END -->" "$log_entry"

  # Incrementar métricas (solo global)
  increment_metric "$categoria" 2>/dev/null || true

  # Actualizar fecha (ambos)
  update_last_evolution

  # Persistir en memoria global
  echo "[$DATE] [LEARN] [$categoria] $aprendizaje (trigger: $trigger)" >> "$GLOBAL_MEMORY_DIR/evolution-log.txt"

  # ── Instalar como regla activa en active-rules.md ────────────
  ACTIVE_RULES_FILE="$GLOBAL_MEMORY_DIR/active-rules.md"
  PYLEARN="$aprendizaje" PYCAT="$categoria" PYDATE="$SHORT_DATE" python3 - "$ACTIVE_RULES_FILE" <<'PYEOF'
import os, sys
from pathlib import Path

rule_file = Path(sys.argv[1])
learn = os.environ['PYLEARN']
cat   = os.environ['PYCAT']
date  = os.environ['PYDATE']

if not rule_file.exists():
    rule_file.write_text("# Active Rules — Reglas activas instaladas de evoluciones\n\n")

content = rule_file.read_text()
new_rule = f"- [{date}] [{cat}] {learn}"

if new_rule not in content:
    lines = content.splitlines()
    insert_at = 2  # después de título y línea en blanco
    lines.insert(insert_at, new_rule)
    rule_file.write_text('\n'.join(lines) + '\n')
PYEOF

  log "✅ Aprendizaje registrado en ambos CLAUDE.md — sección $marker_name"
  log "✅ Regla instalada en active-rules.md"
}

# ════════════════════════════════════════════════════════════
# COMANDO: skill — Crear o actualizar una skill
# ════════════════════════════════════════════════════════════
cmd_skill() {
  local nombre="${1:-}"
  local descripcion="${2:-}"
  local contenido="${3:-}"

  if [[ -z "$nombre" ]] || [[ -z "$descripcion" ]]; then
    err "Uso: bash .claude/evolve.sh skill <nombre> <descripción> [contenido]"
    exit 1
  fi

  # Skills van al proyecto si existe, si no al global
  local skills_dir="${PROJECT_SKILLS_DIR:-$GLOBAL_SKILLS_DIR}"
  local skill_file="$skills_dir/${nombre}.md"
  local is_new=false

  if [[ ! -f "$skill_file" ]]; then
    is_new=true
    log "Creando nueva skill: $nombre"

    cat > "$skill_file" <<SKILLEOF
# Skill: $nombre
> Auto-generada por el agente el $DATE
> **Descripción:** $descripcion

## Cuándo usar esta skill
<!-- Completar con el agente -->

## Patrón / Solución

${contenido:-<!-- El agente completará esto -->}

## Ejemplos de uso
<!-- El agente agrega ejemplos reales del proyecto -->

## Dependencias
<!-- Skills relacionadas -->

## Historial de cambios
| Versión | Fecha | Cambio |
|---|---|---|
| v1.0 | $SHORT_DATE | Creación inicial |
SKILLEOF

    # Registrar en índice (ambos CLAUDE.md)
    local index_entry="| \`$nombre\` | $descripcion | - | v1.0 |"
    py_insert_both "<!-- SKILLS_INDEX_END -->" "$index_entry"

    # Incrementar métrica de skills (solo global)
    PYCAT="$nombre" python3 - "$GLOBAL_CLAUDE_MD" <<'PYEOF'
import os, re, json, sys
file = sys.argv[1]
with open(file, 'r') as f:
    content = f.read()
match = re.search(r'<!-- METRICS_START -->\n```json\n(.*?)\n```\n<!-- METRICS_END -->', content, re.DOTALL)
if match:
    metrics = json.loads(match.group(1))
    metrics['total_skills_creadas'] = metrics.get('total_skills_creadas', 0) + 1
    new_json = json.dumps(metrics, indent=2, ensure_ascii=False)
    new_block = f'<!-- METRICS_START -->\n```json\n{new_json}\n```\n<!-- METRICS_END -->'
    content = re.sub(r'<!-- METRICS_START -->.*?<!-- METRICS_END -->', new_block, content, flags=re.DOTALL)
    with open(file, 'w') as f:
        f.write(content)
PYEOF

  else
    log "Actualizando skill existente: $nombre"
    local version
    version=$(grep -c "^| v" "$skill_file" 2>/dev/null || echo "1")
    local new_version="v1.$version"
    {
      echo ""
      echo "### Actualización $new_version ($SHORT_DATE)"
      echo "$contenido"
    } >> "$skill_file"
  fi

  update_last_evolution
  echo "[$DATE] [SKILL] $nombre — $descripcion" >> "$GLOBAL_MEMORY_DIR/evolution-log.txt"

  if $is_new; then
    log "✅ Skill '$nombre' creada en $skill_file"
  else
    log "✅ Skill '$nombre' actualizada"
  fi
}

# ════════════════════════════════════════════════════════════
# COMANDO: risk — Registrar zona de riesgo
# ════════════════════════════════════════════════════════════
cmd_risk() {
  local archivo="${1:-}"
  local zona="${2:-}"
  local nivel="${3:-MEDIO}"
  local descripcion="${4:-}"

  if [[ -z "$archivo" ]] || [[ -z "$zona" ]] || [[ -z "$descripcion" ]]; then
    err "Uso: bash .claude/evolve.sh risk <archivo> <zona> <ALTO|MEDIO|BAJO> <descripción>"
    exit 1
  fi

  local emoji="🟡"
  case "$nivel" in
    ALTO)  emoji="🔴" ;;
    MEDIO) emoji="🟡" ;;
    BAJO)  emoji="🟢" ;;
  esac

  local risk_entry="| \`$archivo\` | \`$zona\` | $emoji $nivel | $descripcion | 1 |"
  py_insert_both "<!-- RISK_MAP_END -->" "$risk_entry"

  update_last_evolution
  echo "[$DATE] [RISK] $archivo::$zona [$nivel] $descripcion" >> "$GLOBAL_MEMORY_DIR/evolution-log.txt"
  log "✅ Zona de riesgo registrada: $archivo::$zona (en ambos CLAUDE.md)"
}

# ════════════════════════════════════════════════════════════
# COMANDO: reasoning — Registrar decisión de arquitectura
# ════════════════════════════════════════════════════════════
cmd_reasoning() {
  local titulo="${1:-}"
  local decision="${2:-}"
  local porque="${3:-}"
  local descartado="${4:-N/A}"

  if [[ -z "$titulo" ]] || [[ -z "$decision" ]]; then
    err "Uso: bash .claude/evolve.sh reasoning <título> <decisión> <por-qué> [descartado]"
    exit 1
  fi

  local reasoning_block="
### [$SHORT_DATE] $titulo
**Decisión:** $decision
**Por qué:** $porque
**Alternativa descartada:** $descartado"

  py_insert_both "<!-- REASONING_END -->" "$reasoning_block"

  update_last_evolution
  echo "[$DATE] [REASONING] $titulo" >> "$GLOBAL_MEMORY_DIR/evolution-log.txt"
  log "✅ Razonamiento registrado: $titulo (en ambos CLAUDE.md)"
}

# ════════════════════════════════════════════════════════════
# COMANDO: codemap — Actualizar estado de un archivo
# ════════════════════════════════════════════════════════════
cmd_codemap() {
  local archivo="${1:-}"
  local fragilidad="${2:-🟢 Baja}"

  if [[ -z "$archivo" ]]; then
    err "Uso: bash .claude/evolve.sh codemap <archivo> <fragilidad>"
    exit 1
  fi

  # codemap solo aplica al proyecto (es específico de cada codebase)
  if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
    PYARCHIVO="$archivo" PYFRAGILIDAD="$fragilidad" PYDATE="$SHORT_DATE" python3 - "$PROJECT_CLAUDE_MD" <<'PYEOF'
import os, re, sys
file = sys.argv[1]
archivo = os.environ['PYARCHIVO']
fragilidad = os.environ['PYFRAGILIDAD']
date = os.environ['PYDATE']
with open(file, 'r') as f:
    content = f.read()
# Reemplaza la fila del archivo en el code map si existe
pattern = rf'(\| `?{re.escape(archivo)}`? \|)[^\n]+'
replacement = f'| `{archivo}` | {fragilidad} | {date} |'
new_content = re.sub(pattern, replacement, content)
with open(file, 'w') as f:
    f.write(new_content)
PYEOF
    log "✅ Code map actualizado: $archivo"
  else
    warn "Sin proyecto detectado — codemap requiere CLAUDE.md de proyecto"
  fi
}

# ════════════════════════════════════════════════════════════
# COMANDO: forget — Marcar aprendizaje como obsoleto
# ════════════════════════════════════════════════════════════
cmd_forget() {
  local termino="${1:-}"
  local razon="${2:-obsoleto}"

  if [[ -z "$termino" ]]; then
    err "Uso: bash .claude/evolve.sh forget \"<término a olvidar>\" \"<razón>\""
    exit 1
  fi

  local obsolete_file="$GLOBAL_MEMORY_DIR/obsolete.md"
  local found=0

  log "Buscando '$termino' en memoria activa..."

  # Procesar cada archivo CLAUDE.md activo
  _forget_in_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0

    PYTERM="$termino" PYREASON="$razon" PYDATE="$DATE" PYOBSOLETE="$obsolete_file" \
    python3 - "$file" <<'PYEOF'
import os, re, sys

file      = sys.argv[1]
termino   = os.environ['PYTERM']
razon     = os.environ['PYREASON']
date      = os.environ['PYDATE']
obsolete  = os.environ['PYOBSOLETE']

with open(file, 'r') as f:
    lines = f.readlines()

kept = []
removed = []

for line in lines:
    # Buscar en líneas de aprendizaje (bullets con fecha o [INIT])
    if re.search(r'- \[(INIT|\d{4}-\d{2}-\d{2})\]', line) and termino.lower() in line.lower():
        removed.append(line.rstrip())
    else:
        kept.append(line)

if removed:
    # Archivar en obsolete.md con razón y fecha
    import pathlib
    pathlib.Path(obsolete).parent.mkdir(parents=True, exist_ok=True)
    with open(obsolete, 'a') as f:
        f.write(f"\n## Olvidado {date} — razón: {razon}\n")
        for r in removed:
            f.write(f"~~{r}~~ [OBSOLETO]\n")

    with open(file, 'w') as f:
        f.writelines(kept)

    print(f"  eliminadas {len(removed)} entrada(s) de {file}")
    sys.exit(0)
else:
    print(f"  sin coincidencias en {file}")
    sys.exit(2)
PYEOF
  }

  # Aplicar en global
  if _forget_in_file "$GLOBAL_CLAUDE_MD"; then
    found=$((found + 1))
  fi

  # Aplicar en proyecto
  if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
    if _forget_in_file "$PROJECT_CLAUDE_MD"; then
      found=$((found + 1))
    fi
  fi

  # Buscar y marcar en archivos de topics
  TOPICS_DIR="$GLOBAL_MEMORY_DIR/topics"
  if [[ -d "$TOPICS_DIR" ]]; then
    for topic_file in "$TOPICS_DIR"/*.md; do
      [[ -f "$topic_file" ]] || continue
      if _forget_in_file "$topic_file"; then
        found=$((found + 1))
      fi
    done
  fi

  if [[ "$found" -gt 0 ]]; then
    # Registrar el olvido en el log de evoluciones
    echo "[$DATE] [FORGET] '$termino' — $razon" >> "$GLOBAL_MEMORY_DIR/evolution-log.txt"
    update_last_evolution
    log "✅ '$termino' marcado como obsoleto en $found archivo(s) → archivado en obsolete.md"
  else
    warn "No se encontró '$termino' en memoria activa"
  fi
}

# ════════════════════════════════════════════════════════════
# COMANDO: validate — Marcar aprendizaje como confirmado en práctica
# ════════════════════════════════════════════════════════════
cmd_validate() {
  local termino="${1:-}"
  local contexto="${2:-confirmado en práctica}"

  if [[ -z "$termino" ]]; then
    err "Uso: bash .claude/evolve.sh validate \"<término>\" \"<contexto>\""
    exit 1
  fi

  log "Marcando '$termino' como [VALIDADO]..."

  _validate_in_file() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    PYTERM="$termino" PYCTX="$contexto" PYDATE="$SHORT_DATE" python3 - "$file" <<'PYEOF'
import os, re, sys

file    = sys.argv[1]
termino = os.environ['PYTERM']
ctx     = os.environ['PYCTX']
date    = os.environ['PYDATE']

with open(file) as f:
    content = f.read()

# Buscar línea con el término y agregar [VALIDADO] si no lo tiene
new_content = re.sub(
    rf'(- \[(INIT|\d{{4}}-\d{{2}}-\d{{2}})\][^\n]*{re.escape(termino)}[^\n]*)(?!\s*\[VALIDADO\])',
    rf'\1 [VALIDADO {date}]',
    content,
    flags=re.IGNORECASE
)

if new_content != content:
    with open(file, 'w') as f:
        f.write(new_content)
    print(f"  validado en {file}")
    sys.exit(0)
else:
    sys.exit(2)
PYEOF
  }

  local found=0
  if _validate_in_file "$GLOBAL_CLAUDE_MD"; then found=$((found + 1)); fi
  if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
    if _validate_in_file "$PROJECT_CLAUDE_MD"; then found=$((found + 1)); fi
  fi
  # También en topics
  for f in "$GLOBAL_MEMORY_DIR/topics"/*.md; do
    [[ -f "$f" ]] || continue
    if _validate_in_file "$f"; then found=$((found + 1)); fi
  done

  if [[ "$found" -gt 0 ]]; then
    echo "[$DATE] [VALIDATE] '$termino' — $contexto" >> "$GLOBAL_MEMORY_DIR/evolution-log.txt"
    log "✅ '$termino' marcado como [VALIDADO] en $found archivo(s)"
  else
    warn "No se encontró '$termino' sin validar en memoria activa"
  fi
}

# ════════════════════════════════════════════════════════════
# COMANDO: queue — Encolar aprendizaje para proceso automático (Stop hook)
# ════════════════════════════════════════════════════════════
cmd_queue() {
  local categoria="${1:-funcionalidad}"
  local aprendizaje="${2:-}"
  local trigger="${3:-auto-queue}"

  if [[ -z "$aprendizaje" ]]; then
    err "Uso: bash .claude/evolve.sh queue <categoría> <aprendizaje> [trigger]"
    exit 1
  fi

  local queue_file="$GLOBAL_MEMORY_DIR/evolve-queue.jsonl"
  mkdir -p "$GLOBAL_MEMORY_DIR"

  # Escribir entrada JSON en la cola
  PYCAT="$categoria" PYLEARN="$aprendizaje" PYTRIGGER="$trigger" python3 - "$queue_file" <<'PYEOF'
import os, json, sys
from pathlib import Path
entry = {
    "categoria": os.environ["PYCAT"],
    "aprendizaje": os.environ["PYLEARN"],
    "trigger": os.environ["PYTRIGGER"],
}
with open(sys.argv[1], "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
print(f"[QUEUE] Encolado → {entry['categoria']}: {entry['aprendizaje'][:60]}")
PYEOF
}

# ════════════════════════════════════════════════════════════
# DISPATCHER PRINCIPAL
# ════════════════════════════════════════════════════════════
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  learn)     cmd_learn "$@" ;;
  queue)     cmd_queue "$@" ;;
  forget)    cmd_forget "$@" ;;
  validate)  cmd_validate "$@" ;;
  skill)     cmd_skill "$@" ;;
  risk)      cmd_risk "$@" ;;
  reasoning) cmd_reasoning "$@" ;;
  codemap)   cmd_codemap "$@" ;;
  help|*)
    echo ""
    echo "  🧠 evolve.sh — Sistema de Auto-Evolución de Helix"
    echo ""
    echo "  Comandos:"
    echo "    learn     <categoría> <aprendizaje> <trigger>"
    echo "    queue     <categoría> <aprendizaje> [trigger]  ← encola, procesa al Stop hook"
    echo "    forget    <término> <razón>          ← olvidar lo obsoleto"
    echo "    skill     <nombre> <descripción> [contenido]"
    echo "    risk      <archivo> <zona> <ALTO|MEDIO|BAJO> <descripción>"
    echo "    reasoning <título> <decisión> <por-qué> [descartado]"
    echo "    codemap   <archivo> <fragilidad>
    validate  <término> <contexto>     ← confirmar aprendizaje en práctica"
    echo ""
    echo "  Escribe en:"
    echo "    ~/.claude/CLAUDE.md          (global — métricas, evoluciones)"
    echo "    <proyecto>/CLAUDE.md         (proyecto — auto-detectado desde \$PWD)"
    echo ""
    ;;
esac

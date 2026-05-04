#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-distill.sh — HELIX-COMPRESS: Compresión de contexto adaptativa
# Tres targets: CLAUDE.md por agente, archivos de proyecto, archivos de código.
#
# Uso:
#   run [--agent NOMBRE]              → slices de CLAUDE.md por agente
#   report                            → métricas de ahorro vs full
#   status                            → verifica si slices están actualizados
#   compress-project [DIR]            → comprime helix-*.md del proyecto
#   compress-file FILE [TASK]         → extrae secciones relevantes de un archivo
#   compress-bitacora FILE [--keep N] → condensa bitácora, preserva últimas N entradas
#   clean                             → elimina slices generados
set -uo pipefail

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
DISTILLED_DIR="$HOME/.claude/skills/_distilled"
DATA_FILE="$HOME/.claude/data/distill-meta.json"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
BOLD='\033[1m'; GRAY='\033[0;37m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

mkdir -p "$DISTILLED_DIR"

cmd="${1:-report}"
shift || true

_source_hash() { sha1sum "$CLAUDE_MD" | cut -c1-8; }

# ─── Mapa de secciones por agente (headers exactos de CLAUDE.md) ────────────
# Formato: header parcial que debe aparecer en la línea "## ..."
declare -A AGENT_SECTIONS=(
  ["python-pro"]="SEGURIDAD|COMMITS|BASH GOTCHAS|TESTING"
  ["frontend-developer"]="SEGURIDAD|COMMITS|DISEÑO UI|TESTING"
  ["typescript-pro"]="SEGURIDAD|COMMITS|TESTING"
  ["backend-architect"]="SEGURIDAD|COMMITS|BASH GOTCHAS|TESTING|DIÁLOGO"
  ["database-architect"]="SEGURIDAD|COMMITS|DATOS"
  ["sql-pro"]="SEGURIDAD|COMMITS|DATOS"
  ["error-detective"]="SEGURIDAD|COMMITS|BASH GOTCHAS|TESTING"
  ["test-engineer"]="SEGURIDAD|COMMITS|TESTING"
  ["devops-engineer"]="SEGURIDAD|COMMITS|BASH GOTCHAS"
  ["ui-designer"]="SEGURIDAD|COMMITS|DISEÑO UI"
  ["code-reviewer"]="SEGURIDAD|COMMITS|TESTING|CHECKLIST"
  ["architect-reviewer"]="SEGURIDAD|COMMITS|ORQUESTACIÓN"
  ["security-auditor"]="SEGURIDAD|COMMITS"
  ["monitoring-specialist"]="SEGURIDAD|COMMITS|BASH GOTCHAS"
  ["data-analyst"]="SEGURIDAD|COMMITS|DATOS"
  ["ORC"]="*"
)

# ─── Extractor por headers (match en línea ## solamente) ─────────────────────
_extract_by_headers() {
  local keywords="$1"
  local source="$2"

  [[ "$keywords" == "*" ]] && cat "$source" && return

  PYVAR_KW="$keywords" "${HELIX_PYTHON:-python3}" - "$source" <<'PYEOF'
import sys, re, os
from pathlib import Path

source = Path(sys.argv[1]).read_text()
# Strip HTML comment markers (<!-- ... -->) — internal update markers, not for agents
source = re.sub(r'<!--.*?-->', '', source)
keywords = [k.strip() for k in os.environ['PYVAR_KW'].split('|')]

# Split en bloques que empiezan con ## (nivel 2)
blocks = re.split(r'\n(?=## )', '\n' + source)
result = []

for block in blocks:
    lines = block.strip().split('\n')
    if not lines:
        continue
    header = lines[0] if lines[0].startswith('##') else ''
    header_upper = header.upper()
    # Match solo en el header, no en el body
    if any(kw.upper() in header_upper for kw in keywords):
        result.append(block.strip())

# Siempre incluir la primera sección (título + intro) si existe
intro = blocks[0] if blocks else ''
if intro and not any(intro.startswith(r) for r in result):
    result.insert(0, intro)

print('\n\n'.join(result))
PYEOF
}

# ─── Compresor lingüístico (prose sections dentro de markdown) ───────────────
_compress_linguistic() {
  PYVAR_TEXT="$1" "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import re, os

text = os.environ.get('PYVAR_TEXT', '')
lines = text.split('\n')
out = []

# Palabras de relleno a eliminar en prosa
FILLER = r'\b(just|basically|actually|simply|really|very|quite|essentially|literally|obviously|clearly|of course|certainly|please note that|it is important to|make sure to|you should|you can|note that)\b'
PHRASES = [
    (r'\bin order to\b', 'to'),
    (r'\bdue to the fact that\b', 'because'),
    (r'\bthe fact that\b', 'that'),
    (r'\bis able to\b', 'can'),
    (r'\bwill be able to\b', 'can'),
    (r'\bmake sure (to|that)\b', 'ensure'),
    (r'\bas a result of\b', 'due to'),
    (r'\bat this point in time\b', 'now'),
]

for line in lines:
    stripped = line.strip()

    # Preservar siempre: código, URLs, variables, headers, tablas, bullets con código
    if not stripped:
        out.append(line)
        continue
    if re.match(r'^(#{1,6} |```|>|\|)', stripped):
        out.append(line)
        continue
    if re.search(r'(`[^`]+`|https?://|\$\{|\.\w{2,6}$|\.sh|\.md|\.py|\.ts)', stripped):
        out.append(line)
        continue
    if re.match(r'^\s*[-*]\s*`', line):
        out.append(line)
        continue

    # En prosa: eliminar relleno
    compressed = re.sub(FILLER, '', stripped, flags=re.I)
    for pattern, replacement in PHRASES:
        compressed = re.sub(pattern, replacement, compressed, flags=re.I)
    compressed = re.sub(r'\s{2,}', ' ', compressed).strip()

    if compressed:
        indent = len(line) - len(line.lstrip())
        out.append(' ' * indent + compressed)

print('\n'.join(out))
PYEOF
}

# ─── Generar slice para un agente ────────────────────────────────────────────
_generate_slice() {
  local agent="$1"
  local keywords="${AGENT_SECTIONS[$agent]:-$UNIVERSAL_SECTIONS}"
  local out_file="$DISTILLED_DIR/${agent}.md"
  local source_hash
  source_hash=$(_source_hash)
  local full_tokens=$(( $(wc -c < "$CLAUDE_MD") / 4 ))

  # Extraer secciones relevantes
  local content
  content=$(_extract_by_headers "$keywords" "$CLAUDE_MD")
  local extracted_chars=${#content}

  # Comprimir lingüísticamente
  local compressed
  compressed=$(_compress_linguistic "$content")
  local compressed_chars=${#compressed}
  local compressed_tokens=$(( compressed_chars / 4 ))

  local pct=0
  [[ $full_tokens -gt 0 ]] && pct=$(( (full_tokens - compressed_tokens) * 100 / full_tokens ))

  {
    echo "---"
    echo "name: distilled-context-${agent}"
    echo "description: Contexto Helix comprimido para ${agent}. Auto-generado — no editar manualmente."
    echo "source_hash: ${source_hash}"
    echo "generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "original_tokens: ~${full_tokens}"
    echo "compressed_tokens: ~${compressed_tokens}"
    echo "savings_pct: ${pct}%"
    echo "---"
    echo ""
    echo "# Contexto Helix — ${agent}"
    echo "> Secciones relevantes para este agente. Generado por helix-distill."
    echo ""
    echo "$compressed"
  } > "$out_file"

  echo -e "  ${GREEN}✓${NC} ${agent} — ~${full_tokens} → ~${compressed_tokens} tok (${BOLD}${pct}%${NC} ahorro)" >&2
  echo "${agent}|${full_tokens}|${compressed_tokens}|${pct}"
}

# ═══════════════════════════════════════════════════════════════════
# COMANDO: run
# ═══════════════════════════════════════════════════════════════════
if [[ "$cmd" == "run" ]]; then
  specific="${1:-}"
  specific="${specific#--agent=}"
  specific="${specific#--agent }"

  source_hash=$(_source_hash)
  echo -e "\n${BOLD}[HELIX-DISTILL]${NC} CLAUDE.md hash: ${source_hash}\n"

  results=()
  if [[ -n "$specific" ]] && [[ -v "AGENT_SECTIONS[$specific]" ]]; then
    results+=( "$(_generate_slice "$specific")" )
  else
    for agent in "${!AGENT_SECTIONS[@]}"; do
      [[ "$agent" == "ORC" ]] && continue
      results+=( "$(_generate_slice "$agent")" )
    done
  fi

  # Guardar metadata (PYVAR evita conflicto pipe vs heredoc stdin)
  PYVAR_RESULTS=$(printf '%s\n' "${results[@]}") "${HELIX_PYTHON:-python3}" - "$DATA_FILE" <<'PYEOF'
import json, sys, os
from datetime import datetime, timezone
from pathlib import Path

lines = [l for l in os.environ.get('PYVAR_RESULTS','').strip().split('\n') if '|' in l]
agents = {}
for line in lines:
    parts = line.split('|')
    if len(parts) == 4:
        name, orig, comp, pct = parts
        agents[name] = {'original_tokens': int(orig), 'compressed_tokens': int(comp), 'savings_pct': int(pct)}

total_orig = sum(v['original_tokens'] for v in agents.values())
total_comp = sum(v['compressed_tokens'] for v in agents.values())
Path(sys.argv[1]).write_text(json.dumps({
    'generated': datetime.now(timezone.utc).isoformat(),
    'agents': agents,
    'total': {'original': total_orig, 'compressed': total_comp, 'saved': total_orig - total_comp}
}, indent=2))
PYEOF

  echo -e "\n${GREEN}✓ Distilación completa.${NC} Slices en: ${DISTILLED_DIR}/\n"
  bash "$0" report

# ═══════════════════════════════════════════════════════════════════
# COMANDO: compress-project
# ═══════════════════════════════════════════════════════════════════
elif [[ "$cmd" == "compress-project" ]]; then
  project_dir="${1:-$(pwd)}"
  memory_dir="${project_dir}/.claude/memory"

  echo -e "\n${BOLD}[HELIX-DISTILL]${NC} Comprimiendo contexto de proyecto: ${project_dir}\n"

  declare -A PROJECT_FILES=(
    ["helix-analysis.md"]="50"      # máx 50% del original
    ["helix-bitacora.md"]="30"      # más agresivo — crece mucho
    ["helix-team.md"]="60"
    ["helix-backlog.md"]="70"       # preservar más — es operativo
    ["helix-roadmap.md"]="60"
  )

  total_before=0
  total_after=0

  for filename in "${!PROJECT_FILES[@]}"; do
    filepath="${memory_dir}/${filename}"
    [[ ! -f "$filepath" ]] && continue

    original_chars=$(wc -c < "$filepath")
    original_tokens=$(( original_chars / 4 ))
    total_before=$(( total_before + original_tokens ))

    # Estrategia por archivo
    if [[ "$filename" == "helix-analysis.md" ]]; then
      # Extracción por sección: mantener solo Stack + Agentes + Riesgo + primera línea del Resumen
      file_lines=$(wc -l < "$filepath" | tr -d '[:space:]')
      if [[ "$file_lines" -gt 150 ]]; then
        compressed=$(PYVAR_CONTENT="$(cat "$filepath")" "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, re

content = os.environ.get('PYVAR_CONTENT', '')
lines = content.split('\n')

KEEP_HEADERS = ['stack', 'agentes', 'riesgo', 'risk', 'agents', 'skills', 'mcp']
SUMMARY_HEADERS = ['resumen', 'summary', 'ejecutivo']

result = []
current_section = None
current_keep = False
current_summary = False
summary_lines = 0

for line in lines:
    # Líneas de encabezado del documento (antes del primer ##)
    if not any(l.startswith('##') for l in result) and not line.startswith('##'):
        result.append(line)
        continue

    if line.startswith('## '):
        header_lower = line.lower()
        current_keep = any(kw in header_lower for kw in KEEP_HEADERS)
        current_summary = any(kw in header_lower for kw in SUMMARY_HEADERS)
        summary_lines = 0
        current_section = line
        if current_keep or current_summary:
            result.append(line)
        continue

    if current_keep:
        result.append(line)
    elif current_summary:
        # Del resumen: solo primer párrafo no vacío (1 línea)
        if summary_lines == 0 and line.strip():
            # Truncar a 200 chars si es muy largo
            result.append(line[:200] + ('...' if len(line) > 200 else ''))
            summary_lines += 1

print('\n'.join(result))
PYEOF
        )
      else
        compressed=$(_compress_linguistic "$(cat "$filepath")")
      fi

    elif [[ "$filename" == "helix-roadmap.md" ]]; then
      # Archivar milestones completados cuando superan 10 entradas
      compressed=$(PYVAR_CONTENT="$(cat "$filepath")" "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, re

content = os.environ.get('PYVAR_CONTENT', '')
lines = content.split('\n')

COMPLETED_HEADERS = ['✅ completado', '✅ done', '✅ cerrado', 'completado']
KEEP = 10  # máx filas en sección Completado

in_completed = False
completed_rows = []
completed_header_idx = None
result_lines = []

for i, line in enumerate(lines):
    if line.startswith('## ') and any(h in line.lower() for h in COMPLETED_HEADERS):
        in_completed = True
        completed_header_idx = len(result_lines)
        result_lines.append(line)
        continue
    if line.startswith('## ') and in_completed:
        in_completed = False

    if in_completed and re.match(r'^\s*\|.*\|', line) and '---' not in line:
        if not any(kw in line.lower() for kw in ['milestone', 'descripción', 'description', 'fecha', 'date']):
            completed_rows.append(line)
            continue

    result_lines.append(line)

# Si hay más de KEEP completados, insertar resumen + últimos KEEP
if len(completed_rows) > KEEP and completed_header_idx is not None:
    omitted = len(completed_rows) - KEEP
    # Insertar nota de condensación tras el header de la sección
    insert_at = completed_header_idx + 1
    # Encontrar la línea separadora de tabla (---) y el header de tabla
    for j in range(insert_at, min(insert_at + 5, len(result_lines))):
        if '---' in result_lines[j]:
            insert_at = j + 1
            break
    result_lines.insert(insert_at,
        f'| *(archivados)* | {omitted} milestones completados anteriores archivados | — |')
    # Reinyectar solo los últimos KEEP
    for row in completed_rows[-KEEP:]:
        result_lines.insert(insert_at + 1, row)
else:
    # No hay suficientes para archivar — reinyectar todos
    if completed_header_idx is not None:
        insert_at = completed_header_idx + 1
        for j in range(insert_at, min(insert_at + 5, len(result_lines))):
            if '---' in result_lines[j]:
                insert_at = j + 1
                break
        for row in completed_rows:
            result_lines.insert(insert_at, row)
            insert_at += 1

print('\n'.join(result_lines))
PYEOF
      )

    elif [[ "$filename" == "helix-bitacora.md" ]]; then
      # Preservar solo últimas N entradas de tabla
      compressed=$(PYVAR_CONTENT="$(cat "$filepath")" "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, re

content = os.environ.get('PYVAR_CONTENT', '')
lines = content.split('\n')
table_rows = [i for i, l in enumerate(lines) if re.match(r'^\s*\|.*\|', l) and '---' not in l and 'Fecha' not in l and 'Date' not in l]
KEEP = 30
if len(table_rows) > KEEP:
    cut_at = table_rows[-KEEP]
    header_lines = []
    for i in range(cut_at - 1, max(cut_at - 5, 0), -1):
        if '---' in lines[i] or 'Fecha' in lines[i]:
            header_lines = [i - 1, i]
            break
    kept = lines[:10]
    kept.append(f"\n> *(Entradas anteriores a la #{len(table_rows)-KEEP} condensadas. {len(table_rows)-KEEP} entradas históricas omitidas.)*\n")
    if header_lines:
        kept.extend(lines[header_lines[0]:header_lines[1]+1])
    kept.extend(lines[cut_at:])
    content = '\n'.join(kept)
print(content)
PYEOF
      )

    else
      compressed=$(_compress_linguistic "$(cat "$filepath")")
    fi

    compressed_chars=${#compressed}
    compressed_tokens=$(( compressed_chars / 4 ))
    total_after=$(( total_after + compressed_tokens ))
    pct=0
    [[ $original_tokens -gt 0 ]] && pct=$(( (original_tokens - compressed_tokens) * 100 / original_tokens ))

    # Guardar versión comprimida con backup
    backup="${filepath%.md}.original.md"
    [[ ! -f "$backup" ]] && cp "$filepath" "$backup"
    echo "$compressed" > "$filepath"

    echo -e "  ${GREEN}✓${NC} ${filename}: ~${original_tokens} → ~${compressed_tokens} tok (${pct}% ahorro)"
  done

  saved=$(( total_before - total_after ))
  pct_total=0
  [[ $total_before -gt 0 ]] && pct_total=$(( saved * 100 / total_before ))
  echo -e "\n  ${BOLD}Total proyecto: ~${total_before} → ~${total_after} tok (${GREEN}${pct_total}% ahorro${NC}${BOLD})${NC}\n"

# ═══════════════════════════════════════════════════════════════════
# COMANDO: compress-file
# ═══════════════════════════════════════════════════════════════════
elif [[ "$cmd" == "compress-file" ]]; then
  filepath="${1:-}"
  task="${2:-}"

  if [[ -z "$filepath" || ! -f "$filepath" ]]; then
    echo -e "${YELLOW}[DISTILL]${NC} Uso: helix-distill.sh compress-file <archivo> [tarea/keywords]"
    exit 1
  fi

  ext="${filepath##*.}"
  original_chars=$(wc -c < "$filepath")
  original_tokens=$(( original_chars / 4 ))

  echo -e "${BLUE}[DISTILL]${NC} Comprimiendo: ${filepath} (~${original_tokens} tok)" >&2
  [[ -n "$task" ]] && echo -e "  Tarea: ${task}" >&2

  # Single Python run: capture output, display it, measure it
  _compressed_output=$(PYVAR_FILE="$filepath" PYVAR_TASK="$task" PYVAR_EXT="$ext" "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, re
from pathlib import Path

filepath = os.environ['PYVAR_FILE']
task     = os.environ.get('PYVAR_TASK', '')
ext      = os.environ.get('PYVAR_EXT', '')
content  = Path(filepath).read_text(errors='replace')

if task:
    keywords = [k.strip().lower() for k in re.split(r'[\s,|]+', task) if k.strip()]

    if ext in ('py', 'ts', 'js', 'tsx', 'jsx', 'go', 'rs', 'java', 'kt'):
        if ext == 'py':
            pattern = r'\n(?=(?:def |class |async def ))'
        else:
            pattern = r'\n(?=(?:function |class |const |interface |type |export |async function ))'
        blocks = re.split(pattern, '\n' + content)
        relevant = []
        for b in blocks[:3]:
            if re.search(r'^(import|from|require|#)', b.strip(), re.M):
                relevant.append(b)
                break
        for block in blocks:
            if any(kw in block.lower() for kw in keywords) and block not in relevant:
                relevant.append(block)
        result = '\n'.join(relevant) if relevant else content
    elif ext == 'md':
        sections = re.split(r'\n(?=#{1,3} )', '\n' + content)
        relevant = [s for s in sections if any(kw in s.lower() for kw in keywords)]
        result = '\n'.join(relevant) if relevant else content
    else:
        # Non-code files: extract lines ±10 context around keyword matches
        lines = content.split('\n')
        relevant_idx = set()
        for i, line in enumerate(lines):
            if any(kw in line.lower() for kw in keywords):
                for j in range(max(0, i-10), min(len(lines), i+11)):
                    relevant_idx.add(j)
        result = '\n'.join(lines[i] for i in sorted(relevant_idx)) if relevant_idx else content
else:
    result = content

result = re.sub(r'\n{3,}', '\n\n', result)
print(result)
PYEOF
  )
  echo "$_compressed_output"
  compressed_chars=${#_compressed_output}
  compressed_tokens=$(( ${compressed_chars:-$original_chars} / 4 ))
  pct=0
  [[ $original_tokens -gt 0 ]] && pct=$(( (original_tokens - compressed_tokens) * 100 / original_tokens ))
  echo -e "  ${GREEN}Resultado: ~${original_tokens} → ~${compressed_tokens} tok (${pct}% ahorro)${NC}" >&2

# ═══════════════════════════════════════════════════════════════════
# COMANDO: compress-bitacora
# ═══════════════════════════════════════════════════════════════════
elif [[ "$cmd" == "compress-bitacora" ]]; then
  filepath="${1:-}"
  # Handle: --keep 5, --keep=5, or just 5 as second arg
  keep=30
  if [[ "${2:-}" == "--keep" && -n "${3:-}" ]]; then
    keep="${3}"
  elif [[ "${2:-}" == --keep=* ]]; then
    keep="${2#--keep=}"
  elif [[ "${2:-}" =~ ^[0-9]+$ ]]; then
    keep="${2}"
  fi

  if [[ -z "$filepath" || ! -f "$filepath" ]]; then
    echo -e "${YELLOW}[DISTILL]${NC} Uso: helix-distill.sh compress-bitacora <archivo> [--keep N]"
    exit 1
  fi

  original_tokens=$(( $(wc -c < "$filepath") / 4 ))
  backup="${filepath%.md}.original.md"
  [[ ! -f "$backup" ]] && cp "$filepath" "$backup"

  PYVAR_FILE="$filepath" PYVAR_KEEP="$keep" "${HELIX_PYTHON:-python3}" - <<'PYEOF' > "${filepath}.tmp"
import os, re
from pathlib import Path

content = Path(os.environ['PYVAR_FILE']).read_text()
keep = int(os.environ.get('PYVAR_KEEP', '30'))
lines = content.split('\n')

table_rows = [i for i, l in enumerate(lines)
              if re.match(r'^\s*\|', l) and '---' not in l
              and not re.search(r'Fecha|Date|Acción|Action|#', l)]

if len(table_rows) <= keep:
    print(content)
else:
    cut_at = table_rows[-keep]
    omitted = len(table_rows) - keep

    # Header del documento (primeras líneas hasta la primera tabla)
    first_table = table_rows[0] if table_rows else len(lines)
    header = lines[:first_table]

    # Encontrar header de tabla
    th_idx = cut_at - 1
    while th_idx > 0 and '---' not in lines[th_idx]:
        th_idx -= 1

    result = header
    result.append(f"\n> *(Historial condensado: {omitted} entradas anteriores omitidas)*\n")
    if th_idx > 0:
        result.extend(lines[th_idx-1:th_idx+1])
    result.extend(lines[cut_at:])
    print('\n'.join(result))
PYEOF

  mv "${filepath}.tmp" "$filepath"
  compressed_tokens=$(( $(wc -c < "$filepath") / 4 ))
  pct=0
  [[ $original_tokens -gt 0 ]] && pct=$(( (original_tokens - compressed_tokens) * 100 / original_tokens ))
  echo -e "${GREEN}[DISTILL]${NC} Bitácora comprimida: ~${original_tokens} → ~${compressed_tokens} tok (${pct}% ahorro) | preservadas últimas ${keep} entradas"

# ═══════════════════════════════════════════════════════════════════
# COMANDO: report
# ═══════════════════════════════════════════════════════════════════
elif [[ "$cmd" == "report" ]]; then
  [[ ! -f "$DATA_FILE" ]] && echo -e "${YELLOW}Sin datos. Ejecutar 'run' primero.${NC}" && exit 0

  full_tokens=$(( $(wc -c < "$CLAUDE_MD") / 4 ))

  "${HELIX_PYTHON:-python3}" - "$DATA_FILE" "$full_tokens" <<'PYEOF'
import json, sys
from pathlib import Path

data = json.load(open(sys.argv[1]))
full = int(sys.argv[2])

G='\033[0;32m'; Y='\033[1;33m'; B='\033[1m'; N='\033[0m'; R='\033[0;31m'

print(f"\n{B}{'='*58}{N}")
print(f"{B}  HELIX-COMPRESS — DISTILL Report{N}")
print(f"{'='*58}")
print(f"  CLAUDE.md completo : ~{full:,} tok  (línea base por agente)")
print(f"  Generado           : {data['generated'][:16]}\n")

agents = data['agents']
print(f"{B}  Ahorro por agente{N}  (vs CLAUDE.md completo)")
for name, m in sorted(agents.items(), key=lambda x: -x[1]['savings_pct']):
    comp = m['compressed_tokens']
    pct  = m['savings_pct']
    bar  = '█' * (pct // 10) + '░' * (10 - pct // 10)
    col  = G if pct >= 75 else (Y if pct >= 50 else R)
    print(f"  {name:<25} {col}{bar}{N} {pct:>3}% | ~{comp} tok")

n = len(agents)
tok_sin = n * full
tok_con = sum(m['compressed_tokens'] for m in agents.values())
ahorro  = int((1 - tok_con/tok_sin)*100) if tok_sin else 0

print(f"\n{B}  Proyección sesión Capa 2 ({n} agentes){N}")
print(f"  Sin DISTILL : ~{tok_sin:,} tok")
print(f"  Con DISTILL : ~{tok_con:,} tok")
col = G if ahorro >= 75 else Y
print(f"  Ahorro      : {col}{B}{ahorro}%{N}")

print(f"\n{B}  Comandos adicionales{N}")
print(f"  compress-project [DIR]           → helix-*.md del proyecto")
print(f"  compress-file FILE [task]        → extrae secciones relevantes de código")
print(f"  compress-bitacora FILE [--keep N]→ condensa bitácora")
print(f"\n{'='*58}\n")
PYEOF

# ═══════════════════════════════════════════════════════════════════
# COMANDO: status
# ═══════════════════════════════════════════════════════════════════
elif [[ "$cmd" == "status" ]]; then
  current=$(_source_hash)
  echo -e "\n${BOLD}[HELIX-DISTILL]${NC} CLAUDE.md hash actual: ${current}\n"
  shopt -s nullglob
  files=("$DISTILLED_DIR"/*.md)
  shopt -u nullglob
  [[ ${#files[@]} -eq 0 ]] && echo -e "  ${YELLOW}Sin slices.${NC} Ejecutar: run\n" && exit 0
  for f in "${files[@]}"; do
    h=$(grep "^source_hash:" "$f" 2>/dev/null | awk '{print $2}')
    name=$(basename "$f" .md)
    [[ "$h" == "$current" ]] && echo -e "  ${GREEN}✓${NC} $name" || echo -e "  ${YELLOW}!${NC} $name (desactualizado)"
  done; echo ""

# ═══════════════════════════════════════════════════════════════════
# COMANDO: clean
# ═══════════════════════════════════════════════════════════════════
elif [[ "$cmd" == "clean" ]]; then
  shopt -s nullglob
  files=("$DISTILLED_DIR"/*.md)
  shopt -u nullglob
  [[ ${#files[@]} -eq 0 ]] && echo -e "${GRAY}Sin slices.${NC}" && exit 0
  rm -f "${files[@]}" "$DATA_FILE" 2>/dev/null || true
  echo -e "${GREEN}[DISTILL]${NC} ${#files[@]} slices eliminados."

else
  echo -e "${YELLOW}Uso:${NC} helix-distill.sh [run|report|status|compress-project|compress-file|compress-bitacora|clean]"
  exit 1
fi

#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-routing-fix.sh — Auto-corrección del catálogo de agentes desde ERL+ExpeL
# Lee routing-heuristics.md, detecta mismatches, propone y aplica correcciones
# a agents-index.md
#
# Uso:
#   bash helix-routing-fix.sh           → propone correcciones (dry run)
#   bash helix-routing-fix.sh --apply   → aplica correcciones confirmadas
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
HEURISTICS_FILE="$GLOBAL_DIR/memory/routing-heuristics.md"
AGENTS_INDEX="$GLOBAL_DIR/memory/agents-index.md"
APPLY="${1:---dry-run}"

[[ ! -f "$HEURISTICS_FILE" ]] && {
    echo "Sin heurísticas. Ejecuta helix-erl.sh primero." >&2
    exit 0
}
[[ ! -f "$AGENTS_INDEX" ]] && {
    echo "agents-index.md no encontrado." >&2
    exit 1
}

export HELIX_HEURISTICS="$HEURISTICS_FILE"
export HELIX_AGENTS_INDEX="$AGENTS_INDEX"
export HELIX_APPLY="$APPLY"

"${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, re
from pathlib import Path
from datetime import datetime

heuristics_file = Path(os.environ['HELIX_HEURISTICS'])
agents_index    = Path(os.environ['HELIX_AGENTS_INDEX'])
apply           = os.environ.get('HELIX_APPLY', '--dry-run') == '--apply'
now             = datetime.now().strftime('%Y-%m-%d')

BLUE   = '\033[0;34m'; GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'; RED    = '\033[0;31m'; NC = '\033[0m'

heuristics_text = heuristics_file.read_text()
agents_text     = agents_index.read_text()

# ── Extraer agentes activos del catálogo ─────────────────────
active_agents = {}  # name → trigger string
for line in agents_text.splitlines():
    m = re.match(r'\|\s*`([a-z][a-z-]+)`\s*\|\s*(.+?)\s*\|', line)
    if m:
        active_agents[m.group(1)] = m.group(2).strip()

# ── Detectar correcciones necesarias desde sección ExpeL ─────
corrections = []

# Pattern 1: routing incorrecto detectado
for m in re.finditer(
    r'\[(\w+)\] se usa `([a-z-]+)` .+ pero `([a-z-]+)` existe en catálogo',
    heuristics_text
):
    domain, actual, ideal = m.group(1), m.group(2), m.group(3)
    if ideal in active_agents and actual in active_agents:
        corrections.append({
            'type': 'mismatch',
            'domain': domain,
            'actual_agent': actual,
            'ideal_agent': ideal,
            'description': f'[{domain}] reemplazar uso de {actual} por {ideal}',
            'fix': 'trigger_note',  # agregar nota al trigger del agente ideal
        })

# Pattern 2: routing evolucionó — el anterior es obsoleto
for m in re.finditer(
    r'\[(\w+)\] routing evolucionó: `([a-z-]+)` → `([a-z-]+)`',
    heuristics_text
):
    domain, old_agent, new_agent = m.group(1), m.group(2), m.group(3)
    if new_agent in active_agents:
        corrections.append({
            'type': 'evolution',
            'domain': domain,
            'old_agent': old_agent,
            'new_agent': new_agent,
            'description': f'[{domain}] {new_agent} reemplazó a {old_agent} — preferir {new_agent}',
            'fix': 'trigger_note',
        })

# Pattern 3: agente fuera de catálogo usado frecuentemente
for m in re.finditer(
    r'`([a-z-]+)` usado (\d+)x pero no está en catálogo activo',
    heuristics_text
):
    agent, count = m.group(1), int(m.group(2))
    if agent not in active_agents:
        corrections.append({
            'type': 'missing',
            'agent': agent,
            'count': count,
            'description': f'`{agent}` ({count}x) no está en catálogo activo',
            'fix': 'add_to_index',
        })

# ── Reportar ─────────────────────────────────────────────────
print(f"\n{BLUE}⬡ Helix Routing Fix{NC}")
print(f"  Agentes en catálogo: {len(active_agents)}")
print(f"  Correcciones detectadas: {len(corrections)}")

if not corrections:
    print(f"\n  {GREEN}✅ Catálogo consistente con heurísticas{NC}")
    raise SystemExit(0)

print()
for i, c in enumerate(corrections, 1):
    icon = YELLOW + '⚠️ ' + NC if c['type'] in ('mismatch', 'missing') else BLUE + '→' + NC
    print(f"  [{i}] {icon} {c['description']}")

if not apply:
    print(f"\n  Modo dry-run. Para aplicar: bash helix-routing-fix.sh --apply")
    raise SystemExit(0)

# ── Aplicar correcciones ──────────────────────────────────────
print(f"\n  Aplicando correcciones...")
modified_agents_text = agents_text
changes_made = []

for c in corrections:
    if c['fix'] == 'trigger_note' and 'ideal_agent' in c:
        # Agregar nota al trigger del agente ideal para el dominio
        agent  = c['ideal_agent']
        domain = c['domain']
        # Buscar la línea del agente y agregar "(preferir para {domain})" si no está ya
        pattern = rf'(\|\s*`{re.escape(agent)}`\s*\|[^\n]+)'
        def add_domain_note(m):
            line = m.group(1)
            if domain not in line:
                # Agregar al final de la línea del trigger
                line = re.sub(r'(\|\s*\[detalle\])', f'| ★ preferir para {domain} \\1', line)
            return line
        new_text = re.sub(pattern, add_domain_note, modified_agents_text)
        if new_text != modified_agents_text:
            modified_agents_text = new_text
            changes_made.append(f"  ✅ `{agent}` marcado como preferido para dominio '{domain}'")

    elif c['fix'] == 'add_to_index' and 'agent' in c:
        # Agregar agente a sección "Agentes Nuevos" si no está en deshabilitados
        agent = c['agent']
        disabled_line = re.search(r'## Deshabilitados.*?\n(.*?)(?=\n##)', modified_agents_text, re.DOTALL)
        if disabled_line and agent in disabled_line.group(1):
            # Mover de deshabilitados a activos
            modified_agents_text = modified_agents_text.replace(
                f'`{agent}`', '', 1  # remove from disabled section
            )
            # Agregar nota de que debería activarse
            changes_made.append(f"  💡 `{agent}` ({c['count']}x): considera mover de Deshabilitados a Activos")
        else:
            changes_made.append(f"  💡 `{agent}` no está en catálogo — añadir manualmente si corresponde")

# Agregar sección de cambios aplicados al final si hubo
if changes_made:
    # Agregar timestamp de última corrección
    fix_note = f"\n\n> Última corrección ERL+ExpeL: {now}"
    if "Última corrección ERL" in modified_agents_text:
        modified_agents_text = re.sub(
            r'> Última corrección ERL.*',
            fix_note.strip(),
            modified_agents_text
        )
    else:
        modified_agents_text = modified_agents_text.rstrip() + fix_note

    agents_index.write_text(modified_agents_text)

    print(f"\n  Cambios aplicados:")
    for change in changes_made:
        print(change)
else:
    print(f"\n  Sin cambios automáticos aplicables. Revisión manual recomendada.")
    for c in corrections:
        if c['type'] == 'missing':
            print(f"  → Añadir `{c['agent']}` al catálogo si lo usas frecuentemente")
PYEOF

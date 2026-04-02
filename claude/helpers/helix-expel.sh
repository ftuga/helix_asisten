#!/usr/bin/env bash
# helix-expel.sh — ExpeL: Experiential Policy Learning
# Analiza trayectorias en routing-feedback.jsonl para extraer reglas contrastivas
# Compara agentes que compiten en el mismo dominio y abstrae políticas generalizables
#
# Uso: bash helix-expel.sh [--min-contrast N]
# Output: agrega sección "## Reglas ExpeL" a routing-heuristics.md
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
FEEDBACK_FILE="$GLOBAL_DIR/memory/routing-feedback.jsonl"
HEURISTICS_FILE="$GLOBAL_DIR/memory/routing-heuristics.md"
AGENTS_INDEX="$GLOBAL_DIR/memory/agents-index.md"
MIN_CONTRAST="${1:-2}"

[[ ! -f "$FEEDBACK_FILE" ]] && echo "Sin datos de routing." >&2 && exit 0

export HELIX_FEEDBACK="$FEEDBACK_FILE"
export HELIX_HEURISTICS="$HEURISTICS_FILE"
export HELIX_AGENTS_INDEX="$AGENTS_INDEX"
export HELIX_MIN_CONTRAST="$MIN_CONTRAST"

python3 - <<'PYEOF'
import os, json, re
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict, Counter

feedback_file  = Path(os.environ['HELIX_FEEDBACK'])
heuristics_file = Path(os.environ['HELIX_HEURISTICS'])
agents_index   = Path(os.environ['HELIX_AGENTS_INDEX'])
min_contrast   = int(os.environ.get('HELIX_MIN_CONTRAST', 2))
now            = datetime.now().strftime('%Y-%m-%d %H:%M')

# ── Cargar catálogo de agentes activos ───────────────────────
active_agents = set()
if agents_index.exists():
    for line in agents_index.read_text().splitlines():
        m = re.search(r'`([a-z][a-z-]+)`', line)
        if m:
            active_agents.add(m.group(1))

# ── Cargar y enriquecer feedback entries ─────────────────────
DOMAIN_KEYWORDS = {
    'frontend':    ['react', 'component', 'tsx', 'frontend', 'ui', 'interfaz', 'diseño', 'tailwind', 'página', 'form'],
    'backend':     ['fastapi', 'endpoint', 'api', 'router', 'backend', 'python', 'sqlalchemy', 'modelo'],
    'database':    ['schema', 'migración', 'query', 'sql', 'postgresql', 'índice', 'tabla'],
    'testing':     ['test', 'pytest', 'coverage', 'fixture', 'mock', 'assert', 'suite'],
    'security':    ['auth', 'jwt', 'token', 'permiso', 'seguridad', 'cors', 'oauth'],
    'devops':      ['docker', 'deploy', 'nginx', 'compose', 'container', 'ci', 'pipeline'],
    'analysis':    ['analizar', 'reporte', 'report', 'dashboard', 'métricas', 'datos'],
    'architecture':['arquitectura', 'estructura', 'patrón', 'refactor', 'módulo', 'capa'],
    'research':    ['investig', 'busca', 'search', 'best practice', 'documentación'],
}

def detect_domain(tarea: str) -> list:
    tarea_lower = tarea.lower()
    return [d for d, kws in DOMAIN_KEYWORDS.items() if any(k in tarea_lower for k in kws)] or ['general']

# Agente "ideal" por dominio según el catálogo
IDEAL_AGENT = {
    'testing':     'test-engineer',
    'backend':     'python-pro',
    'frontend':    'frontend-developer',
    'database':    'database-architect',
    'security':    'security-auditor',
    'devops':      'devops-engineer',
    'analysis':    'data-analyst',
    'architecture':'architect-reviewer',
    'research':    'backend-architect',  # researcher no es un agente del catálogo activo
}

entries = []
with open(feedback_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            d['_domains'] = detect_domain(d.get('tarea', ''))
            entries.append(d)
        except:
            pass

# ── Análisis 1: Contrastes por dominio ───────────────────────
# Para cada dominio, qué agentes compiten y cuál domina
domain_agents: dict[str, list] = defaultdict(list)
for e in entries:
    for d in e['_domains']:
        domain_agents[d].append(e['agente'])

contrast_rules = []
for domain, agents_used in domain_agents.items():
    if len(agents_used) < min_contrast:
        continue
    counter = Counter(agents_used)
    unique_agents = list(counter.keys())

    if len(unique_agents) < 2:
        continue  # solo un agente — no hay contraste

    dominant, dom_count = counter.most_common(1)[0]
    second,   sec_count = counter.most_common(2)[-1]
    total = len(agents_used)

    # Regla contrastiva: A domina sobre B en dominio X
    if dom_count > sec_count:
        contrast_rules.append({
            'type': 'dominance',
            'domain': domain,
            'winner': dominant,
            'loser': second,
            'winner_pct': int(dom_count / total * 100),
            'rule': f"[{domain}] `{dominant}` ({dom_count}x, {int(dom_count/total*100)}%) supera a `{second}` ({sec_count}x) — usar `{dominant}` como primera opción"
        })

# ── Análisis 2: Routing incorrecto por dominio ───────────────
# Agente usado ≠ agente ideal del catálogo, y el ideal existe y está activo
mismatch_rules = []
for domain, agents_used in domain_agents.items():
    ideal = IDEAL_AGENT.get(domain)
    if not ideal or ideal not in active_agents:
        continue

    counter = Counter(agents_used)
    actual_dominant = counter.most_common(1)[0][0] if counter else None

    if actual_dominant and actual_dominant != ideal:
        # Se usa un agente diferente al ideal
        actual_count = counter[actual_dominant]
        ideal_count  = counter.get(ideal, 0)
        total = sum(counter.values())

        if ideal_count == 0:
            mismatch_rules.append({
                'type': 'mismatch',
                'domain': domain,
                'actual': actual_dominant,
                'ideal': ideal,
                'rule': f"[{domain}] se usa `{actual_dominant}` ({actual_count}x) pero `{ideal}` existe en catálogo y nunca se ha invocado — posible routing incorrecto"
            })
        elif actual_count > ideal_count * 2:
            mismatch_rules.append({
                'type': 'underuse',
                'domain': domain,
                'actual': actual_dominant,
                'ideal': ideal,
                'rule': f"[{domain}] `{actual_dominant}` ({actual_count}x) se usa {actual_count//max(ideal_count,1)}x más que `{ideal}` ({ideal_count}x) — considerar routing más preciso"
            })

# ── Análisis 3: Agentes fuera de catálogo usados frecuentemente ──
# Agentes invocados pero no en agents-index activos
out_of_catalog = []
all_used = Counter(e['agente'] for e in entries)
for agent, count in all_used.most_common():
    if agent not in active_agents and count >= min_contrast:
        out_of_catalog.append({
            'agent': agent,
            'count': count,
            'rule': f"`{agent}` usado {count}x pero no está en catálogo activo — considerar añadir a agents-index.md"
        })

# ── Análisis 4: Evolución temporal del routing ───────────────
# Si para un dominio el agente cambió con el tiempo → el anterior era subóptimo
temporal_rules = []
recent_cutoff = (datetime.now() - timedelta(days=14)).strftime('%Y-%m-%d')
for domain, agents_list in domain_agents.items():
    all_for_domain = [e for e in entries if domain in e['_domains']]
    if len(all_for_domain) < 4:
        continue
    all_for_domain.sort(key=lambda x: x.get('ts', ''))
    first_half  = Counter(e['agente'] for e in all_for_domain[:len(all_for_domain)//2])
    second_half = Counter(e['agente'] for e in all_for_domain[len(all_for_domain)//2:])

    old_dominant = first_half.most_common(1)[0][0] if first_half else None
    new_dominant = second_half.most_common(1)[0][0] if second_half else None

    if old_dominant and new_dominant and old_dominant != new_dominant:
        temporal_rules.append({
            'domain': domain,
            'old': old_dominant,
            'new': new_dominant,
            'rule': f"[{domain}] routing evolucionó: `{old_dominant}` → `{new_dominant}` — `{new_dominant}` es la estrategia aprendida más reciente"
        })

# ── Generar output ───────────────────────────────────────────
all_rules = (
    [r['rule'] for r in contrast_rules] +
    [r['rule'] for r in mismatch_rules] +
    [r['rule'] for r in out_of_catalog] +
    [r['rule'] for r in temporal_rules]
)

if not all_rules:
    print("Sin reglas contrastivas suficientes aún (necesita más datos de routing)")
    raise SystemExit(0)

# Reemplazar o agregar sección ExpeL en routing-heuristics.md
expel_section = f"""
## Reglas ExpeL (Contrastivas)
> Generado: {now} | Basado en {len(entries)} trayectorias

"""
if contrast_rules:
    expel_section += "### Dominancia observada\n"
    for r in contrast_rules:
        expel_section += f"- {r['rule']}\n"
    expel_section += "\n"

if mismatch_rules:
    expel_section += "### Routing incorrecto detectado\n"
    for r in mismatch_rules:
        expel_section += f"- {r['rule']}\n"
    expel_section += "\n"

if out_of_catalog:
    expel_section += "### Agentes fuera de catálogo\n"
    for r in out_of_catalog[:5]:
        expel_section += f"- {r['rule']}\n"
    expel_section += "\n"

if temporal_rules:
    expel_section += "### Evolución temporal\n"
    for r in temporal_rules:
        expel_section += f"- {r['rule']}\n"
    expel_section += "\n"

# Actualizar routing-heuristics.md
if heuristics_file.exists():
    content = heuristics_file.read_text()
    # Reemplazar sección existente o agregar al final
    if "## Reglas ExpeL" in content:
        content = re.sub(r'\n## Reglas ExpeL.*?(?=\n## |\Z)', expel_section, content, flags=re.DOTALL)
    else:
        content = content.rstrip() + "\n" + expel_section
    heuristics_file.write_text(content)
else:
    heuristics_file.write_text(expel_section)

# Output
GREEN = '\033[0;32m'; BLUE = '\033[0;34m'; YELLOW = '\033[1;33m'; NC = '\033[0m'
print(f"\n{BLUE}⬡ Helix ExpeL — {len(entries)} trayectorias analizadas{NC}")
if contrast_rules:
    print(f"  {len(contrast_rules)} contrastes de dominancia")
if mismatch_rules:
    for r in mismatch_rules:
        print(f"  {YELLOW}⚠️  routing incorrecto: [{r['domain']}] {r['actual']} → debería ser {r['ideal']}{NC}")
if out_of_catalog:
    print(f"  {len(out_of_catalog)} agentes fuera de catálogo con uso frecuente")
if temporal_rules:
    print(f"  {len(temporal_rules)} evoluciones de routing detectadas")
print(f"  → {heuristics_file}")
PYEOF

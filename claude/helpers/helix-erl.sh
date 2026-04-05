#!/usr/bin/env bash
# helix-erl.sh — Experiential Reflective Learning
# Analiza routing-feedback.jsonl y extrae heurísticas reutilizables
# Uso: bash helix-erl.sh [--min-samples N] [--force]
# Output: ~/.claude/memory/routing-heuristics.md
set -uo pipefail

MIN_SAMPLES="${1:-2}"
GLOBAL_DIR="$HOME/.claude"
FEEDBACK_FILE="$GLOBAL_DIR/memory/routing-feedback.jsonl"
HEURISTICS_FILE="$GLOBAL_DIR/memory/routing-heuristics.md"
TOPICS_DIR="$GLOBAL_DIR/memory/topics"

if [[ ! -f "$FEEDBACK_FILE" ]]; then
  echo "Sin datos de routing. Ejecuta tareas con agentes primero." >&2
  exit 0
fi

export HELIX_FEEDBACK="$FEEDBACK_FILE"
export HELIX_MIN_SAMPLES="$MIN_SAMPLES"
export HELIX_OUTPUT="$HEURISTICS_FILE"
export HELIX_TOPICS="$TOPICS_DIR"
export HELIX_GLOBAL="$GLOBAL_DIR"

python3 - <<'PYEOF'
import os, json, re
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict, Counter

feedback_file = Path(os.environ['HELIX_FEEDBACK'])
min_samples   = int(os.environ.get('HELIX_MIN_SAMPLES', 2))
output_file   = Path(os.environ['HELIX_OUTPUT'])
today         = datetime.now().strftime('%Y-%m-%d')
now           = datetime.now().strftime('%Y-%m-%d %H:%M')

# ── Cargar datos ─────────────────────────────────────────────
entries = []
with open(feedback_file) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            entries.append(d)
        except:
            pass

if not entries:
    print("Sin entradas en routing-feedback.jsonl")
    raise SystemExit(0)

# ── Extraer keywords de tareas ───────────────────────────────
DOMAIN_KEYWORDS = {
    'frontend':    ['react', 'component', 'tsx', 'frontend', 'ui', 'interfaz', 'diseño', 'tailwind', 'página', 'form'],
    'backend':     ['fastapi', 'endpoint', 'api', 'router', 'backend', 'python', 'sqlalchemy', 'modelo'],
    'database':    ['schema', 'migración', 'query', 'sql', 'postgresql', 'índice', 'tabla', 'relación'],
    'testing':     ['test', 'pytest', 'coverage', 'fixture', 'mock', 'assert', 'unit', 'integration'],
    'security':    ['auth', 'jwt', 'token', 'permiso', 'seguridad', 'cors', 'oauth', 'password'],
    'devops':      ['docker', 'deploy', 'nginx', 'compose', 'container', 'ci', 'pipeline', 'infra'],
    'analysis':    ['analizar', 'analiz', 'reporte', 'report', 'dashboard', 'métricas', 'datos', 'chart'],
    'architecture':['arquitectura', 'estructura', 'patrón', 'refactor', 'diseño', 'módulo', 'capa'],
    'research':    ['investig', 'busca', 'search', 'best practice', 'documentación', 'herramienta'],
}

def detect_domain(tarea: str) -> list[str]:
    tarea_lower = tarea.lower()
    found = []
    for domain, keywords in DOMAIN_KEYWORDS.items():
        if any(kw in tarea_lower for kw in keywords):
            found.append(domain)
    return found or ['general']

# ── Análisis 1: Agente más exitoso por dominio ───────────────
domain_agent: dict[str, list[str]] = defaultdict(list)
for e in entries:
    if e.get('resultado') in ('success', 'partial', None, ''):
        domains = detect_domain(e.get('tarea', ''))
        for d in domains:
            domain_agent[d].append(e['agente'])

heuristics_domain = []
for domain, agents in domain_agent.items():
    agent_counts = Counter(agents)
    top_agent, count = agent_counts.most_common(1)[0]
    if count >= min_samples:
        total = len(agents)
        pct   = int(count / total * 100)
        alternatives = [f"{a}({c})" for a, c in agent_counts.most_common(3) if a != top_agent]
        alt_str = f" | alternativas: {', '.join(alternatives)}" if alternatives else ""
        heuristics_domain.append({
            'domain': domain,
            'agent': top_agent,
            'count': count,
            'total': total,
            'pct': pct,
            'rule': f"dominio '{domain}' → `{top_agent}` ({count}/{total} usos, {pct}%{alt_str})"
        })

# ── Análisis 2: Pares frecuentes de agentes ──────────────────
# Agrupar por proyecto + ordenar por timestamp
by_project: dict[str, list[dict]] = defaultdict(list)
for e in entries:
    proj = e.get('proyecto', 'global') or 'global'
    by_project[proj].append(e)

pair_counter: Counter = Counter()
for proj, evts in by_project.items():
    evts.sort(key=lambda x: x.get('ts', ''))
    for i in range(len(evts) - 1):
        a1 = evts[i]['agente']
        a2 = evts[i+1]['agente']
        if a1 != a2:
            pair_counter[(a1, a2)] += 1

heuristics_pairs = []
for (a1, a2), count in pair_counter.most_common(5):
    if count >= min_samples:
        heuristics_pairs.append({
            'pair': (a1, a2),
            'count': count,
            'rule': f"flujo frecuente: `{a1}` → `{a2}` ({count}x) — considerar skill de orquestación"
        })

# ── Análisis 3: Agentes nunca usados (gap) ───────────────────
used_agents = set(e['agente'] for e in entries)

# Agentes del catálogo desde agents-index.md
agents_index = Path(os.environ.get('HELIX_FEEDBACK', '')).parent.parent / 'memory/agents-index.md'
catalog_agents = set()
if agents_index.exists():
    for line in agents_index.read_text().splitlines():
        m = re.search(r'`([a-z][a-z-]+)`', line)
        if m:
            catalog_agents.add(m.group(1))

never_used = catalog_agents - used_agents
rarely_used = []  # agentes usados 1 vez en toda la historia
for agent in used_agents:
    total = sum(1 for e in entries if e['agente'] == agent)
    if total == 1:
        rarely_used.append(agent)

# ── Análisis 4: Tendencia por proyecto ───────────────────────
project_patterns = []
for proj, evts in by_project.items():
    if len(evts) < 3 or not proj or proj == 'global':
        continue
    agents_proj = Counter(e['agente'] for e in evts)
    dominant, dom_count = agents_proj.most_common(1)[0]
    if dom_count >= 3:
        project_patterns.append({
            'project': proj,
            'agent': dominant,
            'count': dom_count,
            'rule': f"proyecto `{proj}` usa `{dominant}` como agente dominante ({dom_count}x)"
        })

# ── Generar output ───────────────────────────────────────────
lines = [
    f"# Routing Heuristics — Helix ERL",
    f"> Generado: {now} | Entradas analizadas: {len(entries)}",
    f"> Umbral mínimo: {min_samples} muestras",
    "",
    "## Reglas por Dominio",
    "",
]

if heuristics_domain:
    for h in sorted(heuristics_domain, key=lambda x: -x['pct']):
        lines.append(f"- {h['rule']}")
else:
    lines.append("- Sin suficientes datos aún (necesita ≥2 muestras por dominio)")

lines += ["", "## Flujos Frecuentes (Pares)", ""]
if heuristics_pairs:
    for h in heuristics_pairs:
        lines.append(f"- {h['rule']}")
else:
    lines.append("- Sin pares frecuentes detectados aún")

lines += ["", "## Patrones por Proyecto", ""]
if project_patterns:
    for h in project_patterns:
        lines.append(f"- {h['rule']}")
else:
    lines.append("- Sin proyectos con suficiente historial")

lines += ["", "## Gaps Detectados", ""]
if never_used and catalog_agents:
    lines.append(f"- **Nunca usados** ({len(never_used)}): {', '.join(sorted(never_used)[:10])}")
if rarely_used:
    lines.append(f"- **Usados 1 vez**: {', '.join(sorted(rarely_used)[:8])}")
if not never_used and not rarely_used:
    lines.append("- Sin gaps significativos detectados")

# ── Integrar quality scores de skill-quality.jsonl ──────────
quality_file = Path(os.environ.get('HELIX_GLOBAL', str(Path.home() / '.claude'))) / 'memory' / 'skill-quality.jsonl'
if quality_file.exists():
    from collections import defaultdict
    quality_scores = defaultdict(list)
    for line in quality_file.read_text().splitlines():
        line = line.strip()
        if not line: continue
        try:
            e = json.loads(line)
            quality_scores[e['name']].append(e['score'])
        except: pass

    if quality_scores:
        lines += ["", "## Calidad por Agente (skill-quality.jsonl)", ""]
        problematic = []
        partial = []
        reliable = []
        for name, scores in quality_scores.items():
            avg = sum(scores) / len(scores)
            n = len(scores)
            if avg < 1.5:
                problematic.append((name, avg, n))
            elif avg < 2.5:
                partial.append((name, avg, n))
            else:
                reliable.append((name, avg, n))

        if problematic:
            lines.append("### ⚠️ Agentes problemáticos (avg < 1.5) — revisar o reemplazar")
            for name, avg, n in sorted(problematic, key=lambda x: x[1]):
                lines.append(f"- **{name}** avg={avg:.1f} ({n} usos) — considerar skill alternativa o mejorar prompt")
        if partial:
            lines.append("### Agentes con correcciones frecuentes (avg 1.5–2.4)")
            for name, avg, n in sorted(partial, key=lambda x: x[1]):
                lines.append(f"- {name} avg={avg:.1f} ({n} usos)")
        if reliable:
            lines.append("### ✅ Agentes confiables (avg ≥ 2.5)")
            for name, avg, n in sorted(reliable, key=lambda x: -x[1]):
                lines.append(f"- {name} avg={avg:.1f} ({n} usos)")

lines += [
    "",
    "---",
    f"*Actualizar con: `bash ~/.claude/helpers/helix-erl.sh`*",
]

output_file.parent.mkdir(parents=True, exist_ok=True)
output_file.write_text('\n'.join(lines) + '\n')

# ── Output para terminal ─────────────────────────────────────
GREEN = '\033[0;32m'; BLUE = '\033[0;34m'; NC = '\033[0m'
print(f"\n{BLUE}⬡ Helix ERL — {len(entries)} entradas analizadas{NC}")
print(f"  {len(heuristics_domain)} heurísticas de dominio")
print(f"  {len(heuristics_pairs)} flujos frecuentes")
print(f"  {len(project_patterns)} patrones por proyecto")
if never_used:
    print(f"  ⚠️  {len(never_used)} agentes nunca usados en catálogo")
print(f"  → {output_file}")
PYEOF

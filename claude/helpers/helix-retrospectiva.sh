#!/usr/bin/env bash
# helix-retrospectiva.sh — Análisis automático al cierre de sesión
# Detecta aprendizajes no registrados, patrones de uso, gaps y genera reflexiones
# Uso: bash helix-retrospectiva.sh "<resumen_sesion>" [PROJECT_ROOT]
set -uo pipefail

RESUMEN="${1:-}"
PROJECT="${2:-}"
GLOBAL_DIR="$HOME/.claude"
MEMORY_DIR="$GLOBAL_DIR/memory"

# ── 1. ERL: actualizar heurísticas de routing ────────────────
ERL_SCRIPT="$GLOBAL_DIR/helpers/helix-erl.sh"
if [[ -f "$ERL_SCRIPT" ]]; then
    # Correr ERL cada 7 días o si el archivo no existe
    HEURISTICS="$MEMORY_DIR/routing-heuristics.md"
    SHOULD_RUN=false
    if [[ ! -f "$HEURISTICS" ]]; then
        SHOULD_RUN=true
    else
        LAST_MOD=$(date -r "$HEURISTICS" '+%s' 2>/dev/null || echo 0)
        NOW=$(date '+%s')
        DAYS_OLD=$(( (NOW - LAST_MOD) / 86400 ))
        [[ "$DAYS_OLD" -ge 7 ]] && SHOULD_RUN=true
    fi
    if [[ "$SHOULD_RUN" == "true" ]]; then
        bash "$ERL_SCRIPT" 2>/dev/null || true
    fi
fi

export HELIX_RESUMEN="$RESUMEN"
export HELIX_PROJECT="$PROJECT"
export HELIX_GLOBAL="$GLOBAL_DIR"

python3 - <<'PYEOF'
import os, json, re
from datetime import datetime, timedelta
from pathlib import Path
from collections import Counter

resumen   = os.environ.get('HELIX_RESUMEN', '')
project   = os.environ.get('HELIX_PROJECT', '')
global_dir = Path(os.environ.get('HELIX_GLOBAL', Path.home() / '.claude'))
memory_dir = global_dir / 'memory'
today      = datetime.now().strftime('%Y-%m-%d')
now        = datetime.now().strftime('%Y-%m-%d %H:%M')

evo_log    = memory_dir / 'evolution-log.txt'
routing_fb = memory_dir / 'routing-feedback.jsonl'

# ── Utilidades ───────────────────────────────────────────────
def load_evo_log():
    if not evo_log.exists():
        return []
    return evo_log.read_text().splitlines()

def today_learnings(lines):
    return [l for l in lines if today in l and '[LEARN]' in l]

def append_to_evo_log(entries):
    with open(evo_log, 'a') as f:
        for e in entries:
            f.write(e + '\n')

# ── Señales en el resumen de sesión ─────────────────────────
# Palabras clave → (categoría, confianza, descripción)
SIGNALS = [
    (r'\bPyJWT\b',            'testing',       0.9, 'PyJWT migration detectada'),
    (r'scalar_one_or_none',   'funcionalidad', 0.9, 'scalar_one_or_none fix pattern'),
    (r'\b(\d+)\s+bug',        'funcionalidad', 0.8, 'bugs corregidos en sesión'),
    (r'migr[aó]ci[oó]n\b',   'datos',         0.75, 'migración de datos o schema'),
    (r'\brace condition\b',   'arquitectura',  0.85,'race condition detectada'),
    (r'\bN\+1\b',             'performance',   0.85, 'problema N+1 detectado'),
    (r'timeout',              'operatividad',  0.75, 'timeout issue en sesión'),
    (r'CORS',                 'seguridad',     0.8,  'problema CORS resuelto'),
    (r'docker\s+compose',     'docker',        0.7,  'docker compose trabajo'),
    (r'índice[s]?\s+faltante|index.*missing', 'datos', 0.8, 'índice DB faltante'),
    (r'celery|worker|queue',  'celery',        0.75, 'trabajo con celery/workers'),
    (r'\bauth\w*\b.*\btoken|token.*\bauth', 'auth', 0.8, 'auth/token pattern'),
]

candidates = []  # (categoría, confianza, texto)

resumen_lower = resumen.lower()

evo_lines = load_evo_log()
seen_categorias = set()  # evitar múltiples candidatos por categoría en mismo run

for pattern, categoria, confianza, hint in SIGNALS:
    if categoria in seen_categorias:
        continue
    m = re.search(pattern, resumen, re.IGNORECASE)
    if m:
        # Verificar que no hay ya un [LEARN] de esta categoría hoy
        already_registered = any(
            today in l and f'[{categoria}]' in l
            for l in evo_lines
        )
        if not already_registered:
            seen_categorias.add(categoria)
            candidates.append((categoria, confianza, hint, hint))

# ── Análisis de patrones de routing ─────────────────────────
agent_patterns = []
if routing_fb.exists():
    entries = []
    with open(routing_fb) as f:
        for line in f:
            try:
                d = json.loads(line)
                entries.append(d)
            except:
                pass

    # Entradas de hoy
    today_entries = [e for e in entries if e.get('ts', '').startswith(today)]

    # Patrones: agente usado N veces hoy para mismo proyecto
    if today_entries:
        agent_counter = Counter(e['agente'] for e in today_entries)
        proj_counter  = Counter(e.get('proyecto', '') for e in today_entries if e.get('proyecto'))
        dominant_proj = proj_counter.most_common(1)[0][0] if proj_counter else ''
        dominant_agent, count = agent_counter.most_common(1)[0] if agent_counter else ('', 0)

        if count >= 3:
            # Agente dominante hoy — verificar si ya hay skill para él
            skills_dir = Path(os.environ['HELIX_GLOBAL']) / 'skills'
            agent_skill_exists = any(
                dominant_agent.replace('-', '_') in f.stem or dominant_agent in f.stem
                for f in skills_dir.glob('*.md')
            ) if skills_dir.exists() else False

            if not agent_skill_exists:
                agent_patterns.append((
                    'arquitectura', 0.7,
                    f'agente-dominante: {dominant_agent}',
                    f'{dominant_agent} usado {count}x hoy en {dominant_proj} — considerar skill dedicada'
                ))

    # Pares de agentes frecuentes (últimos 7 días)
    week_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')
    recent = [e for e in entries if e.get('ts', '') >= week_ago]
    if len(recent) >= 6:
        # Secuencias de 2 agentes consecutivos por proyecto
        by_project = {}
        for e in recent:
            p = e.get('proyecto', 'global')
            by_project.setdefault(p, []).append(e['agente'])

        pair_counter = Counter()
        for proj, agents in by_project.items():
            for i in range(len(agents) - 1):
                pair_counter[(agents[i], agents[i+1])] += 1

        top_pair, pair_count = pair_counter.most_common(1)[0] if pair_counter else (('', ''), 0)
        if pair_count >= 3 and top_pair[0] and top_pair[1]:
            agent_patterns.append((
                'arquitectura', 0.75,
                f'par-de-agentes: {top_pair[0]}→{top_pair[1]}',
                f'Par {top_pair[0]}→{top_pair[1]} aparece {pair_count}x en última semana — patrón de orquestación frecuente'
            ))

candidates.extend(agent_patterns)

# ── Sesión de alta complejidad sin aprendizajes ──────────────
evo_lines = load_evo_log()
today_learns = today_learnings(evo_lines)
resumen_words = len(resumen.split())

if resumen_words > 40 and len(today_learns) == 0 and not candidates:
    # Sesión con trabajo real pero sin aprendizajes registrados
    candidates.append((
        'operatividad', 0.65,
        'sesión-sin-aprendizajes',
        f'Sesión de {resumen_words} palabras de resumen sin aprendizajes registrados — ¿hubo algo nuevo?'
    ))

# ── Filtrar y registrar ──────────────────────────────────────
if not candidates:
    # Sin candidatos — todo OK
    raise SystemExit(0)

auto_register = [(c, s, t, d) for c, s, t, d in candidates if s >= 0.75]
review_needed = [(c, s, t, d) for c, s, t, d in candidates if 0.65 <= s < 0.75]

new_entries = []
for categoria, confianza, tag, descripcion in auto_register:
    entry = f'[{now}] [LEARN] [{categoria}] {descripcion} (trigger: retrospectiva-auto/{tag})'
    new_entries.append(entry)

for categoria, confianza, tag, descripcion in review_needed:
    entry = f'[{now}] [CANDIDATE] [{categoria}] {descripcion} (confianza: {confianza:.0%}, trigger: retrospectiva/{tag})'
    new_entries.append(entry)

if new_entries:
    append_to_evo_log(new_entries)
    print(f'\n\033[0;34m⬡ Helix Retrospectiva — {len(auto_register)} auto-registrados, {len(review_needed)} candidatos\033[0m')
    for e in new_entries:
        prefix = '  ✅' if '[LEARN]' in e else '  🔎'
        match = re.search(r'\[(LEARN|CANDIDATE)\] \[(\w+)\] (.+?) \(', e)
        if match:
            tipo, cat, desc = match.groups()
            print(f'{prefix} [{cat}] {desc[:70]}')

# ── Gap analysis: heurísticas vs uso real ────────────────────
heuristics_file = memory_dir / 'routing-heuristics.md'
if heuristics_file.exists() and routing_fb.exists():
    try:
        heuristics_text = heuristics_file.read_text()
        # Extraer dominios que tienen heurísticas documentadas
        documented_domains = re.findall(r"dominio '([^']+)'", heuristics_text)
        # Detectar dominio de esta sesión desde el resumen
        session_domains = []
        domain_hints = {
            'frontend': ['react', 'component', 'frontend', 'ui', 'interfaz', 'diseño'],
            'backend':  ['fastapi', 'api', 'endpoint', 'backend', 'sqlalchemy'],
            'testing':  ['test', 'pytest', 'coverage', 'bug', 'fix'],
            'analysis': ['analizar', 'reporte', 'dashboard', 'métricas'],
        }
        for domain, hints in domain_hints.items():
            if any(h in resumen.lower() for h in hints):
                session_domains.append(domain)

        gaps = [d for d in session_domains if d not in documented_domains]
        if gaps:
            print(f'\n  💡 Gap detectado: dominios {gaps} usados pero sin heurísticas → ejecutar helix-erl.sh')
    except:
        pass

# ── Auto-reflexión si el resumen menciona errores resueltos ──
error_keywords = ['corregido', 'bug', 'fix', 'resolvió', 'solucionó', 'fixed', 'reparó']
if any(kw in resumen.lower() for kw in error_keywords):
    # Extraer fragmentos de error del resumen para sugerir almacenar en Reflexion
    error_frags = []
    for sent in resumen.replace('. ', '.|').split('|'):
        if any(kw in sent.lower() for kw in error_keywords) and len(sent) > 15:
            error_frags.append(sent.strip()[:120])

    if error_frags:
        print(f'\n  💾 {len(error_frags)} error(es) resuelto(s) detectado(s) en resumen')
        print(f'     → Considera: bash ~/.claude/helpers/helix-reflexion.sh store "<error>" "<resolución>"')
        for frag in error_frags[:2]:
            print(f'     · {frag[:80]}')

PYEOF

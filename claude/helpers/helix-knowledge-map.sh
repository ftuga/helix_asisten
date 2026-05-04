#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-knowledge-map.sh — Mapa de confianza cross-dominio
# Cruza: learnings × heurísticas confirmadas × reflexiones en Qdrant × decay scores
# Genera coverage matrix: si un dominio es crítico pero tiene 0 reflexiones → visible
#
# Uso:
#   bash helix-knowledge-map.sh              → mapa completo (tabla ASCII)
#   bash helix-knowledge-map.sh --gaps       → solo dominios con cobertura < 50%
#   bash helix-knowledge-map.sh --json       → salida JSON a knowledge-map.json
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
MEMORY_DIR="$GLOBAL_DIR/memory"
EVO_LOG="$MEMORY_DIR/evolution-log.txt"
HEURISTICS="$MEMORY_DIR/routing-heuristics.md"
DECAY_FILE="$MEMORY_DIR/decay-scores.json"
KNOWLEDGE_MAP="$MEMORY_DIR/knowledge-map.json"
MODE="${1:---full}"

export HELIX_EVO_LOG="${EVO_LOG}"
export HELIX_HEURISTICS="${HEURISTICS}"
export HELIX_DECAY_FILE="${DECAY_FILE}"
export HELIX_KNOWLEDGE_MAP="${KNOWLEDGE_MAP}"
export HELIX_MODE="${MODE}"

# Detectar si Qdrant está disponible
QDRANT_AVAILABLE=false
if curl -sf "http://localhost:6333/healthz" &>/dev/null; then
    QDRANT_AVAILABLE=true
fi
export HELIX_QDRANT_AVAILABLE="$QDRANT_AVAILABLE"

"${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, re, json, subprocess
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime

evo_log       = Path(os.environ['HELIX_EVO_LOG'])
heuristics_f  = Path(os.environ['HELIX_HEURISTICS'])
decay_file    = Path(os.environ['HELIX_DECAY_FILE'])
knowledge_map = Path(os.environ['HELIX_KNOWLEDGE_MAP'])
mode          = os.environ.get('HELIX_MODE', '--full')
qdrant_ok     = os.environ.get('HELIX_QDRANT_AVAILABLE', 'false') == 'true'
now_str       = datetime.now().strftime('%Y-%m-%d %H:%M')

# ── Dominios canónicos con peso de criticidad ─────────────────
DOMAINS = {
    'seguridad':      {'weight': 1.0, 'label': 'Seguridad/Auth',     'emoji': '🔒'},
    'auth':           {'weight': 1.0, 'label': 'Autenticación',       'emoji': '🔑'},
    'arquitectura':   {'weight': 0.9, 'label': 'Arquitectura',        'emoji': '🏗️'},
    'operatividad':   {'weight': 0.85,'label': 'Operatividad',        'emoji': '⚙️'},
    'performance':    {'weight': 0.8, 'label': 'Performance',         'emoji': '⚡'},
    'datos':          {'weight': 0.75,'label': 'Datos/DB',            'emoji': '🗄️'},
    'funcionalidad':  {'weight': 0.7, 'label': 'Funcionalidad',       'emoji': '🧩'},
    'testing':        {'weight': 0.7, 'label': 'Testing',             'emoji': '🧪'},
    'interfaz':       {'weight': 0.65,'label': 'Interfaz/UX',         'emoji': '🎨'},
    'celery':         {'weight': 0.6, 'label': 'Celery/Workers',      'emoji': '⚗️'},
    'docker':         {'weight': 0.6, 'label': 'Docker/Infra',        'emoji': '🐳'},
}

# ── 1. Learnings por dominio (evolution-log) ──────────────────
learnings = defaultdict(list)  # dominio → [líneas]
avg_decay  = defaultdict(list)  # dominio → [scores]

if evo_log.exists():
    for line in evo_log.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        for domain in DOMAINS:
            if f'[{domain}]' in line:
                learnings[domain].append(line)
                break

# Incorporar decay scores si existen
if decay_file.exists():
    try:
        decay_data = json.loads(decay_file.read_text())
        for entry in decay_data.get('entries', []):
            line = entry.get('line', '')
            for domain in DOMAINS:
                if f'[{domain}]' in line:
                    avg_decay[domain].append(entry.get('score', 50))
                    break
    except Exception:
        pass

# ── 2. Heurísticas confirmadas por dominio (routing-heuristics) ──
heuristics_count = defaultdict(int)
if heuristics_f.exists():
    content = heuristics_f.read_text()
    for domain in DOMAINS:
        # Contar menciones en secciones de dominancia confirmada
        count = len(re.findall(rf"dominio '{re.escape(domain)}'", content))
        count += len(re.findall(rf"\[{re.escape(domain)}\]", content))
        heuristics_count[domain] = min(count, 5)  # cap a 5 para normalizar

# ── 3. Reflexiones en Qdrant por dominio ─────────────────────
reflexions_count = defaultdict(int)
if qdrant_ok:
    try:
        # Usar helix-reflexion.sh list y parsear output
        result = subprocess.run(
            ['bash', str(Path.home() / '.claude/helpers/helix-reflexion.sh'), 'list'],
            capture_output=True, text=True, timeout=10
        )
        for line in result.stdout.splitlines():
            for domain in DOMAINS:
                if domain in line.lower():
                    reflexions_count[domain] += 1
                    break
    except Exception:
        pass

# ── 4. Calcular score de cobertura por dominio ───────────────
# Cobertura = f(learnings, heurísticas, reflexiones, decay_score)
# Escala 0-100
def coverage_score(domain):
    l_count  = len(learnings[domain])
    h_count  = heuristics_count[domain]
    r_count  = reflexions_count[domain]
    d_scores = avg_decay[domain]
    d_avg    = sum(d_scores) / len(d_scores) if d_scores else 50

    # Puntos: learnings (max 40), heurísticas (max 30), reflexiones (max 20), decay (max 10)
    l_pts = min(40, l_count * 8)
    h_pts = min(30, h_count * 10)
    r_pts = min(20, r_count * 10)
    d_pts = d_avg * 0.10  # decay promedio normalizado

    return round(l_pts + h_pts + r_pts + d_pts, 1)

# ── 5. Construir mapa ────────────────────────────────────────
map_entries = []
for domain, meta in DOMAINS.items():
    cov = coverage_score(domain)
    l_n = len(learnings[domain])
    h_n = heuristics_count[domain]
    r_n = reflexions_count[domain]
    d_avg = round(sum(avg_decay[domain]) / len(avg_decay[domain]), 1) if avg_decay[domain] else 0
    weight = meta['weight']

    # Gap score: dominios críticos con baja cobertura tienen mayor urgencia
    gap = round((1 - cov / 100) * weight * 100, 1)
    status = (
        'critical' if cov < 30 and weight >= 0.8 else
        'gap'      if cov < 50 else
        'partial'  if cov < 75 else
        'healthy'
    )

    map_entries.append({
        'domain':     domain,
        'label':      meta['label'],
        'emoji':      meta['emoji'],
        'weight':     weight,
        'coverage':   cov,
        'gap_score':  gap,
        'learnings':  l_n,
        'heuristics': h_n,
        'reflexions': r_n,
        'decay_avg':  d_avg,
        'status':     status,
    })

map_entries.sort(key=lambda x: (-x['gap_score'], -x['weight']))

# ── Guardar JSON ─────────────────────────────────────────────
knowledge_map.parent.mkdir(parents=True, exist_ok=True)
output = {
    'generated':     now_str,
    'qdrant':        qdrant_ok,
    'total_domains': len(map_entries),
    'critical_gaps': sum(1 for e in map_entries if e['status'] == 'critical'),
    'gaps':          sum(1 for e in map_entries if e['status'] == 'gap'),
    'healthy':       sum(1 for e in map_entries if e['status'] == 'healthy'),
    'domains':       map_entries,
}
knowledge_map.write_text(json.dumps(output, indent=2, ensure_ascii=False))

# ── Output ───────────────────────────────────────────────────
BLUE   = '\033[0;34m'; GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'; RED    = '\033[0;31m'; GRAY = '\033[0;37m'; NC = '\033[0m'
BOLD   = '\033[1m'

def bar(score, width=12):
    filled = int(score / 100 * width)
    return '█' * filled + '░' * (width - filled)

def status_color(status):
    return {
        'critical': RED,
        'gap':      YELLOW,
        'partial':  BLUE,
        'healthy':  GREEN,
    }.get(status, GRAY)

if mode == '--json':
    print(knowledge_map)
    raise SystemExit(0)

entries_to_show = map_entries
if mode == '--gaps':
    entries_to_show = [e for e in map_entries if e['status'] in ('critical', 'gap')]

print(f"\n{BLUE}{BOLD}⬡ Helix Knowledge Map — {now_str}{NC}")
print(f"  Qdrant: {'✓ online' if qdrant_ok else '✗ offline'}")
print(f"  Gaps críticos: {output['critical_gaps']}  |  Gaps: {output['gaps']}  |  Saludables: {output['healthy']}")
print()

# Header
print(f"  {BOLD}{'Dominio':<22} {'Cob':>4}  {'Coverage':<14} {'L':>3} {'H':>3} {'R':>3} {'Decay':>5}  Estado{NC}")
print(f"  {'─'*22} {'─':>4}  {'─'*14} {'─':>3} {'─':>3} {'─':>3} {'─':>5}  {'─'*8}")

for e in entries_to_show:
    col = status_color(e['status'])
    label = f"{e['emoji']} {e['label']}"[:22]
    cov_bar = bar(e['coverage'])
    status_label = {
        'critical': '🚨 CRÍTICO',
        'gap':      '⚠️  gap',
        'partial':  '🔵 parcial',
        'healthy':  '✅ ok',
    }.get(e['status'], e['status'])

    print(
        f"  {col}{label:<22}{NC} "
        f"{col}{e['coverage']:>4.0f}{NC}  "
        f"{col}{cov_bar:<14}{NC} "
        f"{e['learnings']:>3} "
        f"{e['heuristics']:>3} "
        f"{e['reflexions']:>3} "
        f"{e['decay_avg']:>5.0f}  "
        f"{col}{status_label}{NC}"
    )

print()
print(f"  Columnas: L=learnings · H=heurísticas · R=reflexiones · Decay=score medio")

# Recomendaciones
critical = [e for e in map_entries if e['status'] == 'critical']
gaps_list = [e for e in map_entries if e['status'] == 'gap']
if critical or gaps_list:
    print(f"\n  {YELLOW}💡 Acciones recomendadas:{NC}")
    for e in (critical + gaps_list)[:4]:
        if e['reflexions'] == 0:
            print(f"  · [{e['domain']}] Sin reflexiones — ejecutar helix-reflexion.sh store para errores resueltos")
        elif e['learnings'] < 2:
            print(f"  · [{e['domain']}] Solo {e['learnings']} learning(s) — registrar aprendizajes con evolve.sh")
        elif e['heuristics'] == 0:
            print(f"  · [{e['domain']}] Sin heurísticas — ejecutar helix-erl.sh para extraer de routing-feedback")

print(f"\n  → {knowledge_map}")
PYEOF

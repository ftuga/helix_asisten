#!/usr/bin/env bash
# helix-decay.sh — Confidence decay para evolution-log entries
# Calcula score de vigencia 0-100 para cada aprendizaje registrado
# Factores: recencia, confirmaciones, importancia del patrón, tipo de entrada
#
# Uso:
#   bash helix-decay.sh              → genera decay-scores.json + reporte
#   bash helix-decay.sh --stale      → solo muestra entradas con score < 30
#   bash helix-decay.sh --prune      → marca candidatos a deprecar en obsolete.md
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
MEMORY_DIR="$GLOBAL_DIR/memory"
EVO_LOG="$MEMORY_DIR/evolution-log.txt"
DECAY_FILE="$MEMORY_DIR/decay-scores.json"
OBSOLETE_FILE="$MEMORY_DIR/obsolete.md"
MODE="${1:---report}"

[[ ! -f "$EVO_LOG" ]] && echo "Sin evolution-log." >&2 && exit 0

export HELIX_EVO_LOG="$EVO_LOG"
export HELIX_DECAY_FILE="$DECAY_FILE"
export HELIX_OBSOLETE="$OBSOLETE_FILE"
export HELIX_MODE="$MODE"

python3 - <<'PYEOF'
import os, re, json
from datetime import datetime, timedelta
from pathlib import Path

evo_log      = Path(os.environ['HELIX_EVO_LOG'])
decay_file   = Path(os.environ['HELIX_DECAY_FILE'])
obsolete_file = Path(os.environ['HELIX_OBSOLETE'])
mode         = os.environ.get('HELIX_MODE', '--report')
today        = datetime.now()
now_str      = today.strftime('%Y-%m-%d %H:%M')

# ── Patrones de alto valor (no decaen) ───────────────────────
PERENNIAL = [
    r'set -euo pipefail', r'wc -l.*espaci', r'VAR=\$\(\(', r'pipefail',
    r'HELIX_MODE', r'swarm_init', r'agent_spawn', r'helix_control_total',
    r'scalar_one_or_none', r'PyJWT', r'sanitize.*git', r'PROJECT-CONTEXT',
    r'anchor.*secci', r'ACON', r'ERL', r'ExpeL', r'Reflexion',
    r'helix-metricas', r'routing.*heur', r'skill.*tracker',
]

# ── Patrones de bajo valor (decaen rápido) ───────────────────
EPHEMERAL = [
    r'\[VALIDATE\]', r'test.*prueba', r'prueba.*test',
    r'FORGET', r'ok \(nada', r'proyecto específico',
    r'9 routers', r'5 routers', r'router.*obsolet',  # detalles de proyecto
]

def recency_score(date_str: str) -> float:
    """Score 0-100 basado en antigüedad. Decae 1 punto por día hasta 60 días."""
    if not date_str:
        return 30.0
    try:
        # Intentar parsear fecha del string
        m = re.search(r'(\d{4}-\d{2}-\d{2})', date_str)
        if not m:
            return 30.0
        entry_date = datetime.strptime(m.group(1), '%Y-%m-%d')
        days_old = (today - entry_date).days
        if days_old < 0:
            return 100.0
        # Decaimiento: 100 → 40 en 60 días, luego 40 → 10 en los próximos 120
        if days_old <= 60:
            return max(40.0, 100.0 - days_old * 1.0)
        else:
            return max(10.0, 40.0 - (days_old - 60) * 0.25)
    except:
        return 30.0

def importance_score(line: str) -> float:
    """Score 0-100 por importancia del patrón."""
    # Perennial: siempre 90+
    for p in PERENNIAL:
        if re.search(p, line, re.IGNORECASE):
            return 90.0
    # Ephemeral: score base bajo
    for p in EPHEMERAL:
        if re.search(p, line, re.IGNORECASE):
            return 10.0
    # Por tipo de entrada
    if '[LEARN]' in line:
        base = 60.0
    elif '[CANDIDATE]' in line:
        base = 40.0
    elif '[SKILL]' in line:
        base = 70.0
    else:
        base = 30.0
    # Boost por categoría crítica
    if any(c in line for c in ['[seguridad]', '[arquitectura]', '[auth]']):
        base = min(100, base + 15)
    if any(c in line for c in ['[operatividad]', '[performance]']):
        base = min(100, base + 10)
    return base

def category_multiplier(line: str) -> float:
    """Multiplicador por categoría — seguridad y arquitectura decaen menos."""
    if '[seguridad]' in line or '[auth]' in line:
        return 1.3
    if '[arquitectura]' in line:
        return 1.2
    if '[operatividad]' in line:
        return 1.1
    if '[funcionalidad]' in line:
        return 0.9  # más específicos de proyecto, decaen más
    return 1.0

# ── Parsear entradas ─────────────────────────────────────────
entries = []
for line in evo_log.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith('#'):
        continue

    # Extraer timestamp
    m = re.match(r'\[(\d{4}-\d{2}-\d{2}[^\]]*)\]', line)
    date_str = m.group(1) if m else ''

    rec   = recency_score(date_str)
    imp   = importance_score(line)
    mult  = category_multiplier(line)

    # Score final: combinación ponderada
    final = min(100, ((rec * 0.4) + (imp * 0.6)) * mult)

    entries.append({
        'line':       line[:120],
        'date':       date_str[:10] if date_str else 'unknown',
        'recency':    round(rec, 1),
        'importance': round(imp, 1),
        'score':      round(final, 1),
        'stale':      final < 30,
        'candidate':  30 <= final < 50,
    })

# ── Guardar scores ───────────────────────────────────────────
decay_file.parent.mkdir(parents=True, exist_ok=True)
decay_data = {
    'generated': now_str,
    'total':     len(entries),
    'stale':     sum(1 for e in entries if e['stale']),
    'candidate': sum(1 for e in entries if e['candidate']),
    'healthy':   sum(1 for e in entries if not e['stale'] and not e['candidate']),
    'avg_score': round(sum(e['score'] for e in entries) / len(entries), 1) if entries else 0,
    'entries':   entries,
}
decay_file.write_text(json.dumps(decay_data, indent=2, ensure_ascii=False))

# ── Output ───────────────────────────────────────────────────
BLUE   = '\033[0;34m'; GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'; RED    = '\033[0;31m'; GRAY = '\033[0;37m'; NC = '\033[0m'

print(f"\n{BLUE}⬡ Helix Decay — {len(entries)} entradas evaluadas{NC}")
print(f"  Saludables:  {decay_data['healthy']}  (score ≥ 50)")
print(f"  Candidatos:  {decay_data['candidate']}  (30–49)")
print(f"  Obsoletas:   {decay_data['stale']}  (< 30)")
print(f"  Score medio: {decay_data['avg_score']}/100")

if mode in ('--stale', '--prune'):
    stale = [e for e in entries if e['stale'] or e['candidate']]
    if not stale:
        print(f"\n  {GREEN}✅ Sin entradas obsoletas detectadas{NC}")
    else:
        print(f"\n  {YELLOW}Entradas de baja vigencia:{NC}")
        for e in sorted(stale, key=lambda x: x['score'])[:15]:
            color = RED if e['stale'] else YELLOW
            print(f"  {color}[{e['score']:4.0f}]{NC} [{e['date']}] {e['line'][:80]}")

if mode == '--prune':
    stale_entries = [e for e in entries if e['stale']]
    if stale_entries:
        # Escribir en obsolete.md para revisión manual
        with open(obsolete_file, 'a') as f:
            f.write(f"\n## Candidatos a deprecar — {now_str}\n")
            for e in stale_entries:
                f.write(f"- [score {e['score']:.0f}] {e['line'][:100]}\n")
        print(f"\n  {YELLOW}{len(stale_entries)} entradas escritas en obsolete.md para revisión{NC}")
        print(f"  Revisar y confirmar antes de eliminar del evolution-log")
    else:
        print(f"\n  {GREEN}✅ Sin candidatos para deprecar{NC}")

print(f"  → {decay_file}")
PYEOF

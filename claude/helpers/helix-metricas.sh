#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-metricas.sh — Evaluar salud de Helix desde señales observables
# Uso: bash helix-metricas.sh [PROJECT_ROOT]
# Output: JSON con scores, problemas y flag de alerta
set -uo pipefail

PROJECT="${1:-}"
GLOBAL_DIR="$HOME/.claude"

# Detectar proyecto si no se pasó
if [[ -z "$PROJECT" ]]; then
  dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" && "$dir" != "$GLOBAL_DIR" ]]; then
      PROJECT="$dir"; break
    fi
    dir=$(dirname "$dir")
  done
fi

# Pasar todo a Python — más limpio que mezclar bash arrays + JSON
export HELIX_PROJECT="$PROJECT"
export HELIX_GLOBAL="$GLOBAL_DIR"

"${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, json, re
from datetime import datetime, timedelta
from pathlib import Path

project   = os.environ.get('HELIX_PROJECT', '')
global_dir = Path(os.environ.get('HELIX_GLOBAL', Path.home() / '.claude'))
today     = datetime.now()

# ── helpers ──────────────────────────────────────────────────
def count_files(path, pattern='*.md'):
    p = Path(path)
    return len(list(p.glob(pattern))) if p.exists() else 0

def file_age_days(path):
    p = Path(path)
    if not p.exists(): return None
    return int((today.timestamp() - p.stat().st_mtime) / 86400)

# ════════════════════════════════════════════════════════════
# DIMENSIÓN 1: CONTEXTO
# ════════════════════════════════════════════════════════════
prob_ctx = []
score_ctx = 100

claude_md = global_dir / 'CLAUDE.md'
lines = len(claude_md.read_text().splitlines()) if claude_md.exists() else 0
if lines > 400:
    prob_ctx.append(f"CLAUDE.md en {lines} líneas — CRÍTICO (límite: 350). Ejecutar /helix-actualiza.")
    score_ctx -= 40
elif lines > 350:
    prob_ctx.append(f"CLAUDE.md en {lines} líneas — elevado (límite: 350)")
    score_ctx -= 20

if project:
    analysis = Path(project) / '.claude/memory/helix-analysis.md'
    age = file_age_days(analysis)
    if age is None:
        prob_ctx.append("Sin análisis guardado. Ejecutar /helix-analiza.")
        score_ctx -= 15
    elif age > 30:
        prob_ctx.append(f"Análisis tiene {age} días (límite: 30). Ejecutar /helix-actualiza.")
        score_ctx -= 25

# ════════════════════════════════════════════════════════════
# DIMENSIÓN 2: CALIDAD
# ════════════════════════════════════════════════════════════
prob_cal = []
score_cal = 100

if project:
    bitacora = Path(project) / '.claude/memory/helix-bitacora.md'
    if bitacora.exists():
        text = bitacora.read_text()
        cutoff = today - timedelta(days=30)

        # Errores recientes
        errores = 0
        in_errores = False
        for line in text.splitlines():
            if '🐛 Errores' in line: in_errores = True
            if in_errores and line.startswith('## ') and '🐛' not in line: in_errores = False
            if in_errores and line.startswith('|') and 'Fecha' not in line and '---' not in line:
                m = re.search(r'\| (\d{4}-\d{2}-\d{2})', line)
                if m:
                    try:
                        if datetime.strptime(m.group(1), '%Y-%m-%d') >= cutoff:
                            errores += 1
                    except: pass

        if errores > 5:
            prob_cal.append(f"{errores} errores en bitácora (últimos 30 días) — patrón preocupante")
            score_cal -= 40
        elif errores > 2:
            prob_cal.append(f"{errores} errores en bitácora (últimos 30 días)")
            score_cal -= 15

        # Recomendaciones pendientes
        pendientes = text.lower().count('pendiente')
        if pendientes > 5:
            prob_cal.append(f"{pendientes} recomendaciones sin implementar — revisar con el usuario")
            score_cal -= 25
        elif pendientes > 2:
            prob_cal.append(f"{pendientes} recomendaciones pendientes")
            score_cal -= 10

# ════════════════════════════════════════════════════════════
# DIMENSIÓN 3: OVERHEAD
# ════════════════════════════════════════════════════════════
prob_ovh = []
score_ovh = 100

agentes = count_files(global_dir / 'agents')
if agentes > 20:
    prob_ovh.append(f"{agentes} agentes activos — evaluar cuáles usa realmente este proyecto")
    score_ovh -= 20

skills = count_files(global_dir / 'skills')
if skills > 50:
    prob_ovh.append(f"{skills} skills globales — revisar relevancia para proyectos activos")
    score_ovh -= 15

# Sesiones sin evolución hoy
session_log = global_dir / 'memory/session-log.txt'
evo_log     = global_dir / 'memory/evolution-log.txt'
if session_log.exists() and evo_log.exists():
    hoy = today.strftime('%Y-%m-%d')
    mes = today.strftime('%Y-%m')
    sesiones_mes = sum(1 for l in session_log.read_text().splitlines() if mes in l)
    aprendizajes_hoy = sum(1 for l in evo_log.read_text().splitlines() if hoy in l and '[LEARN]' in l)
    if sesiones_mes > 10 and aprendizajes_hoy == 0:
        prob_ovh.append(f"{sesiones_mes} sesiones este mes — 0 aprendizajes registrados hoy")
        score_ovh -= 15

# ════════════════════════════════════════════════════════════
# DIMENSIÓN 4: ROUTING (Fase 2 — solo si hay feedback)
# ════════════════════════════════════════════════════════════
prob_rt = []
score_rt = 100
routing_metrics = {}

feedback_path = global_dir / 'memory/routing-feedback.jsonl'
if feedback_path.exists():
    from collections import Counter
    project_name = os.path.basename(project) if project else None
    cutoff_30d = today - timedelta(days=30)
    counter = Counter()
    project_counter = Counter()

    with feedback_path.open() as fh:
        for line in fh:
            try:
                e = json.loads(line)
            except Exception:
                continue
            ts = e.get('ts') or e.get('timestamp') or ''
            try:
                d = datetime.fromisoformat(ts.split(' ')[0]) if ts else None
                if d and d < cutoff_30d:
                    continue
            except Exception:
                pass
            a = e.get('agente') or e.get('agent')
            if not a:
                continue
            counter[a] += 1
            proj = e.get('proyecto') or e.get('project') or ''
            if project_name and proj == project_name:
                project_counter[a] += 1

    total_global = sum(counter.values())
    if total_global > 0:
        top3 = counter.most_common(3)
        top3_share = sum(c for _, c in top3) / total_global
        agentes_dir = global_dir / 'agents'
        all_agents = [f.stem for f in agentes_dir.glob('*.md')] if agentes_dir.exists() else []
        coverage = len(counter) / max(len(all_agents), 1)
        never_used = len([a for a in all_agents if a not in counter])

        routing_metrics['global_30d'] = {
            'total_invocations': total_global,
            'unique_agents': len(counter),
            'coverage_ratio': round(coverage, 3),
            'top3_saturation': round(top3_share, 3),
            'top3': [{'agent': a, 'count': c} for a, c in top3],
            'never_used_count': never_used,
        }
        if top3_share >= 0.5:
            prob_rt.append(f"top-3 agentes acumulan {int(top3_share*100)}% invocaciones (BIASED — objetivo <50%)")
            score_rt -= 25
        if coverage < 0.3:
            prob_rt.append(f"cobertura de catálogo {int(coverage*100)}% — {never_used} agentes nunca usados")
            score_rt -= 20

    # Stack coverage del proyecto
    if project:
        stack_file = Path(project) / '.claude/memory/helix-stack.md'
        if stack_file.is_file():
            content = stack_file.read_text()
            def get_list_sm(key):
                m = re.search(rf"({key}:\s*\n)((?:    - .*\n)*)", content)
                return re.findall(r"    - (.+)", m.group(2)) if m else []
            stack_set = set(get_list_sm('core')) | set(get_list_sm('extended'))
            project_total = sum(project_counter.values())
            if project_total > 0 and stack_set:
                in_stack = sum(c for a, c in project_counter.items() if a in stack_set)
                stack_cov = in_stack / project_total
                routing_metrics['project_stack'] = {
                    'project_invocations_30d': project_total,
                    'stack_coverage': round(stack_cov, 3),
                    'invocations_outside_stack': project_total - in_stack,
                }
                if stack_cov < 0.7:
                    prob_rt.append(f"solo {int(stack_cov*100)}% de invocaciones del proyecto cayeron en stack — drift")
                    score_rt -= 20

# ════════════════════════════════════════════════════════════
# SCORE FINAL Y ALERTA
# ════════════════════════════════════════════════════════════
alerta = score_ctx < 60 or score_cal < 60 or score_ovh < 60 or score_rt < 60

todos_problemas = prob_ctx + prob_cal + prob_ovh + prob_rt

result = {
    "fecha":    today.strftime('%Y-%m-%d %H:%M'),
    "proyecto": project or "sin-proyecto",
    "scores": {
        "contexto":  {"valor": max(score_ctx, 0), "ok": score_ctx >= 60, "problemas": prob_ctx},
        "calidad":   {"valor": max(score_cal, 0), "ok": score_cal >= 60, "problemas": prob_cal},
        "overhead":  {"valor": max(score_ovh, 0), "ok": score_ovh >= 60, "problemas": prob_ovh},
        "routing":   {"valor": max(score_rt, 0), "ok": score_rt >= 60, "problemas": prob_rt, "metrics": routing_metrics},
    },
    "alerta":          alerta,
    "total_problemas": len(todos_problemas),
    "claude_md_lineas": lines,
    "agentes_activos":  agentes,
    "skills_total":     skills,
}

print(json.dumps(result, indent=2, ensure_ascii=False))
PYEOF

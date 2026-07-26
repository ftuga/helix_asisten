#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-cache-metrics.sh — Mide cache-hit rate del prompt cache de Anthropic.
# Lee logs de Claude Code (~/.claude/projects/*/*.jsonl) y calcula ratios.
# Uso: bash helix-cache-metrics.sh [--last-n 100] [--project <name>]
set -uo pipefail

LAST_N="${LAST_N:-200}"
FILTER_PROJECT=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --last-n) LAST_N="$2"; shift 2 ;;
    --project) FILTER_PROJECT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

export HELIX_LAST_N="$LAST_N" HELIX_PROJECT="$FILTER_PROJECT"

"${HELIX_PYTHON:-python3}" <<'PYEOF'
import os, json, glob
from pathlib import Path
from collections import defaultdict

LAST_N = int(os.environ.get("HELIX_LAST_N", 200))
PROJ   = os.environ.get("HELIX_PROJECT", "")
HOME   = Path.home()

# Logs de conversaciones en projects/ — del árbol de config ACTIVO, no del histórico
CONFIG_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(HOME / ".claude")))
sessions_dir = CONFIG_DIR / "projects"
if not sessions_dir.exists():
    print(f"No hay logs en {sessions_dir}/"); raise SystemExit(0)

# Filtra por proyecto si corresponde
if PROJ:
    pattern = f"*{PROJ}*/*.jsonl"
else:
    pattern = "*/*.jsonl"

files = sorted(sessions_dir.glob(pattern), key=lambda p: p.stat().st_mtime, reverse=True)
if not files:
    print(f"No hay archivos para patrón {pattern}"); raise SystemExit(0)

# Acumular métricas de los últimos N API calls (por archivo, no por línea).
calls = 0
totals = {
    "cache_creation_input_tokens": 0,
    "cache_read_input_tokens": 0,
    "input_tokens": 0,
    "output_tokens": 0,
}
by_project = defaultdict(lambda: dict(totals))
by_project_calls = defaultdict(int)

for fp in files:
    project_name = fp.parent.name
    try:
        with open(fp) as f:
            for line in f:
                if calls >= LAST_N: break
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                # Claude Code format: message.usage contiene los contadores
                usage = (d.get("message") or {}).get("usage")
                if not usage: continue
                calls += 1
                by_project_calls[project_name] += 1
                for k in totals:
                    v = usage.get(k, 0) or 0
                    totals[k] += v
                    by_project[project_name][k] += v
        if calls >= LAST_N: break
    except Exception:
        continue

if calls == 0:
    print("Sin datos de usage en los logs — versión antigua de Claude Code o sin actividad.")
    raise SystemExit(0)

def ratio(num, den):
    return (num / den * 100) if den else 0.0

input_total = totals["input_tokens"] + totals["cache_read_input_tokens"] + totals["cache_creation_input_tokens"]
hit_rate = ratio(totals["cache_read_input_tokens"], input_total)
miss_rate = ratio(totals["input_tokens"], input_total)
create_rate = ratio(totals["cache_creation_input_tokens"], input_total)

# Estimación de ahorro vs sin cache
# Anthropic Opus pricing: input $15/MTok, cache_read $1.50/MTok, cache_write $18.75/MTok (5m)
# Dif vs no-cache: cache_read ahorra 90%, cache_write cuesta 25% extra
reads = totals["cache_read_input_tokens"]
creates = totals["cache_creation_input_tokens"]
# Ahorro estimado (approx):
savings_tokens = reads * 0.90 - creates * 0.25
savings_pct = ratio(savings_tokens, input_total) if input_total else 0

GREEN = "\033[0;32m"; BLUE = "\033[0;34m"; YELLOW = "\033[0;33m"; RED = "\033[0;31m"; NC = "\033[0m"

print(f"\n{BLUE}⬡ Helix Cache Metrics — últimas {calls} API calls{NC}")
print(f"{BLUE}─" * 60 + NC)
print(f"  Tokens totales input (incl. cache): {input_total:>12,}")
print(f"  • Fresh input                      : {totals['input_tokens']:>12,}  ({miss_rate:5.1f}% miss)")
print(f"  • {GREEN}Cache read{NC}                       : {reads:>12,}  ({hit_rate:5.1f}% hit)")
print(f"  • Cache creation                   : {creates:>12,}  ({create_rate:5.1f}% write)")
print(f"  Output tokens                      : {totals['output_tokens']:>12,}")
print()

# Evaluación heurística
if hit_rate >= 60:
    verdict = f"{GREEN}✅ Cache funcionando bien — considerar sostener patrones estables{NC}"
elif hit_rate >= 30:
    verdict = f"{YELLOW}⚠️  Cache mediano — CLAUDE.md o system prompt quizá cambia demasiado{NC}"
else:
    verdict = f"{RED}🚨 Cache muy bajo — revisar estabilidad de system prompt (CLAUDE.md, tool defs){NC}"
print(f"  Hit rate: {hit_rate:.1f}%  → {verdict}")
print(f"  Ahorro estimado de tokens: ~{savings_pct:.1f}%  ({savings_tokens:,.0f} tokens)")

# Top 5 proyectos por calls
print(f"\n{BLUE}  Top proyectos por actividad:{NC}")
top = sorted(by_project_calls.items(), key=lambda x: -x[1])[:5]
for proj, n in top:
    p_reads = by_project[proj]["cache_read_input_tokens"]
    p_total = sum(by_project[proj][k] for k in ("input_tokens","cache_read_input_tokens","cache_creation_input_tokens"))
    p_hit = ratio(p_reads, p_total)
    print(f"    {proj[:40]:<40} {n:>4} calls  hit={p_hit:5.1f}%")

print()
PYEOF

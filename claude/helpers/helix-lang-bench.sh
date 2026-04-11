#!/usr/bin/env bash
# helix-lang-bench.sh — Benchmark y análisis de efectividad de HELIX-LANG
# Uso:
#   log    "NL message" "HL message"        → registra un par para análisis
#   decode "HL message" "NL decoded"        → registra una decodificación
#   report [--limit N] [--detail]           → estadísticas de efectividad
#   test   "NL message"                     → estima compresión sin loggear
#   reset                                   → limpia el log (con confirmación)
set -uo pipefail

BENCH_LOG="$HOME/.claude/data/helix-lang.jsonl"
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; GRAY='\033[0;37m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

cmd="${1:-report}"
shift || true

# ─── Estimación de tokens (aproximación BPE) ──────────────────────────────
_estimate_tokens() {
  local text="$1"
  python3 - "$text" <<'PYEOF'
import sys, re

text = sys.argv[1]

# Detectar si es HL (código-like) o NL (lenguaje natural)
# HL: alta densidad de operadores y códigos cortos
hl_patterns = len(re.findall(r'(->|<-|=>|<>|:\w|%\d+|\.\w{2,6}|@\w+|\{|\})', text))
words = len(text.split())
hl_ratio = hl_patterns / max(words, 1)

if hl_ratio > 0.3:
    # HL: sintaxis código — ~3.2 chars/token (Claude entrenado en código)
    tokens = max(1, len(text) / 3.2)
else:
    # NL: lenguaje natural — ~4.0 chars/token inglés, ~3.5 español
    tokens = max(1, len(text) / 3.7)

print(f"{tokens:.1f}")
PYEOF
}

# ─── Comando: log ──────────────────────────────────────────────────────────
if [[ "$cmd" == "log" ]]; then
  NL="${1:-}"
  HL="${2:-}"

  if [[ -z "$NL" || -z "$HL" ]]; then
    echo -e "${RED}[HL-BENCH]${NC} Uso: helix-lang-bench.sh log \"NL message\" \"HL message\""
    exit 1
  fi

  nl_tokens=$(_estimate_tokens "$NL")
  hl_tokens=$(_estimate_tokens "$HL")
  nl_chars=${#NL}
  hl_chars=${#HL}

  ratio=$(python3 -c "
nl=$nl_tokens; hl=$hl_tokens
if nl > 0:
    ratio = (nl - hl) / nl * 100
    print(f'{ratio:.1f}')
else:
    print('0.0')
")

  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  session="${HELIX_SESSION_ID:-$(date +%s)}"

  entry=$(python3 -c "
import json, sys
print(json.dumps({
    'ts': '$ts',
    'type': 'encode',
    'nl': sys.argv[1],
    'hl': sys.argv[2],
    'nl_tokens': float('$nl_tokens'),
    'hl_tokens': float('$hl_tokens'),
    'nl_chars': $nl_chars,
    'hl_chars': $hl_chars,
    'savings_pct': float('$ratio'),
    'session': '$session'
}))" "$NL" "$HL")

  echo "$entry" >> "$BENCH_LOG"

  echo -e "${GREEN}[HL-BENCH]${NC} Registrado — compresión estimada: ${BOLD}${ratio}%${NC} (${nl_chars}→${hl_chars} chars | ~${nl_tokens}→~${hl_tokens} tokens)"

# ─── Comando: decode ───────────────────────────────────────────────────────
elif [[ "$cmd" == "decode" ]]; then
  HL="${1:-}"
  DECODED="${2:-}"

  if [[ -z "$HL" || -z "$DECODED" ]]; then
    echo -e "${RED}[HL-BENCH]${NC} Uso: helix-lang-bench.sh decode \"HL message\" \"decoded NL\""
    exit 1
  fi

  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  session="${HELIX_SESSION_ID:-$(date +%s)}"

  entry=$(python3 -c "
import json, sys
print(json.dumps({
    'ts': '$ts',
    'type': 'decode',
    'hl': sys.argv[1],
    'decoded': sys.argv[2],
    'session': '$session'
}))" "$HL" "$DECODED")

  echo "$entry" >> "$BENCH_LOG"
  echo -e "${GREEN}[HL-BENCH]${NC} Decodificación registrada."

# ─── Comando: test (estimación rápida sin loggear) ─────────────────────────
elif [[ "$cmd" == "test" ]]; then
  NL="${1:-}"
  if [[ -z "$NL" ]]; then
    echo -e "${RED}[HL-BENCH]${NC} Uso: helix-lang-bench.sh test \"NL message\""
    exit 1
  fi

  nl_tokens=$(_estimate_tokens "$NL")
  nl_chars=${#NL}

  echo -e "${CYAN}[HL-BENCH]${NC} Mensaje NL analizado:"
  echo -e "  Chars: ${nl_chars} | Tokens est.: ${nl_tokens}"
  echo ""
  echo -e "  Proyección de ahorro (basado en promedios históricos):"

  python3 - "$nl_tokens" "$BENCH_LOG" <<'PYEOF'
import sys, json
from pathlib import Path

nl_tokens = float(sys.argv[1])
log_path = sys.argv[2]

# Calcular ratio histórico promedio
log = Path(log_path)
if log.exists() and log.stat().st_size > 0:
    entries = [json.loads(l) for l in log.read_text().strip().split('\n') if l]
    encodes = [e for e in entries if e.get('type') == 'encode']
    if encodes:
        avg_ratio = sum(e['savings_pct'] for e in encodes) / len(encodes)
        est_hl = nl_tokens * (1 - avg_ratio/100)
        print(f"  Ratio histórico promedio: {avg_ratio:.1f}%")
        print(f"  Tokens estimados en HL: ~{est_hl:.1f} (vs {nl_tokens:.1f} NL)")
        sys.exit(0)

# Sin historial → usar proyección teórica
for pct, label in [(60, 'conservador'), (75, 'esperado'), (85, 'óptimo')]:
    est = nl_tokens * (1 - pct/100)
    print(f"  {pct}% ({label}): ~{est:.1f} tokens HL vs {nl_tokens:.1f} NL")
PYEOF

# ─── Comando: report ───────────────────────────────────────────────────────
elif [[ "$cmd" == "report" ]]; then
  limit="${1:-all}"
  detail="${2:-}"

  if [[ ! -f "$BENCH_LOG" ]] || [[ ! -s "$BENCH_LOG" ]]; then
    echo -e "${YELLOW}[HL-BENCH]${NC} Sin datos aún. Usar 'log' para registrar pares NL→HL."
    exit 0
  fi

  python3 - "$BENCH_LOG" "$limit" "$detail" <<'PYEOF'
import sys, json, statistics
from pathlib import Path
from datetime import datetime, timezone

log_path = sys.argv[1]
limit = sys.argv[2]
detail = sys.argv[3] if len(sys.argv) > 3 else ""

entries = [json.loads(l) for l in Path(log_path).read_text().strip().split('\n') if l]
encodes = [e for e in entries if e.get('type') == 'encode']
decodes = [e for e in entries if e.get('type') == 'decode']

if not encodes:
    print("Sin pares encode registrados aún.")
    sys.exit(0)

# Aplicar limit
if limit != "all":
    try:
        encodes = encodes[-int(limit):]
    except ValueError:
        pass

ratios = [e['savings_pct'] for e in encodes]
nl_total = sum(e['nl_tokens'] for e in encodes)
hl_total = sum(e['hl_tokens'] for e in encodes)
chars_nl = sum(e['nl_chars'] for e in encodes)
chars_hl = sum(e['hl_chars'] for e in encodes)
saved_tokens = nl_total - hl_total

GREEN = '\033[0;32m'; BLUE = '\033[0;34m'; YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'; BOLD = '\033[1m'; RED = '\033[0;31m'; GRAY = '\033[0;37m'; NC = '\033[0m'

print(f"\n{BOLD}{'='*55}{NC}")
print(f"{BOLD}  HELIX-LANG — Reporte de Efectividad{NC}")
print(f"{'='*55}")
print(f"  Pares analizados : {len(encodes)}")
print(f"  Decodificaciones : {len(decodes)}")
print()

# Métricas de compresión
avg = statistics.mean(ratios)
med = statistics.median(ratios)
stdev = statistics.stdev(ratios) if len(ratios) > 1 else 0
best = max(encodes, key=lambda e: e['savings_pct'])
worst = min(encodes, key=lambda e: e['savings_pct'])

color = GREEN if avg >= 70 else (YELLOW if avg >= 50 else RED)
print(f"{BOLD}  Compresión de tokens{NC}")
print(f"  Promedio   : {color}{avg:.1f}%{NC}  (σ={stdev:.1f})")
print(f"  Mediana    : {med:.1f}%")
print(f"  Mejor caso : {GREEN}{best['savings_pct']:.1f}%{NC}")
print(f"  Peor caso  : {RED}{worst['savings_pct']:.1f}%{NC}")
print()
print(f"{BOLD}  Tokens totales{NC}")
print(f"  NL total   : ~{nl_total:.0f} tokens")
print(f"  HL total   : ~{hl_total:.0f} tokens")
print(f"  Ahorrados  : {GREEN}~{saved_tokens:.0f} tokens{NC}")
print()
print(f"{BOLD}  Chars totales{NC}")
print(f"  NL→HL     : {chars_nl} → {chars_hl} chars")
print(f"  Reducción  : {(1-chars_hl/chars_nl)*100:.1f}%")

# Evaluación del protocolo
print(f"\n{BOLD}  Evaluación del protocolo{NC}")
if avg >= 75:
    print(f"  {GREEN}✓ EFECTIVO{NC} — Superando objetivo del 75%")
elif avg >= 60:
    print(f"  {YELLOW}~ ACEPTABLE{NC} — Por debajo del objetivo (75%). Revisar casos.")
else:
    print(f"  {RED}✗ BAJO RENDIMIENTO{NC} — Requiere revisión del diseño")

# Tendencia (últimos 5 vs anteriores)
if len(ratios) >= 6:
    old_avg = statistics.mean(ratios[:-5])
    new_avg = statistics.mean(ratios[-5:])
    trend = new_avg - old_avg
    arrow = "↑" if trend > 0 else "↓"
    color = GREEN if trend > 0 else RED
    print(f"  Tendencia  : {color}{arrow} {abs(trend):.1f}%{NC} vs promedio anterior")

# Recomendaciones
print(f"\n{BOLD}  Recomendaciones{NC}")
low_cases = [e for e in encodes if e['savings_pct'] < 50]
if low_cases:
    print(f"  {YELLOW}!{NC} {len(low_cases)} pares con compresión <50% — revisar si aplica HL")
if avg < 75:
    deficit = 75 - avg
    print(f"  {YELLOW}!{NC} Déficit de {deficit:.1f}% respecto al objetivo — considerar:")
    print(f"      · Expandir vocabulario de dominios")
    print(f"      · Usar más composición con {{}} y +")
    print(f"      · Revisar si los mensajes NL se pueden pre-comprimir")
if not low_cases and avg >= 75:
    print(f"  {GREEN}✓{NC} Sin acciones necesarias. Protocolo funcionando bien.")

# Detalle de pares (si se pidió)
if detail == "--detail":
    print(f"\n{BOLD}  Últimos 5 pares registrados{NC}")
    for e in encodes[-5:]:
        ts = e['ts'][:10]
        ratio = e['savings_pct']
        color = GREEN if ratio >= 75 else (YELLOW if ratio >= 50 else RED)
        print(f"\n  [{ts}] {color}{ratio:.0f}%{NC}")
        print(f"  NL: {e['nl'][:80]}{'...' if len(e['nl'])>80 else ''}")
        print(f"  HL: {e['hl'][:80]}{'...' if len(e['hl'])>80 else ''}")

print(f"\n{'='*55}\n")
PYEOF

# ─── Comando: report-hash (métricas de S:hash) ────────────────────────────
elif [[ "$cmd" == "report-hash" ]]; then
  if [[ ! -f "$BENCH_LOG" ]] || [[ ! -s "$BENCH_LOG" ]]; then
    echo -e "${YELLOW}[HL-BENCH]${NC} Sin datos de S:hash aún."
    exit 0
  fi

  python3 - "$BENCH_LOG" <<'PYEOF'
import sys, json, statistics
from pathlib import Path

log = Path(sys.argv[1])
entries = [json.loads(l) for l in log.read_text().strip().split('\n') if l]

snapshots = [e for e in entries if e.get('type') == 'snapshot']
deltas    = [e for e in entries if e.get('type') == 'delta']
encodes   = [e for e in entries if e.get('type') == 'encode']

GREEN = '\033[0;32m'; BOLD = '\033[1m'; YELLOW = '\033[1;33m'; CYAN = '\033[0;36m'; NC = '\033[0m'

print(f"\n{BOLD}{'='*55}{NC}")
print(f"{BOLD}  HELIX-LANG — Reporte S:hash{NC}")
print(f"{'='*55}")

total_state_tokens  = sum(e.get('state_tokens',0) for e in snapshots+deltas)
total_ref_tokens    = sum(e.get('ref_tokens',2)   for e in snapshots+deltas)
total_saved         = total_state_tokens - total_ref_tokens
hash_events         = len(snapshots) + len(deltas)

if hash_events > 0:
    hash_savings_pct = (total_saved / total_state_tokens * 100) if total_state_tokens else 0
    print(f"  Snapshots creados  : {len(snapshots)}")
    print(f"  Deltas aplicados   : {len(deltas)}")
    print(f"  Tokens en estados  : ~{total_state_tokens:.0f}")
    print(f"  Tokens si por ref  : ~{total_ref_tokens:.0f}")
    print(f"  Tokens ahorrados   : {GREEN}~{total_saved:.0f}{NC}")
    print(f"  Ahorro S:hash      : {GREEN}{hash_savings_pct:.1f}%{NC}")

# Combinado: mensajes + hash
if encodes and hash_events > 0:
    msg_saved   = sum(e['nl_tokens']-e['hl_tokens'] for e in encodes)
    msg_total   = sum(e['nl_tokens'] for e in encodes)
    total_nl    = msg_total + total_state_tokens
    total_hl    = (msg_total - msg_saved) + total_ref_tokens
    combined    = (total_nl - total_hl) / total_nl * 100
    print(f"\n{BOLD}  Ahorro combinado (mensajes + S:hash){NC}")
    print(f"  Tokens NL total    : ~{total_nl:.0f}")
    print(f"  Tokens HL total    : ~{total_hl:.0f}")
    color = GREEN if combined >= 75 else YELLOW
    print(f"  {BOLD}Ahorro total: {color}{combined:.1f}%{NC}")
    if combined >= 75:
        print(f"  {GREEN}✓ OBJETIVO 75% ALCANZADO{NC}")
    else:
        deficit = 75 - combined
        print(f"  {YELLOW}! Déficit de {deficit:.1f}% del objetivo{NC}")
else:
    print(f"\n  {YELLOW}Sin datos de mensajes para combinar.{NC}")

print(f"\n{'='*55}\n")
PYEOF

# ─── Comando: reset ────────────────────────────────────────────────────────
elif [[ "$cmd" == "reset" ]]; then
  if [[ ! -f "$BENCH_LOG" ]]; then
    echo -e "${GRAY}[HL-BENCH]${NC} No hay log que resetear."
    exit 0
  fi
  count=$(wc -l < "$BENCH_LOG" | tr -d '[:space:]')
  echo -e "${YELLOW}[HL-BENCH]${NC} ¿Eliminar ${count} entradas de ${BENCH_LOG}? [s/N]"
  read -r confirm
  if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
    rm "$BENCH_LOG"
    echo -e "${GREEN}[HL-BENCH]${NC} Log eliminado."
  else
    echo -e "${GRAY}[HL-BENCH]${NC} Cancelado."
  fi

else
  echo -e "${RED}[HL-BENCH]${NC} Comando desconocido: $cmd"
  echo "Uso: helix-lang-bench.sh [log|decode|test|report|reset]"
  exit 1
fi

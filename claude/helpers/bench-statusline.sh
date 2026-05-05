#!/usr/bin/env bash
# bench-statusline.sh — mide latencia de helix-statusline.sh sobre N runs.
#
# Uso:
#   bash claude/helpers/bench-statusline.sh                    # 10 runs warm
#   bash claude/helpers/bench-statusline.sh 20                 # 20 runs warm
#   bash claude/helpers/bench-statusline.sh 10 cold            # 10 runs limpiando cache cada vez
#
# Output: min / max / avg / p50 / p95 en milisegundos + tabla por run.
# Exit 0 siempre. Para CI: agregar threshold check a tu pipeline si querés.
#
# Reproducibilidad del fix v3.18.1 (Win 19s → 1.6s warm):
#   - Linux/Mac warm esperado: <200ms
#   - Linux/Mac cold esperado: <500ms
#   - Windows Git Bash warm:   <2000ms
#   - Windows Git Bash cold:   <5000ms

set -uo pipefail

RUNS="${1:-10}"
MODE="${2:-warm}"  # warm | cold

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || (( RUNS < 1 )); then
    echo "ERROR: RUNS debe ser entero positivo (recibido: $RUNS)" >&2
    exit 1
fi
if [[ "$MODE" != "warm" && "$MODE" != "cold" ]]; then
    echo "ERROR: MODE debe ser 'warm' o 'cold' (recibido: $MODE)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUSLINE="${SCRIPT_DIR}/helix-statusline.sh"
CACHE_DIR="${HELIX_DIR:-$HOME/.helix}/cache"

if [[ ! -x "$STATUSLINE" ]]; then
    echo "ERROR: no encuentro $STATUSLINE" >&2
    exit 2
fi

# JSON mínimo que el statusline acepta como stdin (mismo schema que Claude Code envía).
read -r -d '' INPUT_JSON <<'EOF' || true
{"display_name":"Claude","current_dir":"/home/lfrontuso/helix_asisten","context_window_used_pct":42,"cache_efficiency_pct":88}
EOF

declare -a TIMINGS

printf "Bench: %d runs (%s)\n" "$RUNS" "$MODE"
printf "Script: %s\n\n" "$STATUSLINE"
printf "%-5s %10s\n" "RUN" "MS"
printf "%-5s %10s\n" "---" "----"

for ((i=1; i<=RUNS; i++)); do
    if [[ "$MODE" == "cold" && -d "$CACHE_DIR" ]]; then
        rm -f "$CACHE_DIR"/statusline-*.txt 2>/dev/null
    fi

    # bash builtin: $EPOCHREALTIME = float seconds (5.0+). Fallback a date+ms.
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
        t0=$EPOCHREALTIME
        printf '%s' "$INPUT_JSON" | bash "$STATUSLINE" >/dev/null 2>&1
        t1=$EPOCHREALTIME
        ms=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.0f", (b-a)*1000}')
    else
        t0=$(date +%s%N)
        printf '%s' "$INPUT_JSON" | bash "$STATUSLINE" >/dev/null 2>&1
        t1=$(date +%s%N)
        ms=$(( (t1 - t0) / 1000000 ))
    fi

    TIMINGS+=("$ms")
    printf "%-5d %10d\n" "$i" "$ms"
done

# Stats: min/max/avg/p50/p95 — pure bash + 1 sort.
SORTED=$(printf '%s\n' "${TIMINGS[@]}" | sort -n)
MIN=$(printf '%s\n' "$SORTED" | head -1)
MAX=$(printf '%s\n' "$SORTED" | tail -1)

SUM=0
for v in "${TIMINGS[@]}"; do SUM=$((SUM + v)); done
AVG=$((SUM / RUNS))

# Percentiles (nearest-rank). p50 = ceil(0.5*N), p95 = ceil(0.95*N).
p50_idx=$(( (RUNS + 1) / 2 ))
p95_idx=$(( (RUNS * 95 + 99) / 100 ))
(( p95_idx > RUNS )) && p95_idx=$RUNS
P50=$(printf '%s\n' "$SORTED" | sed -n "${p50_idx}p")
P95=$(printf '%s\n' "$SORTED" | sed -n "${p95_idx}p")

printf "\n=== STATS (ms) ===\n"
printf "min:  %d\n" "$MIN"
printf "max:  %d\n" "$MAX"
printf "avg:  %d\n" "$AVG"
printf "p50:  %d\n" "$P50"
printf "p95:  %d\n" "$P95"
printf "runs: %d (%s)\n" "$RUNS" "$MODE"

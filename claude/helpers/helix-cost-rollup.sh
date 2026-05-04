#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-cost-rollup.sh — R2 cost-tracker v0.1
#
# Procesa transcripts JSONL de ~/.claude/projects/ y calcula USD real por
# modelo, sesión, proyecto. Usa precios públicos de Anthropic (Nov 2025).
#
# Modos:
#   session <sessionId>          USD de la sesión (lee transcript y suma)
#   current                      USD de la sesión actual (más reciente, cwd actual)
#   all                          rollup completo por modelo/proyecto
#   report                       genera ~/.claude/memory/topics/route-cost-audit.md
#
# Caché: ~/.claude/cache/cost-rollup-*.json TTL 30s (alineado con statusline).
#
# Sin egress, sin servicios externos. Datos solo de archivos locales.

set -uo pipefail

readonly HELIX_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
readonly PROJECTS_DIR="${HELIX_DIR}/projects"
readonly CACHE_DIR="${HELIX_DIR}/cache"
readonly REPORT_FILE="${HELIX_DIR}/memory/topics/route-cost-audit.md"
readonly CACHE_TTL=30

mkdir -p "$CACHE_DIR"

# Precios USD por millón de tokens (Anthropic public pricing 2025-11)
# Cache write = input × 1.25 ; cache read = input × 0.10
declare -A MODEL_INPUT_PRICE=(
    ["claude-opus-4-7"]="15.00"
    ["claude-opus-4-6"]="15.00"
    ["claude-opus-4"]="15.00"
    ["claude-sonnet-4-6"]="3.00"
    ["claude-sonnet-4-5"]="3.00"
    ["claude-sonnet-4"]="3.00"
    ["claude-haiku-4-5"]="1.00"
    ["claude-haiku-4"]="1.00"
)
declare -A MODEL_OUTPUT_PRICE=(
    ["claude-opus-4-7"]="75.00"
    ["claude-opus-4-6"]="75.00"
    ["claude-opus-4"]="75.00"
    ["claude-sonnet-4-6"]="15.00"
    ["claude-sonnet-4-5"]="15.00"
    ["claude-sonnet-4"]="15.00"
    ["claude-haiku-4-5"]="5.00"
    ["claude-haiku-4"]="5.00"
)

# ─────────────────────────────────────────────────────────────
# Cálculo de costo de un transcript completo (delegado a python)
# ─────────────────────────────────────────────────────────────
calc_transcript_cost() {
    local transcript="$1"
    [[ -f "$transcript" ]] || { echo "0.00|unknown|0|0|0|0"; return; }

    HELIX_TRANSCRIPT="$transcript" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import json, os, sys
from pathlib import Path

PRICES = {
    "claude-opus-4-7":   {"in": 15.00, "out": 75.00},
    "claude-opus-4-6":   {"in": 15.00, "out": 75.00},
    "claude-opus-4":     {"in": 15.00, "out": 75.00},
    "claude-sonnet-4-6": {"in": 3.00,  "out": 15.00},
    "claude-sonnet-4-5": {"in": 3.00,  "out": 15.00},
    "claude-sonnet-4":   {"in": 3.00,  "out": 15.00},
    "claude-haiku-4-5":  {"in": 1.00,  "out": 5.00},
    "claude-haiku-4":    {"in": 1.00,  "out": 5.00},
}

path = os.environ["HELIX_TRANSCRIPT"]
totals = {"in": 0, "out": 0, "cache_w": 0, "cache_r": 0, "cost_usd": 0.0}
model_seen = "unknown"

try:
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            msg = d.get("message", {}) if isinstance(d.get("message"), dict) else {}
            usage = msg.get("usage", {}) if isinstance(msg.get("usage"), dict) else {}
            if not usage: continue
            model = msg.get("model") or model_seen or "unknown"
            if model and model != "unknown":
                model_seen = model
            p = PRICES.get(model, PRICES["claude-opus-4-7"])  # default opus
            inp = usage.get("input_tokens", 0) or 0
            out = usage.get("output_tokens", 0) or 0
            cw  = usage.get("cache_creation_input_tokens", 0) or 0
            cr  = usage.get("cache_read_input_tokens", 0) or 0
            totals["in"] += inp
            totals["out"] += out
            totals["cache_w"] += cw
            totals["cache_r"] += cr
            totals["cost_usd"] += (
                inp * p["in"] / 1_000_000 +
                out * p["out"] / 1_000_000 +
                cw * p["in"] * 1.25 / 1_000_000 +
                cr * p["in"] * 0.10 / 1_000_000
            )
except Exception:
    pass

print(f"{totals['cost_usd']:.4f}|{model_seen}|{totals['in']}|{totals['out']}|{totals['cache_w']}|{totals['cache_r']}")
PYEOF
}

# ─────────────────────────────────────────────────────────────
# Modos
# ─────────────────────────────────────────────────────────────

mode_session() {
    local sid="$1"
    [[ -z "$sid" ]] && { echo "Usage: $0 session <sessionId>" >&2; return 1; }
    local transcript
    transcript=$(find "$PROJECTS_DIR" -name "${sid}.jsonl" 2>/dev/null | head -1)
    [[ -z "$transcript" ]] && { echo "0.0000|unknown|0|0|0|0"; return 0; }
    calc_transcript_cost "$transcript"
}

mode_current() {
    # Sesión más reciente del cwd actual.
    # Claude Code convierte / y _ a - en el directorio de projects/.
    local cwd_flat
    cwd_flat=$(echo "${PWD}" | sed 's|/|-|g; s|_|-|g')
    local proj_dir="${PROJECTS_DIR}/${cwd_flat}"
    [[ ! -d "$proj_dir" ]] && { echo "0.0000|unknown|0|0|0|0"; return 0; }
    local transcript
    transcript=$(find "$proj_dir" -name "*.jsonl" -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr | head -1 | awk '{print $2}')
    [[ -z "$transcript" ]] && { echo "0.0000|unknown|0|0|0|0"; return 0; }

    # Cache 30s
    local cache_file="${CACHE_DIR}/cost-current.txt"
    if [[ -f "$cache_file" ]]; then
        local age now
        now=$(date +%s)
        age=$((now - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if (( age < CACHE_TTL )); then
            cat "$cache_file"; return 0
        fi
    fi

    local result
    result=$(calc_transcript_cost "$transcript")
    echo "$result" > "$cache_file"
    echo "$result"
}

mode_all() {
    # Procesa TODOS los transcripts, agrupa por modelo + project
    HELIX_PROJECTS_DIR="$PROJECTS_DIR" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import json, os, sys
from pathlib import Path
from collections import defaultdict

PRICES = {
    "claude-opus-4-7":   {"in": 15.00, "out": 75.00},
    "claude-opus-4-6":   {"in": 15.00, "out": 75.00},
    "claude-opus-4":     {"in": 15.00, "out": 75.00},
    "claude-sonnet-4-6": {"in": 3.00,  "out": 15.00},
    "claude-sonnet-4-5": {"in": 3.00,  "out": 15.00},
    "claude-sonnet-4":   {"in": 3.00,  "out": 15.00},
    "claude-haiku-4-5":  {"in": 1.00,  "out": 5.00},
    "claude-haiku-4":    {"in": 1.00,  "out": 5.00},
}

root = Path(os.environ["HELIX_PROJECTS_DIR"])
# rollup: por (model, project)
agg = defaultdict(lambda: {"in":0,"out":0,"cw":0,"cr":0,"usd":0.0,"sessions":0})

for proj_dir in root.iterdir():
    if not proj_dir.is_dir(): continue
    # Strip Claude Code's flattened HOME prefix (e.g. -home-USERNAME-) to leave project name
    home_prefix = "-" + os.path.expanduser("~").strip("/").replace("/", "-") + "-"
    project = proj_dir.name.replace(home_prefix, "")
    for tr in proj_dir.glob("*.jsonl"):
        agg_key_seen = set()
        try:
            with open(tr) as f:
                for line in f:
                    line = line.strip()
                    if not line: continue
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    msg = d.get("message", {}) if isinstance(d.get("message"), dict) else {}
                    usage = msg.get("usage", {}) if isinstance(msg.get("usage"), dict) else {}
                    if not usage: continue
                    model = msg.get("model") or "unknown"
                    p = PRICES.get(model, PRICES["claude-opus-4-7"])
                    inp = usage.get("input_tokens", 0) or 0
                    out = usage.get("output_tokens", 0) or 0
                    cw  = usage.get("cache_creation_input_tokens", 0) or 0
                    cr  = usage.get("cache_read_input_tokens", 0) or 0
                    k = (model, project)
                    agg[k]["in"] += inp
                    agg[k]["out"] += out
                    agg[k]["cw"] += cw
                    agg[k]["cr"] += cr
                    agg[k]["usd"] += (
                        inp * p["in"] / 1_000_000 +
                        out * p["out"] / 1_000_000 +
                        cw * p["in"] * 1.25 / 1_000_000 +
                        cr * p["in"] * 0.10 / 1_000_000
                    )
                    if k not in agg_key_seen:
                        agg[k]["sessions"] += 1
                        agg_key_seen.add(k)
        except Exception:
            continue

print("model|project|sessions|in_tok|out_tok|cache_w|cache_r|usd")
total_usd = 0.0
for (model, project), v in sorted(agg.items(), key=lambda x: -x[1]["usd"]):
    print(f"{model}|{project}|{v['sessions']}|{v['in']}|{v['out']}|{v['cw']}|{v['cr']}|{v['usd']:.4f}")
    total_usd += v["usd"]
print(f"TOTAL|all|—|—|—|—|—|{total_usd:.4f}")
PYEOF
}

mode_report() {
    local rollup
    rollup=$(mode_all)
    [[ -z "$rollup" ]] && { echo "No data" >&2; return 1; }

    {
        echo "# Route Cost Audit — Helix Cost Tracker v0.1"
        echo ""
        echo "> Auto-generado por \`helix-cost-rollup.sh report\` el $(date -u +'%Y-%m-%dT%H:%M:%SZ')."
        echo "> Fuente: transcripts JSONL en \`~/.claude/projects/\`. Precios Anthropic 2025-11."
        echo ""
        echo "## Tabla por modelo + proyecto"
        echo ""
        echo "| Modelo | Proyecto | Sesiones | Input tok | Output tok | Cache W | Cache R | USD |"
        echo "|---|---|---|---|---|---|---|---|"
        printf '%s\n' "$rollup" | tail -n +2 | awk -F'|' '{
            printf "| %s | %s | %s | %s | %s | %s | %s | $%s |\n", $1, $2, $3, $4, $5, $6, $7, $8
        }'
        echo ""
        echo "## Notas"
        echo ""
        echo "- Cache write = input × 1.25 (Anthropic pricing)"
        echo "- Cache read  = input × 0.10"
        echo "- USD calculado por turn vía \`message.usage\` y \`message.model\` en transcripts."
        echo "- Output NO se cachea (siempre billable a precio output)."
        echo ""
        echo "## Gate B1 #2"
        echo ""
        echo "Este reporte es el artifact de \"R1 cost pre-audit\" del checklist Gate B1."
        echo "Para validar B1 #2 se requiere ≥1 semana de runtime continuo."
    } > "$REPORT_FILE"

    echo "$REPORT_FILE"
}

# ─────────────────────────────────────────────────────────────
# Entry
# ─────────────────────────────────────────────────────────────
cmd="${1:-current}"
case "$cmd" in
    session) mode_session "${2:-}" ;;
    current) mode_current ;;
    all)     mode_all ;;
    report)  mode_report ;;
    *)
        cat <<EOF
Usage: $0 <mode>
  current              USD de la sesión actual (más reciente del cwd)
  session <sessionId>  USD de una sesión específica
  all                  rollup completo por modelo + proyecto
  report               genera $REPORT_FILE
EOF
        exit 1
        ;;
esac

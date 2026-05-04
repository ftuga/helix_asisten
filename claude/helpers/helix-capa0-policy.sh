#!/usr/bin/env bash
# helix-capa0-policy.sh — HW2 (FASE 9 plan v4) decisión de Capa 0
# Lee ~/.claude/hw-profile.json (creado por helix-hwprobe.sh) y emite policy.
#
# Policies posibles (stdout):
#   ON         → Capa 0 habilitada full (modelos completos OK)
#   OPT_IN     → Capa 0 habilitada solo con modelos pequeños (phi3:mini, qwen2.5:3b)
#   OFF        → Capa 0 deshabilitada, fallback inmediato a Claude
#
# Constraint duro: timeout 30s en cualquier llamada Ollama. Excede → fallback Claude.
# Council dissent #3 mitigation: si bench empírico existe, usa eso > heurística.
#
# Uso:
#   bash ~/.claude/helpers/helix-capa0-policy.sh           → print policy
#   bash ~/.claude/helpers/helix-capa0-policy.sh --json    → print decisión completa con razón
#   bash ~/.claude/helpers/helix-capa0-policy.sh --check   → exit 0 si ON|OPT_IN, exit 1 si OFF

set -uo pipefail

readonly PROFILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hw-profile.json"
readonly BENCH_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cache/capa0-bench.json"
readonly OVERRIDE_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/capa0-disabled"
readonly CAPA0_TIMEOUT_SEC=30

OUTPUT_MODE="text"
for arg in "$@"; do
    case "$arg" in
        --json)  OUTPUT_MODE="json" ;;
        --check) OUTPUT_MODE="check" ;;
    esac
done

# ─────────────────────────────────────────────────────────────
# Profile loading (refresh si no existe o tiene >24h)
# ─────────────────────────────────────────────────────────────
ensure_profile() {
    if [[ ! -f "$PROFILE" ]]; then
        bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-hwprobe.sh" --quiet
    else
        local mtime now age
        mtime=$(stat -c %Y "$PROFILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        age=$((now - mtime))
        if [[ $age -gt 86400 ]]; then
            bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-hwprobe.sh" --quiet
        fi
    fi
}

# Extraer valor de JSON sin jq (regex bash)
json_get() {
    local key="$1"
    local file="$2"
    grep -oE "\"$key\"[[:space:]]*:[[:space:]]*\"?[^,\"}]*\"?" "$file" \
        | head -1 \
        | sed -E 's/^[^:]+:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'
}

ensure_profile

if [[ ! -f "$PROFILE" ]]; then
    # No pudo crear profile — fallback seguro: OFF
    if [[ "$OUTPUT_MODE" == "json" ]]; then
        printf '{"policy":"OFF","reason":"hw-profile.json no disponible"}\n'
    elif [[ "$OUTPUT_MODE" == "check" ]]; then
        exit 1
    else
        printf 'OFF\n'
    fi
    exit 0
fi

TIER=$(json_get "tier" "$PROFILE")
RAM_TOTAL=$(json_get "total" "$PROFILE")
GPU_KIND=$(json_get "kind" "$PROFILE")
GPU_VRAM=$(json_get "vram_mb" "$PROFILE")
TIER_SOURCE=$(json_get "tier_source" "$PROFILE")

# ─────────────────────────────────────────────────────────────
# Bench override (si existe — preferir empírico sobre heurística)
# Council dissent #3: el umbral 8GB es heurística, NO citada.
# Si helix-bench-capa0.sh se corrió, su resultado prevalece.
# ─────────────────────────────────────────────────────────────
BENCH_LATENCY_MS=""
if [[ -f "$BENCH_FILE" ]]; then
    BENCH_LATENCY_MS=$(json_get "latency_ms" "$BENCH_FILE")
fi

# ─────────────────────────────────────────────────────────────
# Decisión de policy
# ─────────────────────────────────────────────────────────────
POLICY="OFF"
REASON="default"

# User override (gana sobre todo: env var, archivo persistente, bench y heurística HW).
# Archivo creado por helix-capa0-toggle.sh; mode dentro del archivo es metadata para
# session-end.sh, aquí solo importa la presencia.
if [[ -f "$OVERRIDE_FILE" ]]; then
    POLICY="OFF"
    OVR_MODE=$(grep -E '^mode:' "$OVERRIDE_FILE" 2>/dev/null | head -1 | sed -E 's/^mode:[[:space:]]*//')
    REASON="override manual del usuario (mode=${OVR_MODE:-unknown})"
elif [[ "${HELIX_CAPA0_DISABLED:-0}" == "1" ]]; then
    POLICY="OFF"
    REASON="override manual del usuario (HELIX_CAPA0_DISABLED=1)"
# Verificación previa: ollama instalado?
elif ! command -v ollama >/dev/null 2>&1; then
    POLICY="OFF"
    REASON="ollama no instalado"
elif [[ -n "$BENCH_LATENCY_MS" ]] && [[ "$BENCH_LATENCY_MS" =~ ^[0-9]+$ ]]; then
    # Override empírico: usar resultado del bench
    if [[ "$BENCH_LATENCY_MS" -lt 10000 ]]; then
        POLICY="ON"
        REASON="bench empírico ${BENCH_LATENCY_MS}ms <10s"
    elif [[ "$BENCH_LATENCY_MS" -lt 30000 ]]; then
        POLICY="OPT_IN"
        REASON="bench empírico ${BENCH_LATENCY_MS}ms entre 10-30s — solo modelos pequeños"
    else
        POLICY="OFF"
        REASON="bench empírico ${BENCH_LATENCY_MS}ms >30s — Capa 0 inviable, fallback Claude"
    fi
else
    # Heurística (sin bench)
    case "$TIER" in
        large)
            POLICY="ON"
            REASON="tier=large por heurística (RAM≥16GB o GPU NVIDIA ≥4GB VRAM)"
            ;;
        medium)
            POLICY="OPT_IN"
            REASON="tier=medium por heurística (RAM 8-16GB sin GPU dedicada) — recomendado bench primero"
            ;;
        small)
            POLICY="OFF"
            REASON="tier=small por heurística (RAM <8GB) — fallback Claude default"
            ;;
        *)
            POLICY="OFF"
            REASON="tier desconocido"
            ;;
    esac
fi

# ─────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────
case "$OUTPUT_MODE" in
    json)
        cat <<EOF
{
  "policy": "$POLICY",
  "reason": "$REASON",
  "tier": "$TIER",
  "tier_source": "$TIER_SOURCE",
  "bench_latency_ms": ${BENCH_LATENCY_MS:-null},
  "timeout_sec": $CAPA0_TIMEOUT_SEC
}
EOF
        ;;
    check)
        [[ "$POLICY" == "OFF" ]] && exit 1 || exit 0
        ;;
    *)
        printf '%s\n' "$POLICY"
        ;;
esac

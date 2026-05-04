#!/usr/bin/env bash
# helix-bench-capa0.sh — HW4 (FASE 9 plan v4) bench empírico de Capa 0
# Mide latencia real de Ollama con prompt simple. Resultado cachea en
# ~/.claude/cache/capa0-bench.json y override la heurística de helix-capa0-policy.
#
# Mitigation council dissent #3 (umbral 8GB sin cita): este bench produce el
# DATO empírico que reemplaza la heurística. Una vez ejecutado, capa0-policy
# usa este número en lugar de RAM/GPU heurística.
#
# Uso:
#   bash ~/.claude/helpers/helix-bench-capa0.sh           → bench rápido (modelo pequeño)
#   bash ~/.claude/helpers/helix-bench-capa0.sh --full    → bench con helix-scout/coder
#   bash ~/.claude/helpers/helix-bench-capa0.sh --refresh → forzar bench aunque haya cache reciente

set -uo pipefail

readonly CACHE="${HOME}/.claude/cache/capa0-bench.json"
readonly CACHE_TTL=$((7 * 86400))   # 7 días — re-bench semanal
readonly TEST_PROMPT="say only OK"
readonly TIMEOUT_SEC=35

MODE="quick"
FORCE_REFRESH=0
for arg in "$@"; do
    case "$arg" in
        --full)    MODE="full" ;;
        --refresh) FORCE_REFRESH=1 ;;
    esac
done

mkdir -p "$(dirname "$CACHE")"

# ANSI brand colors
C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_CYAN=$'\033[38;2;0;245;212m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[0;31m'

# ─────────────────────────────────────────────────────────────
# Cache check
# ─────────────────────────────────────────────────────────────
if [[ "$FORCE_REFRESH" -eq 0 ]] && [[ -f "$CACHE" ]]; then
    mtime=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
    now=$(date +%s)
    if (( now - mtime < CACHE_TTL )); then
        printf '%scache hit%s — bench previo en %ss (TTL %sd). Pasá --refresh para re-bench.\n' \
            "$C_DIM" "$C_RESET" $((now - mtime)) $((CACHE_TTL / 86400))
        cat "$CACHE"
        exit 0
    fi
fi

# ─────────────────────────────────────────────────────────────
# Ollama check
# ─────────────────────────────────────────────────────────────
if ! command -v ollama >/dev/null 2>&1; then
    printf '%s✗ ollama no instalado%s — bench imposible. Marcando OFF en cache.\n' "$C_RED" "$C_RESET" >&2
    cat > "$CACHE" <<EOF
{
  "schema": "helix-capa0-bench/v1",
  "benched_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "ollama_missing",
  "latency_ms": null,
  "model": null,
  "policy_recommended": "OFF"
}
EOF
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Pick model
# ─────────────────────────────────────────────────────────────
INSTALLED=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')

pick_model() {
    local preferred=("$@")
    for m in "${preferred[@]}"; do
        if echo "$INSTALLED" | grep -Fq "$m"; then
            printf '%s' "$m"
            return 0
        fi
    done
    return 1
}

if [[ "$MODE" == "full" ]]; then
    MODEL=$(pick_model "helix-coder:latest" "qwen2.5-coder:7b" "llama3.1:8b" "qwen2.5:3b" "phi3:mini")
else
    MODEL=$(pick_model "phi3:mini" "qwen2.5:0.5b" "qwen2.5:3b" "llama3.2:3b" "helix-scout:latest")
fi

if [[ -z "$MODEL" ]]; then
    printf '%s✗ ningún modelo Ollama instalado%s — bench imposible.\n' "$C_RED" "$C_RESET" >&2
    cat > "$CACHE" <<EOF
{
  "schema": "helix-capa0-bench/v1",
  "benched_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "no_models_installed",
  "latency_ms": null,
  "model": null,
  "policy_recommended": "OFF"
}
EOF
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Bench
# ─────────────────────────────────────────────────────────────
printf '%sbench:%s modelo=%s%s%s prompt="%s" timeout=%ss\n' \
    "$C_CYAN" "$C_RESET" "$C_CYAN" "$MODEL" "$C_RESET" "$TEST_PROMPT" "$TIMEOUT_SEC"

# Pre-cargar modelo (cold start) — primer call siempre paga el load
printf '%s  warmup...%s\n' "$C_DIM" "$C_RESET"
timeout "$TIMEOUT_SEC" ollama run "$MODEL" "$TEST_PROMPT" >/dev/null 2>&1 || true

# Bench real
printf '%s  measuring...%s\n' "$C_DIM" "$C_RESET"
START_NS=$(date +%s%N)
OUTPUT=$(timeout "$TIMEOUT_SEC" ollama run "$MODEL" "$TEST_PROMPT" 2>/dev/null || echo "TIMEOUT")
END_NS=$(date +%s%N)

LATENCY_MS=$(( (END_NS - START_NS) / 1000000 ))

# ─────────────────────────────────────────────────────────────
# Classify
# ─────────────────────────────────────────────────────────────
if [[ "$OUTPUT" == "TIMEOUT" ]] || [[ "$LATENCY_MS" -ge 30000 ]]; then
    POLICY="OFF"
    COLOR="$C_RED"
    GLYPH="✗"
elif [[ "$LATENCY_MS" -lt 10000 ]]; then
    POLICY="ON"
    COLOR="$C_GREEN"
    GLYPH="✓"
else
    POLICY="OPT_IN"
    COLOR="$C_YELLOW"
    GLYPH="⚠"
fi

# ─────────────────────────────────────────────────────────────
# Save + report
# ─────────────────────────────────────────────────────────────
cat > "$CACHE" <<EOF
{
  "schema": "helix-capa0-bench/v1",
  "benched_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "ok",
  "model": "$MODEL",
  "mode": "$MODE",
  "prompt": "$TEST_PROMPT",
  "latency_ms": $LATENCY_MS,
  "timeout_sec": $TIMEOUT_SEC,
  "policy_recommended": "$POLICY"
}
EOF

printf '\n%s%s %s%s — latencia=%dms — policy recomendada=%s%s\n\n' \
    "$COLOR" "$GLYPH" "$MODEL" "$C_RESET" "$LATENCY_MS" "$POLICY" "$C_DIM"
printf '%scache:%s %s\n' "$C_DIM" "$C_RESET" "$CACHE"
printf '%snota:%s helix-capa0-policy.sh ahora usará este bench como fuente de verdad (no la heurística RAM).\n\n' \
    "$C_DIM" "$C_RESET"

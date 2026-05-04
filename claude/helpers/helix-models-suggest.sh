#!/usr/bin/env bash
# helix-models-suggest.sh — HW3 (FASE 9 plan v4) sugerencia de modelos Ollama
# Lee hw-profile.json y lista modelos compatibles con tu HW.
# NO descarga nada — solo sugiere. Usuario decide.
#
# Uso:
#   bash ~/.claude/helpers/helix-models-suggest.sh

set -uo pipefail

readonly PROFILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hw-profile.json"

# Catálogo de modelos con requisitos típicos
# Format: nombre|tamaño_aprox|RAM_min_GB|VRAM_min_GB|latencia_típica|propósito
readonly MODELS_DB=(
    "qwen2.5:0.5b|0.4GB|2|0|<2s|nano — boilerplate, JSON, reformat"
    "phi3:mini|2.2GB|4|0|<5s|small — bugs simples, refactor liviano"
    "qwen2.5:3b|2.0GB|4|0|<5s|small — alternativa phi3 con context largo"
    "llama3.2:3b|2.0GB|4|0|<5s|small — instrucción general"
    "helix-scout|2.0GB|4|0|<8s|small — análisis logs, stacktraces (Helix custom)"
    "qwen2.5-coder:7b|4.7GB|8|0|<15s|medium — code review, refactor"
    "helix-coder|4.7GB|8|0|<15s|medium — bugs Python/TS (Helix custom)"
    "llama3.1:8b|4.7GB|10|0|<15s|medium — instrucción general"
    "qwen2.5:14b|9.0GB|16|6|<30s|large — análisis complejo (requiere GPU)"
    "deepseek-coder-v2:16b|9.0GB|16|6|<30s|large — code en GPU"
    "llama3.1:70b|40GB|64|24|>60s|xlarge — solo workstation"
)

if [[ ! -f "$PROFILE" ]]; then
    bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-hwprobe.sh" --quiet
fi

# Parse profile
RAM_TOTAL=$(grep -oE '"total"[[:space:]]*:[[:space:]]*[0-9]+' "$PROFILE" | head -1 | grep -oE '[0-9]+')
GPU_VRAM=$(grep -oE '"vram_mb"[[:space:]]*:[[:space:]]*[0-9]+' "$PROFILE" | grep -oE '[0-9]+' | tail -1)
GPU_KIND=$(grep -oE '"kind"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROFILE" | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
TIER=$(grep -oE '"tier"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROFILE" | sed -E 's/.*"([^"]*)"$/\1/')

RAM_GB=$((RAM_TOTAL / 1024))
VRAM_GB=$((GPU_VRAM / 1024))

# ANSI colors (brand)
C_RESET=$'\033[0m'
C_DIM=$'\033[2m'
C_CYAN=$'\033[38;2;0;245;212m'
C_OFFWHITE=$'\033[38;2;249;249;249m'
C_SLATE=$'\033[38;2;106;115;120m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'

# ─────────────────────────────────────────────────────────────
# Ollama instalado?
# ─────────────────────────────────────────────────────────────
INSTALLED_LIST=""
if command -v ollama >/dev/null 2>&1; then
    INSTALLED_LIST=$(timeout 3 ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
fi

is_installed() {
    local model="$1"
    [[ -z "$INSTALLED_LIST" ]] && return 1
    echo "$INSTALLED_LIST" | grep -Fq "$model"
}

# ─────────────────────────────────────────────────────────────
# Render
# ─────────────────────────────────────────────────────────────
printf '\n%sHW Profile detectado:%s  RAM=%dGB  VRAM=%dGB (%s)  tier=%s%s\n\n' \
    "$C_CYAN" "$C_RESET" "$RAM_GB" "$VRAM_GB" "$GPU_KIND" "$TIER" "$C_RESET"

printf '%s%-22s %-7s %-9s %-6s %-30s %s%s\n' \
    "$C_SLATE" "MODEL" "SIZE" "RAM_REQ" "STATUS" "PURPOSE" "FIT" "$C_RESET"
printf '%s%s%s\n' "$C_DIM" "──────────────────────────────────────────────────────────────────────────────────" "$C_RESET"

for entry in "${MODELS_DB[@]}"; do
    IFS='|' read -r name size ram_min vram_min latency purpose <<< "$entry"

    # Status: installed / not
    if is_installed "$name"; then
        status="${C_GREEN}installed${C_RESET}"
    else
        status="${C_DIM}—${C_RESET}"
    fi

    # Fit: ¿corre en este HW?
    if [[ "$RAM_GB" -ge "$ram_min" ]] && { [[ "$vram_min" -eq 0 ]] || [[ "$VRAM_GB" -ge "$vram_min" ]]; }; then
        fit="${C_GREEN}✓ runs${C_RESET}"
    elif [[ "$RAM_GB" -ge "$ram_min" ]]; then
        fit="${C_YELLOW}⚠ no GPU${C_RESET}"
    else
        fit="${C_DIM}✗ insuficiente RAM (necesita ${ram_min}GB)${C_RESET}"
    fi

    printf '  %s%-22s%s %-7s %-9s %-19b %-30s %b\n' \
        "$C_OFFWHITE" "$name" "$C_RESET" \
        "$size" "${ram_min}GB+" "$status" "$purpose" "$fit"
done

printf '\n%shint:%s instalar con %sollama pull <model>%s. Helix custom models: %sollama create -f ~/helix_asisten/ollama/<file>.Modelfile%s\n\n' \
    "$C_DIM" "$C_RESET" "$C_CYAN" "$C_RESET" "$C_CYAN" "$C_RESET"

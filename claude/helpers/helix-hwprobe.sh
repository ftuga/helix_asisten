#!/usr/bin/env bash
# helix-hwprobe.sh — HW1 (FASE 9 plan v4) detector de capacidad de máquina
# Output: JSON a ~/.claude/hw-profile.json + stdout
# Detecta: CPU cores/freq, RAM total/free, GPU (NVIDIA/AMD), disco free, OS
# Idempotente: corre cada vez que se invoque, refresca cache
#
# Uso:
#   bash ~/.claude/helpers/helix-hwprobe.sh           → cache + print JSON
#   bash ~/.claude/helpers/helix-hwprobe.sh --quiet   → solo cache, sin stdout
#   bash ~/.claude/helpers/helix-hwprobe.sh --refresh → forzar refresh (default)
#   bash ~/.claude/helpers/helix-hwprobe.sh --tier    → print solo el tier (small|medium|large)

set -uo pipefail

readonly PROFILE="${HOME}/.claude/hw-profile.json"
QUIET=0
PRINT_TIER_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --quiet)   QUIET=1 ;;
        --tier)    PRINT_TIER_ONLY=1; QUIET=1 ;;
        --refresh) ;; # default behavior
    esac
done

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────
detect_cpu_cores() { nproc 2>/dev/null || echo 1; }

detect_cpu_freq_mhz() {
    if [[ -r /proc/cpuinfo ]]; then
        awk -F: '/cpu MHz/ {print int($2); exit}' /proc/cpuinfo 2>/dev/null \
            || awk -F: '/MHz/ {print int($2); exit}' /proc/cpuinfo 2>/dev/null \
            || echo 0
    else
        echo 0
    fi
}

detect_cpu_model() {
    if [[ -r /proc/cpuinfo ]]; then
        awk -F: '/model name/ {gsub(/^ +/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null \
            || echo "unknown"
    else
        echo "unknown"
    fi
}

# RAM en MB (total/free/available)
detect_ram_mb() {
    if command -v free >/dev/null 2>&1; then
        free -m | awk '/^Mem:/ {printf "%d %d %d", $2, $3, $7}'
    elif [[ -r /proc/meminfo ]]; then
        awk '/MemTotal/{t=$2/1024} /MemAvailable/{a=$2/1024} END {printf "%d %d %d", t, t-a, a}' /proc/meminfo
    else
        echo "0 0 0"
    fi
}

# GPU: tipo + VRAM en MB
detect_gpu() {
    local kind="none"
    local vram_mb=0
    local name="none"

    if command -v nvidia-smi >/dev/null 2>&1; then
        # nvidia-smi puede fallar en WSL2 sin driver — capturar stderr
        local raw
        raw=$(timeout 3 nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [[ -n "$raw" ]]; then
            kind="nvidia"
            name=$(echo "$raw" | awk -F, '{gsub(/^ +/, "", $1); print $1}')
            vram_mb=$(echo "$raw" | awk -F, '{gsub(/ /, "", $2); print int($2)}')
        fi
    fi

    if [[ "$kind" == "none" ]] && command -v lspci >/dev/null 2>&1; then
        if lspci 2>/dev/null | grep -qiE "VGA|3D"; then
            local vga
            vga=$(lspci | grep -iE "VGA|3D" | head -1 | awk -F: '{print $3}' | sed 's/^ *//')
            if echo "$vga" | grep -qi "amd\|radeon"; then
                kind="amd"
                name="$vga"
            elif echo "$vga" | grep -qi "intel"; then
                kind="intel-igpu"
                name="$vga"
            else
                kind="other"
                name="$vga"
            fi
        fi
    fi

    printf '%s|%s|%d' "$kind" "$name" "$vram_mb"
}

# Disco free en GB del HOME
detect_disk_free_gb() {
    df -BG "$HOME" 2>/dev/null | awk 'NR==2 {gsub(/G/, "", $4); print int($4)}' \
        || echo 0
}

detect_os() {
    if [[ -r /proc/version ]]; then
        if grep -qi microsoft /proc/version; then
            echo "wsl2"
        elif [[ -f /etc/os-release ]]; then
            . /etc/os-release
            echo "${ID:-linux}"
        else
            echo "linux"
        fi
    else
        uname -s | tr '[:upper:]' '[:lower:]'
    fi
}

# ─────────────────────────────────────────────────────────────
# Tier classification
# ─────────────────────────────────────────────────────────────
# Heurística inicial (sin bench) — se sustituye por bench empírico cuando HW4 corre
# - small:  RAM <8GB → Capa 0 OFF default
# - medium: 8-16GB sin GPU → opt-in small models
# - large:  >16GB o GPU con ≥4GB VRAM → ON full models
#
# Mitigation council #1 dissent #3: la heurística de 8GB es DECLARADA, no medida.
# Cuando HW4 bench corra, sobrescribe esta clasificación con resultado empírico.
classify_tier() {
    local ram_mb="$1"
    local gpu_kind="$2"
    local vram_mb="$3"

    if [[ "$gpu_kind" == "nvidia" ]] && [[ "$vram_mb" -ge 4000 ]]; then
        echo "large"
    elif [[ "$ram_mb" -ge 16000 ]]; then
        echo "large"
    elif [[ "$ram_mb" -ge 8000 ]]; then
        echo "medium"
    else
        echo "small"
    fi
}

# ─────────────────────────────────────────────────────────────
# Probe
# ─────────────────────────────────────────────────────────────
CPU_CORES=$(detect_cpu_cores)
CPU_FREQ=$(detect_cpu_freq_mhz)
CPU_MODEL=$(detect_cpu_model)
read -r RAM_TOTAL RAM_USED RAM_AVAIL < <(detect_ram_mb)
IFS='|' read -r GPU_KIND GPU_NAME GPU_VRAM < <(detect_gpu)
DISK_FREE=$(detect_disk_free_gb)
OS_KIND=$(detect_os)
TIER=$(classify_tier "$RAM_TOTAL" "$GPU_KIND" "$GPU_VRAM")

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Escapar comillas dobles en strings (CPU model puede contener "(R)" etc)
escape_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
CPU_MODEL_ESC=$(escape_json "$CPU_MODEL")
GPU_NAME_ESC=$(escape_json "$GPU_NAME")

# ─────────────────────────────────────────────────────────────
# Write profile
# ─────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$PROFILE")"
cat > "$PROFILE" <<EOF
{
  "schema": "helix-hw-profile/v1",
  "probed_at": "$TIMESTAMP",
  "host": "$(hostname)",
  "os": "$OS_KIND",
  "cpu": {
    "cores": $CPU_CORES,
    "freq_mhz": $CPU_FREQ,
    "model": "$CPU_MODEL_ESC"
  },
  "ram_mb": {
    "total": $RAM_TOTAL,
    "used": $RAM_USED,
    "available": $RAM_AVAIL
  },
  "gpu": {
    "kind": "$GPU_KIND",
    "name": "$GPU_NAME_ESC",
    "vram_mb": $GPU_VRAM
  },
  "disk_free_gb": $DISK_FREE,
  "tier": "$TIER",
  "tier_source": "heuristic",
  "tier_source_note": "heurística RAM/GPU sin bench. Ejecutar helix-bench-capa0.sh para tier empírico (council dissent #3 — 8GB sin cita)."
}
EOF

# ─────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────
if [[ "$PRINT_TIER_ONLY" -eq 1 ]]; then
    printf '%s\n' "$TIER"
elif [[ "$QUIET" -eq 0 ]]; then
    cat "$PROFILE"
fi

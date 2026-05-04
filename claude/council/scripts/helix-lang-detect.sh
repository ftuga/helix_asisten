#!/usr/bin/env bash
# helix-lang-detect.sh — MIT1 council #3 (anti-CS1 devils-advocate)
# Escanea outputs YAML del council buscando uso real de HELIX-LANG v2.
# Registra frecuencia en ~/.claude/council/frequency.log para convertir
# "forzar adopción" en dato medible.
#
# Uso:
#   bash ~/.claude/council/scripts/helix-lang-detect.sh <session_id>
#   bash ~/.claude/council/scripts/helix-lang-detect.sh --report   # tabla acumulada

set -uo pipefail

readonly COUNCIL_DIR="${HOME}/.claude/council"
readonly FREQ_LOG="${COUNCIL_DIR}/frequency.log"

mkdir -p "$COUNCIL_DIR" 2>/dev/null

# ─────────────────────────────────────────────────────────────
# Patrones HELIX-LANG v2 (skill: ~/.claude/skills/helix-lang/SKILL.md)
# ─────────────────────────────────────────────────────────────
# Verbos universales: need|give|ask|do|fix|chk|done|wait|stop
# Operadores: ->|<-|=>|<>|*
# Estados con prefijo: AGENT:STATE.domain (ej: skeptic:!.context)
# Hash refs: S:xxxx
# Composición: |
# Temporales: @now|@next|@done|@blk
# Mensajes inter-agente: FROM->TO verb:object.domain

count_matches() {
    local file="$1"
    local pattern="$2"
    awk -v pat="$pattern" '$0 ~ pat {n++} END {print n+0}' "$file" 2>/dev/null
}

scan_file() {
    local file="$1"
    local hl_verbs hl_ops hl_temporal hl_hash hl_msg total

    # Patrones distintivos (no false-positives con YAML normal)
    hl_verbs=$(count_matches "$file" '\b(need|give|chk|fix|done|wait|stop)[[:space:]]*:[[:space:]]')
    hl_ops=$(count_matches "$file" '(->|<-|=>|<>)[[:space:]]')
    hl_temporal=$(count_matches "$file" '@(now|next|done|blk)\b')
    hl_hash=$(count_matches "$file" '\bS:[a-f0-9]{4,}\b')
    hl_msg=$(count_matches "$file" '\b[a-z][a-z_]+->[a-z][a-z_]+\s+(need|give|ask|do|fix|chk|done)')

    total=$((hl_verbs + hl_ops + hl_temporal + hl_hash + hl_msg))
    printf '%d|%d|%d|%d|%d|%d' "$hl_verbs" "$hl_ops" "$hl_temporal" "$hl_hash" "$hl_msg" "$total"
}

scan_session() {
    local sid="$1"
    local outdir="${COUNCIL_DIR}/context-pack/${sid}/outputs"

    if [[ ! -d "$outdir" ]]; then
        echo "ERROR: session $sid sin outputs en $outdir" >&2
        return 1
    fi

    local total_files=0
    local files_with_hl=0
    local total_chars=0
    local total_matches=0

    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        total_files=$((total_files + 1))
        local chars
        chars=$(wc -c < "$f" 2>/dev/null || echo 0)
        total_chars=$((total_chars + chars))

        local stats
        stats=$(scan_file "$f")
        local file_total
        file_total=$(echo "$stats" | awk -F'|' '{print $6}')
        total_matches=$((total_matches + file_total))

        if [[ "$file_total" -gt 0 ]]; then
            files_with_hl=$((files_with_hl + 1))
        fi
    done < <(find "$outdir" -maxdepth 1 -name "*.yaml" -type f)

    local adoption_pct=0
    if [[ "$total_files" -gt 0 ]]; then
        adoption_pct=$(( files_with_hl * 100 / total_files ))
    fi

    # Registrar en frequency.log
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '%s\t%s\t%d\t%d\t%d\t%d\t%d\n' \
        "$timestamp" "$sid" "$total_files" "$files_with_hl" "$adoption_pct" "$total_matches" "$total_chars" \
        >> "$FREQ_LOG"

    # Reporte stdout
    cat <<EOF
session: $sid
files_total: $total_files
files_with_helix_lang: $files_with_hl
adoption_pct: ${adoption_pct}%
total_pattern_matches: $total_matches
total_chars: $total_chars
log: $FREQ_LOG
EOF

    # Exit code: 0 si >0% adoption, 1 si 0% (señaliza el problema)
    [[ "$files_with_hl" -gt 0 ]] && return 0 || return 1
}

report_history() {
    if [[ ! -f "$FREQ_LOG" ]]; then
        echo "Sin historial — frequency.log no existe aún."
        return
    fi
    printf '\n%-20s %-32s %6s %6s %6s %8s %8s\n' "TIMESTAMP" "SESSION" "FILES" "WITH_HL" "PCT" "MATCHES" "CHARS"
    printf '%s\n' "─────────────────────────────────────────────────────────────────────────────────────────────────"
    awk -F'\t' '{printf "%-20s %-32s %6s %6s %5s%% %8s %8s\n", $1, $2, $3, $4, $5, $6, $7}' "$FREQ_LOG"

    # Trend
    local recent_pct
    recent_pct=$(tail -3 "$FREQ_LOG" | awk -F'\t' '{sum+=$5; n++} END {if(n) printf "%.1f", sum/n}')
    printf '\nadoption últimas 3 sesiones: %s%%\n' "${recent_pct:-0}"
}

# ─────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────
case "${1:-}" in
    --report|-r)
        report_history
        ;;
    --help|-h|"")
        cat <<EOF
helix-lang-detect.sh — Detector de uso de HELIX-LANG en outputs del council

Uso:
  $0 <session_id>     Escanea outputs de la sesión, registra en frequency.log
  $0 --report         Tabla histórica de adoption
  $0 --help           Esta ayuda

Generado por MIT1 council #3 (anti-CS1: convertir 'forzar adopción' en dato).
EOF
        ;;
    *)
        scan_session "$1"
        ;;
esac

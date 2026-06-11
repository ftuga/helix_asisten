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

readonly COUNCIL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/council"
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
    local hl_verbs hl_ops hl_temporal hl_hash hl_msg hl_state total
    local v3_state v3_msg v3_question v3_delta v3_pos_temporal v3_total

    # Patrones HELIX-LANG v2 (gramática completa - corregido 2026-05-07 post-A/B test)
    # FIX 1: incluir verbos `ask` y `do` (faltaban — gramática real los lista)
    # FIX 2: hl_msg acepta uppercase agent codes (SKEPT->SYNTH, ORC->FE+BE)
    # FIX 3: hl_ops sin requerir espacio (SKEPT->SYNTH es válido)
    # FIX 4: hl_state nuevo patrón AGENT:STATE.domain (Forma 1 de la gramática)
    hl_verbs=$(count_matches "$file" '\b(need|give|ask|do|chk|fix|done|wait|stop)[[:space:]]*:[[:space:]]*[a-z]')
    hl_ops=$(count_matches "$file" '(->|<-|=>|<>)')
    hl_temporal=$(count_matches "$file" '@(now|next|done|blk)\b')
    hl_hash=$(count_matches "$file" '\bS:[a-zA-Z0-9]{4,}\b')
    hl_msg=$(count_matches "$file" '[A-Z][A-Za-z_]*->[A-Z{*]')
    hl_state=$(count_matches "$file" '[A-Z][A-Z_]+:(ok|er|~|\?|#|%[0-9]+|![a-z])')

    total=$((hl_verbs + hl_ops + hl_temporal + hl_hash + hl_msg + hl_state))

    # Patrones HELIX-LANG v3 (council 20260507T215307Z-109qf)
    # v3 elimina colon entre agente y estado, IDs 2-char, verbos sin colon, prefijo ? para preguntas.
    # IDs council v3: SK IN CO SY RE DV AB OC. IDs software v3: FE BE DB TS IF.
    # v3_state: AGENT STATE.domain | AGENT STATE (sin colon)
    # v3_msg: AGENT->AGENT object.domain (sin verbo:colon)
    # v3_question: AGENT->AGENT ?object
    # v3_delta: secuencia AGENT STATE AGENT STATE [@temp] o [...]
    # v3_pos_temporal: line ending with ! ; o ^ unico (advisory; ambigüo, contado solo si stand-alone)
    v3_state=$(count_matches "$file" '\b(SK|IN|CO|SY|RE|DV|AB|OC|FE|BE|DB|TS|IF) (ok|er|~[0-9]*|#)\b')
    v3_msg=$(count_matches "$file" '\b(SK|IN|CO|SY|RE|DV|AB|OC|FE|BE|DB|TS|IF)->(SK|IN|CO|SY|RE|DV|AB|OC|FE|BE|DB|TS|IF)\b')
    v3_question=$(count_matches "$file" '->[A-Z]{2,}\s+\?[a-z]')
    v3_delta=$(count_matches "$file" '\b(SK|IN|CO|SY|RE|DV|AB|OC|FE|BE|DB|TS|IF) (ok|er) (SK|IN|CO|SY|RE|DV|AB|OC|FE|BE|DB|TS|IF) (ok|er)\b')
    v3_pos_temporal=$(count_matches "$file" '[a-z0-9.]+ [!;\^]$')

    v3_total=$((v3_state + v3_msg + v3_question + v3_delta + v3_pos_temporal))

    printf '%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d' \
        "$hl_verbs" "$hl_ops" "$hl_temporal" "$hl_hash" "$hl_msg" "$hl_state" "$total" \
        "$v3_state" "$v3_msg" "$v3_question" "$v3_delta" "$v3_pos_temporal" "$v3_total"
}

# Lee la version de helix-lang prescrita para una sesion (desde meta.yaml).
# Default: 2.1 si meta.yaml no existe o no tiene el campo.
read_session_version() {
    local sid="$1"
    local meta="${COUNCIL_DIR}/context-pack/${sid}/meta.yaml"
    if [[ -f "$meta" ]]; then
        grep -E '^helix_lang_version:' "$meta" 2>/dev/null | head -1 | awk -F'"' '{print $2}' | grep -E '^(2\.1|3\.0)$' || echo "2.1"
    else
        echo "2.1"
    fi
}

scan_session() {
    local sid="$1"
    local outdir="${COUNCIL_DIR}/context-pack/${sid}/outputs"

    if [[ ! -d "$outdir" ]]; then
        echo "ERROR: session $sid sin outputs en $outdir" >&2
        return 1
    fi

    # Read prescribed version (council 20260507T215307Z-109qf P2 + DA3)
    local session_version
    session_version=$(read_session_version "$sid")

    local total_files=0
    local files_with_hl=0
    local files_with_v3=0
    local total_chars=0
    local total_matches=0
    local total_v3_matches=0

    # adoption_by_form (D5.B council 20260610T161758Z-ianr):
    # Threshold desagregado en lugar de adoption_pct global.
    # Cuenta archivos con AL MENOS 1 match en cada forma.
    local files_with_handoff=0       # FROM->TO patterns (formas estructurales OBLIGATORIO)
    local files_with_s_hash=0        # S:xxxx vocab refs (OBLIGATORIO)
    local files_with_state_delta=0   # AGENT:STATE.domain o D:{...} (OBLIGATORIO)
    local files_with_prose=0         # any verb/op pattern in prose (opt-in EN/ES)

    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        total_files=$((total_files + 1))
        local chars
        chars=$(wc -c < "$f" 2>/dev/null || echo 0)
        total_chars=$((total_chars + chars))

        local stats
        stats=$(scan_file "$f")
        local file_v2_total file_v3_total
        file_v2_total=$(echo "$stats" | awk -F'|' '{print $7}')
        file_v3_total=$(echo "$stats" | awk -F'|' '{print $13}')
        total_matches=$((total_matches + file_v2_total))
        total_v3_matches=$((total_v3_matches + file_v3_total))

        if [[ "$file_v2_total" -gt 0 ]]; then
            files_with_hl=$((files_with_hl + 1))
        fi
        if [[ "$file_v3_total" -gt 0 ]]; then
            files_with_v3=$((files_with_v3 + 1))
        fi

        # Per-form detection (formas estructurales D5.B)
        local has_handoff has_s_hash has_state_delta has_prose
        has_handoff=$(echo "$stats" | awk -F'|' '{print $5}')   # hl_msg
        has_s_hash=$(echo "$stats" | awk -F'|' '{print $4}')    # hl_hash
        has_state_delta=$(echo "$stats" | awk -F'|' '{print $6}')  # hl_state
        # Also detect D:{...} delta blocks
        local has_delta_block
        has_delta_block=$(count_matches "$f" 'D:\{')
        if [[ "$has_delta_block" -gt 0 ]]; then
            has_state_delta=$((has_state_delta + has_delta_block))
        fi
        has_prose=$(echo "$stats" | awk -F'|' '{print $1 + $3}')  # hl_verbs + hl_temporal

        [[ "$has_handoff" -gt 0 ]] && files_with_handoff=$((files_with_handoff + 1))
        [[ "$has_s_hash" -gt 0 ]] && files_with_s_hash=$((files_with_s_hash + 1))
        [[ "$has_state_delta" -gt 0 ]] && files_with_state_delta=$((files_with_state_delta + 1))
        [[ "$has_prose" -gt 0 ]] && files_with_prose=$((files_with_prose + 1))
    done < <(find "$outdir" -maxdepth 1 -name "*.yaml" -type f)

    # Adoption por version prescrita
    local adoption_pct=0
    local v3_adoption_pct=0
    # adoption_by_form (D5.B): porcentajes desagregados
    local adoption_handoff_pct=0
    local adoption_s_hash_pct=0
    local adoption_state_delta_pct=0
    local adoption_prose_pct=0
    if [[ "$total_files" -gt 0 ]]; then
        adoption_pct=$(( files_with_hl * 100 / total_files ))
        v3_adoption_pct=$(( files_with_v3 * 100 / total_files ))
        adoption_handoff_pct=$(( files_with_handoff * 100 / total_files ))
        adoption_s_hash_pct=$(( files_with_s_hash * 100 / total_files ))
        adoption_state_delta_pct=$(( files_with_state_delta * 100 / total_files ))
        adoption_prose_pct=$(( files_with_prose * 100 / total_files ))
    fi

    # Threshold gates D5.B (handoffs>=80%, S:hash>=70%, estado/delta>=50%, prosa sin threshold)
    local warn_handoff="" warn_s_hash="" warn_state_delta=""
    [[ "$adoption_handoff_pct" -lt 80 ]] && warn_handoff="WARN: handoff adoption ${adoption_handoff_pct}% < 80% threshold"
    [[ "$adoption_s_hash_pct" -lt 70 ]] && warn_s_hash="WARN: S:hash adoption ${adoption_s_hash_pct}% < 70% threshold"
    [[ "$adoption_state_delta_pct" -lt 50 ]] && warn_state_delta="WARN: state/delta adoption ${adoption_state_delta_pct}% < 50% threshold"

    # Adoption "oficial" segun version prescrita
    local official_adoption_pct=$adoption_pct
    if [[ "$session_version" == "3.0" ]]; then
        official_adoption_pct=$v3_adoption_pct
    fi

    # Backward compat warning (P5 council 20260507T215307Z-109qf)
    local compat_warning=""
    if [[ "$session_version" == "2.1" ]] && [[ "$total_v3_matches" -gt $((total_matches * 2)) ]]; then
        compat_warning="WARN: session prescribed v2.1 but v3 patterns dominate (v3=${total_v3_matches} v2=${total_matches}). Possible mid-rollout drift."
    elif [[ "$session_version" == "3.0" ]] && [[ "$total_matches" -gt $((total_v3_matches * 2)) ]]; then
        compat_warning="WARN: session prescribed v3.0 but v2.1 patterns dominate (v2=${total_matches} v3=${total_v3_matches}). Adoption gap."
    fi

    # Registrar en frequency.log (formato extendido D5.B: agrega adoption_by_form columns)
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '%s\t%s\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n' \
        "$timestamp" "$sid" "$total_files" "$files_with_hl" "$official_adoption_pct" "$total_matches" "$total_chars" \
        "$session_version" "$files_with_v3" "$total_v3_matches" \
        "$adoption_handoff_pct" "$adoption_s_hash_pct" "$adoption_state_delta_pct" "$adoption_prose_pct" \
        >> "$FREQ_LOG"

    # Reporte stdout (YAML para fácil parsing con yq)
    cat <<EOF
session: $sid
session_version: $session_version
files_total: $total_files
files_with_helix_lang_v2: $files_with_hl
files_with_helix_lang_v3: $files_with_v3
adoption_pct: ${official_adoption_pct}%
adoption:
  by_form:
    handoff: ${adoption_handoff_pct}%
    s_hash: ${adoption_s_hash_pct}%
    state_delta: ${adoption_state_delta_pct}%
    prose: ${adoption_prose_pct}%
  thresholds_d5b:
    handoff_min: 80%
    s_hash_min: 70%
    state_delta_min: 50%
    prose_min: null
v2_pattern_matches: $total_matches
v3_pattern_matches: $total_v3_matches
total_chars: $total_chars
log: $FREQ_LOG
EOF
    if [[ -n "$compat_warning" ]]; then
        echo "$compat_warning"
    fi
    # D5.B threshold warnings (visible al finalize del council)
    [[ -n "$warn_handoff" ]] && echo "$warn_handoff"
    [[ -n "$warn_s_hash" ]] && echo "$warn_s_hash"
    [[ -n "$warn_state_delta" ]] && echo "$warn_state_delta"

    # Exit code: 0 si >0% adoption en la version prescrita, 1 si 0%
    if [[ "$session_version" == "3.0" ]]; then
        [[ "$files_with_v3" -gt 0 ]] && return 0 || return 1
    else
        [[ "$files_with_hl" -gt 0 ]] && return 0 || return 1
    fi
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

#!/usr/bin/env bash
# resolve-activity.sh — devuelve un string corto (≤40 chars) describiendo
# la actividad actual del agente, para mostrar como header del statusline.
#
# Prioridad (primera fuente que devuelva algo gana):
#   1. Task `in_progress` más reciente en la sesión activa de CC
#   2. Plan file más reciente en ~/.helix/plans/*.md
#   3. Branch git si empieza con feat-/fix-/chore-/feature-/bugfix-
#   4. Última entrada de helix-bitacora.md (heading H2)
#   5. "idle"
#
# Output: 1 línea, sin colores, sin newline final.
# Latencia objetivo: <50ms warm, <100ms cold.

set -uo pipefail

HELIX_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
MAX_LEN=40
ACTIVITY=""

# ── 1. Task in_progress (sesión activa CC) ──────────────────────────────
# La sesión activa es la carpeta de tasks con mtime más reciente y modificada
# en los últimos 10 minutos. Sin esto, una sesión vieja domina indefinidamente.
TASKS_DIR="${HELIX_DIR}/tasks"
if [[ -d "$TASKS_DIR" ]]; then
    if [[ -n "${EPOCHSECONDS:-}" ]]; then
        now=$EPOCHSECONDS
    else
        printf -v now '%(%s)T' -1
    fi
    newest_mtime=0
    newest_sid=""
    shopt -s nullglob
    for sid_dir in "$TASKS_DIR"/*/; do
        m=$(stat -c %Y "$sid_dir" 2>/dev/null) || continue
        if (( m > newest_mtime && now - m < 600 )); then
            newest_mtime=$m
            newest_sid="$sid_dir"
        fi
    done
    shopt -u nullglob
    if [[ -n "$newest_sid" ]]; then
        # Buscar primer task in_progress. Iterar ordenado por id numérico.
        in_progress_subject=""
        in_progress_id=999999
        shopt -s nullglob
        for tjson in "$newest_sid"*.json; do
            [[ -f "$tjson" ]] || continue
            # Parse status + subject + activeForm con bash regex (sin jq).
            content=$(<"$tjson")
            status=""
            if [[ "$content" =~ \"status\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                status="${BASH_REMATCH[1]}"
            fi
            [[ "$status" == "in_progress" ]] || continue
            id=""
            if [[ "$content" =~ \"id\"[[:space:]]*:[[:space:]]*\"([0-9]+)\" ]]; then
                id="${BASH_REMATCH[1]}"
            fi
            (( id < in_progress_id )) || continue
            # Preferir activeForm sobre subject (más narrativo).
            label=""
            if [[ "$content" =~ \"activeForm\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
                label="${BASH_REMATCH[1]}"
            fi
            if [[ -z "$label" && "$content" =~ \"subject\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
                label="${BASH_REMATCH[1]}"
            fi
            if [[ -n "$label" ]]; then
                in_progress_id="$id"
                in_progress_subject="$label"
            fi
        done
        shopt -u nullglob
        if [[ -n "$in_progress_subject" ]]; then
            ACTIVITY="$in_progress_subject"
        fi
    fi
fi

# ── 2. Plan file más reciente ──────────────────────────────────────────
if [[ -z "$ACTIVITY" ]]; then
    PLANS_DIR="${HELIX_DIR}/plans"
    if [[ -d "$PLANS_DIR" ]]; then
        newest_mtime=0
        newest_plan=""
        shopt -s nullglob
        for pf in "$PLANS_DIR"/*.md; do
            m=$(stat -c %Y "$pf" 2>/dev/null) || continue
            if (( m > newest_mtime )); then
                newest_mtime=$m
                newest_plan="$pf"
            fi
        done
        shopt -u nullglob
        if [[ -n "$newest_plan" ]]; then
            base=$(basename "$newest_plan" .md)
            ACTIVITY="$base"
        fi
    fi
fi

# ── 3. Branch git si feat-/fix-/chore-/etc. ─────────────────────────────
if [[ -z "$ACTIVITY" ]]; then
    cwd="${1:-$PWD}"
    if [[ -d "$cwd/.git" ]] || git -C "$cwd" rev-parse --git-dir &>/dev/null; then
        branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
        if [[ "$branch" =~ ^(feat|fix|chore|feature|bugfix|hotfix|refactor)[/-] ]]; then
            ACTIVITY="$branch"
        fi
    fi
fi

# ── 4. Última entrada bitácora ─────────────────────────────────────────
if [[ -z "$ACTIVITY" ]]; then
    cwd="${1:-$PWD}"
    BITACORA="$cwd/.claude/memory/helix-bitacora.md"
    if [[ -f "$BITACORA" ]]; then
        # Buscar último heading H2 (## ...).
        last_h2=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" =~ ^##[[:space:]]+(.*)$ ]]; then
                last_h2="${BASH_REMATCH[1]}"
            fi
        done < "$BITACORA"
        [[ -n "$last_h2" ]] && ACTIVITY="$last_h2"
    fi
fi

# ── 5. Fallback ────────────────────────────────────────────────────────
[[ -z "$ACTIVITY" ]] && ACTIVITY="idle"

# Truncar a MAX_LEN chars (con elipsis si trunca).
if (( ${#ACTIVITY} > MAX_LEN )); then
    ACTIVITY="${ACTIVITY:0:$((MAX_LEN-1))}…"
fi

printf '%s' "$ACTIVITY"

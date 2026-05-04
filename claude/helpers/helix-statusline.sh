#!/usr/bin/env bash
# helix-statusline.sh — Helix native statusline (bash) v0.1
#
# Reemplazo de statusline.cjs (RuFlo V3, 742 LOC). Plan v4 FASE 0.5.
# Decisión post-Council 2026-05-04 (TRANCH 1 aprobado).
#
# Budget de performance: <200ms p99 (target). Caching TTL 30s para lookups caros.
# Input: JSON por stdin (model.display_name, workspace.current_dir).
# Output: 6 líneas con ANSI colors al stdout. Errores van a /dev/null (silent fail).
#
# Layout:
#   L1: ▊ Helix v3.13  ● user  │  ⏇ branch  │  Model  │  📁 project
#   L2: ─────────────────────
#   L3: 🧠 Agentes N  │  Skills N  │  Topics N  │  Stack tier
#   L4: 🔬 Vectors N ●  │  CLAUDE.md NL  │  Ctx N%  │  Cache N%
#   L5: 🪝 Hooks N  │  HSL 6  │  💰 $X/d  │  💾 snap Xh
#   L6: 📋 Backlog N  │  Evolutions N  │  Stale N  │  Session #N

set -uo pipefail

# ─────────────────────────────────────────────────────────────
# Constantes
# ─────────────────────────────────────────────────────────────
readonly HELIX_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
readonly CACHE_DIR="${HELIX_DIR}/cache"
readonly CACHE_TTL=30          # segundos
readonly HSL_LAYERS=6          # constante mientras HSL v1 esté activo
readonly VERSION="v0.2-PLC"   # Pulse-Lite-Conservative — Council #2 audit log 20260504T020347Z

mkdir -p "$CACHE_DIR" 2>/dev/null

# ─────────────────────────────────────────────────────────────
# ANSI colors
# ─────────────────────────────────────────────────────────────
readonly C_RESET=$'\033[0m'
readonly C_DIM=$'\033[2m'
readonly C_BOLD=$'\033[1m'
readonly C_RED=$'\033[0;31m'
readonly C_GREEN=$'\033[0;32m'
readonly C_YELLOW=$'\033[0;33m'
readonly C_BLUE=$'\033[0;34m'
readonly C_PURPLE=$'\033[0;35m'
readonly C_CYAN=$'\033[0;36m'
readonly C_BR_GREEN=$'\033[1;32m'
readonly C_BR_YELLOW=$'\033[1;33m'
readonly C_BR_BLUE=$'\033[1;34m'
readonly C_BR_PURPLE=$'\033[1;35m'
readonly C_BR_CYAN=$'\033[1;36m'
readonly C_BR_WHITE=$'\033[1;37m'
readonly SEP="${C_DIM}│${C_RESET}"

# ─────────────────────────────────────────────────────────────
# Helix Brand Palette (axolotl mascot, truecolor 24-bit ANSI)
# Cobalt Deep Blue #002058 — accent fondos / acentos secundarios
# Electric Cyan    #00F5D4 — wordmark, secciones, brand primario
# Slate Gray       #2D3436 — separadores, dim labels
# Off-White        #F9F9F9 — valores, alta legibilidad
# ─────────────────────────────────────────────────────────────
readonly C_HELIX_CYAN=$'\033[38;2;0;245;212m'      # #00F5D4 Electric Cyan
readonly C_HELIX_COBALT=$'\033[38;2;58;130;220m'   # acento legible derivado de #002058 (el original es ilegible sobre dark bg)
readonly C_HELIX_SLATE=$'\033[38;2;106;115;120m'   # slate gray legible sobre dark bg
readonly C_HELIX_OFFWHITE=$'\033[38;2;249;249;249m' # #F9F9F9 Off-White
readonly C_HELIX_BOLD_CYAN=$'\033[1;38;2;0;245;212m'

# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

# Cache get/set: cache_get <key> -> stdout cached value if fresh, exit 1 if miss
cache_get() {
    local key="$1"
    local file="${CACHE_DIR}/statusline-${key}.txt"
    [[ -f "$file" ]] || return 1
    local mtime now age
    mtime=$(stat -c %Y "$file" 2>/dev/null) || return 1
    now=$(date +%s)
    age=$((now - mtime))
    [[ $age -lt $CACHE_TTL ]] || return 1
    cat "$file"
}

cache_set() {
    local key="$1"
    local file="${CACHE_DIR}/statusline-${key}.txt"
    cat > "$file"
}

# Extraer string de JSON con regex bash. Frágil pero rápido (sin python startup).
# Uso: json_str <json> <key>  -> stdout valor
json_str() {
    local json="$1"
    local key="$2"
    if [[ "$json" =~ \"${key}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

# Extraer número de JSON
json_num() {
    local json="$1"
    local key="$2"
    if [[ "$json" =~ \"${key}\"[[:space:]]*:[[:space:]]*([0-9.]+) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

# Formato "Xh" o "Xm" para edad de archivo en segundos
human_age() {
    local secs="${1:-0}"
    if [[ $secs -lt 60 ]]; then
        printf '%ds' "$secs"
    elif [[ $secs -lt 3600 ]]; then
        printf '%dm' $((secs / 60))
    elif [[ $secs -lt 86400 ]]; then
        printf '%dh' $((secs / 3600))
    else
        printf '%dd' $((secs / 86400))
    fi
}

# ─────────────────────────────────────────────────────────────
# Parse stdin JSON
# ─────────────────────────────────────────────────────────────
INPUT="$(cat 2>/dev/null || true)"
MODEL_NAME=$(json_str "$INPUT" "display_name")
[[ -z "$MODEL_NAME" ]] && MODEL_NAME="Claude"
CWD=$(json_str "$INPUT" "current_dir")
[[ -z "$CWD" ]] && CWD="$PWD"
# Context window % (puede llegar como exceeded_pct, cache_pct, etc.)
CTX_PCT=$(json_num "$INPUT" "context_window_used_pct")
[[ -z "$CTX_PCT" ]] && CTX_PCT="—"
CACHE_PCT=$(json_num "$INPUT" "cache_efficiency_pct")
[[ -z "$CACHE_PCT" ]] && CACHE_PCT="—"

PROJECT_NAME=$(basename "$CWD")

# ─────────────────────────────────────────────────────────────
# Git info (single call con cache TTL=10s)
# ─────────────────────────────────────────────────────────────
GIT_KEY="git-$(printf '%s' "$CWD" | tr / _)"
GIT_DATA=""
if cache_get "$GIT_KEY" >/dev/null 2>&1; then
    GIT_DATA=$(cache_get "$GIT_KEY")
else
    if cd "$CWD" 2>/dev/null && [[ -d .git ]] || git -C "$CWD" rev-parse --git-dir &>/dev/null; then
        GIT_DATA=$(
            cd "$CWD" 2>/dev/null || cd "$HOME"
            user=$(git config user.name 2>/dev/null || echo "user")
            branch=$(git branch --show-current 2>/dev/null || echo "")
            dirty=$(git status --porcelain 2>/dev/null | wc -l)
            printf '%s\n%s\n%s' "$user" "$branch" "$dirty"
        )
        printf '%s' "$GIT_DATA" | cache_set "$GIT_KEY"
    fi
fi
GIT_USER=$(printf '%s' "$GIT_DATA" | sed -n '1p')
GIT_BRANCH=$(printf '%s' "$GIT_DATA" | sed -n '2p')
GIT_DIRTY=$(printf '%s' "$GIT_DATA" | sed -n '3p')
[[ -z "$GIT_USER" ]] && GIT_USER="user"
[[ -z "$GIT_BRANCH" ]] && GIT_BRANCH="—"
[[ -z "$GIT_DIRTY" ]] && GIT_DIRTY=0

# ─────────────────────────────────────────────────────────────
# Conteos baratos (file ops directos, sin cache)
# ─────────────────────────────────────────────────────────────

# Agentes: contar entries en agents-index (líneas tipo "| `agent-name` | ...")
AGENTS_FILE="${HELIX_DIR}/memory/agents-index.md"
N_AGENTS=0
if [[ -f "$AGENTS_FILE" ]]; then
    N_AGENTS=$(grep -cE '^\| `[a-z]' "$AGENTS_FILE" 2>/dev/null || echo 0)
fi

# Skills: subdirectorios bajo ~/.claude/skills/
SKILLS_DIR="${HELIX_DIR}/skills"
N_SKILLS=0
if [[ -d "$SKILLS_DIR" ]]; then
    N_SKILLS=$(find "$SKILLS_DIR" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l)
fi

# Topics: archivos *.md bajo ~/.claude/memory/topics/
TOPICS_DIR="${HELIX_DIR}/memory/topics"
N_TOPICS=0
if [[ -d "$TOPICS_DIR" ]]; then
    N_TOPICS=$(find "$TOPICS_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l)
fi

# Stack tier: parse helix-stack.md del proyecto
STACK_FILE="${CWD}/.claude/memory/helix-stack.md"
STACK_TIER="—"
if [[ -f "$STACK_FILE" ]]; then
    STACK_TIER=$(grep -oE '^tier:[[:space:]]*[a-z]+' "$STACK_FILE" 2>/dev/null | head -1 | awk '{print $2}')
    [[ -z "$STACK_TIER" ]] && STACK_TIER="?"
fi

# CLAUDE.md size
CLAUDE_MD="${HELIX_DIR}/CLAUDE.md"
N_CLAUDE_LINES=0
[[ -f "$CLAUDE_MD" ]] && N_CLAUDE_LINES=$(wc -l < "$CLAUDE_MD" 2>/dev/null || echo 0)

# Vectors count: stale-while-revalidate (hv status toma ~2s — nunca block).
# - Cache TTL 300s (5min). Vector count rara vez cambia mid-sesión.
# - Si cache expirada, lanzar refresh en background y usar valor stale.
# - Si nunca hubo cache, mostrar "?" y dejar background populando.
N_VECTORS="?"
VEC_KEY="vectors"
VEC_FILE="${CACHE_DIR}/statusline-${VEC_KEY}.txt"
VEC_LOCK="${CACHE_DIR}/statusline-${VEC_KEY}.lock"
VEC_TTL=300

if [[ -f "$VEC_FILE" ]]; then
    N_VECTORS=$(cat "$VEC_FILE" 2>/dev/null)
    [[ -z "$N_VECTORS" ]] && N_VECTORS="?"
    # check si necesita refresh
    mtime=$(stat -c %Y "$VEC_FILE" 2>/dev/null || echo 0)
    now=$(date +%s)
    if (( now - mtime > VEC_TTL )) && [[ ! -f "$VEC_LOCK" ]]; then
        # refresh en background — no bloquear render
        ( touch "$VEC_LOCK"
          if command -v hv >/dev/null 2>&1; then
              total=$(timeout 5 hv status 2>/dev/null | grep -oE '[0-9]+[[:space:]]+puntos' | awk '{s+=$1} END {print s+0}')
              [[ -n "$total" ]] && printf '%s' "$total" > "$VEC_FILE"
          fi
          rm -f "$VEC_LOCK"
        ) </dev/null >/dev/null 2>&1 & disown
    fi
elif [[ ! -f "$VEC_LOCK" ]]; then
    # primera invocación: lanzar background populator
    ( touch "$VEC_LOCK"
      if command -v hv >/dev/null 2>&1; then
          total=$(timeout 5 hv status 2>/dev/null | grep -oE '[0-9]+[[:space:]]+puntos' | awk '{s+=$1} END {print s+0}')
          [[ -n "$total" ]] && printf '%s' "$total" > "$VEC_FILE"
      fi
      rm -f "$VEC_LOCK"
    ) </dev/null >/dev/null 2>&1 & disown
fi

# Hooks count: parse settings.json sin jq
SETTINGS="${HELIX_DIR}/settings.json"
N_HOOKS=0
if [[ -f "$SETTINGS" ]]; then
    # cuenta líneas que abren un evento de hook (PreToolUse, PostToolUse, etc.)
    N_HOOKS=$(grep -cE '"(PreToolUse|PostToolUse|UserPromptSubmit|SessionStart|Stop|Notification|PreCompact|SubagentStop|SessionEnd)"' "$SETTINGS" 2>/dev/null || echo 0)
fi

# Cost USD — R2 cost-tracker v0.1: USD real de la sesión actual vía helix-cost-rollup.sh
# Cache TTL 30s gestionado por el rollup. Fallback al contador placeholder si rollup falla.
COST_DAY="—"
COST_ROLLUP="${HELIX_DIR}/helpers/helix-cost-rollup.sh"
if [[ -x "$COST_ROLLUP" ]]; then
    cost_result=$(cd "$CWD" 2>/dev/null && timeout 2 bash "$COST_ROLLUP" current 2>/dev/null | head -1)
    if [[ -n "$cost_result" ]]; then
        usd=$(printf '%s' "$cost_result" | cut -d'|' -f1)
        # Formato: <$1 → "0.42" / 1-99 → "12.4" / ≥100 → "157" entero
        if [[ "$usd" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            usd_int=$(printf '%.0f' "$usd" 2>/dev/null || echo 0)
            if (( usd_int >= 100 )); then
                COST_DAY="\$$(printf '%.0f' "$usd")"
            elif awk -v v="$usd" 'BEGIN{exit !(v<1)}'; then
                COST_DAY="\$$(printf '%.2f' "$usd")"
            else
                COST_DAY="\$$(printf '%.1f' "$usd")"
            fi
        fi
    fi
fi
# Fallback contador legacy si rollup no devolvió nada
if [[ "$COST_DAY" == "—" ]]; then
    SESSION_COUNTER="/tmp/helix-cost-${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H)}"
    if [[ -f "$SESSION_COUNTER" ]]; then
        cnt=$(cat "$SESSION_COUNTER" 2>/dev/null || echo 0)
        COST_DAY="${cnt}c"
    fi
fi

# Snapshot age
SNAP_DIR="${HELIX_DIR}/snapshots/${PROJECT_NAME}"
SNAP_AGE="—"
if [[ -d "$SNAP_DIR" ]]; then
    last_snap=$(ls -t "$SNAP_DIR"/*.yaml 2>/dev/null | head -1)
    if [[ -n "$last_snap" ]]; then
        mtime=$(stat -c %Y "$last_snap" 2>/dev/null)
        if [[ -n "$mtime" ]]; then
            now=$(date +%s)
            SNAP_AGE=$(human_age $((now - mtime)))
        fi
    fi
fi

# Backlog
BACKLOG_FILE="${CWD}/.claude/memory/helix-backlog.md"
N_BACKLOG=0
[[ -f "$BACKLOG_FILE" ]] && N_BACKLOG=$(grep -cE '^- \[ \]' "$BACKLOG_FILE" 2>/dev/null || echo 0)

# Evolutions: parse JSON stats block en CLAUDE.md ("total_aprendizajes": N)
N_EVOLUTIONS=0
if [[ -f "$CLAUDE_MD" ]]; then
    v=$(grep -oE '"total_aprendizajes"[[:space:]]*:[[:space:]]*[0-9]+' "$CLAUDE_MD" 2>/dev/null \
        | grep -oE '[0-9]+' | tail -1)
    [[ -n "$v" ]] && N_EVOLUTIONS="$v"
fi

# Session # — del JSON stats ("total_sesiones": N)
SESSION_NUM=0
if [[ -f "$CLAUDE_MD" ]]; then
    v=$(grep -oE '"total_sesiones"[[:space:]]*:[[:space:]]*[0-9]+' "$CLAUDE_MD" 2>/dev/null \
        | grep -oE '[0-9]+' | tail -1)
    [[ -n "$v" ]] && SESSION_NUM="$v"
fi

# Agentes activos recientes (ventana 60 min) — fuente: routing-feedback.jsonl
ROUTING_LOG="${HELIX_DIR}/memory/routing-feedback.jsonl"
N_AGENTS_ACTIVE=0
TOP_AGENTS=""
EXTRA_AGENTS=0
if [[ -f "$ROUTING_LOG" ]]; then
    CUTOFF_TS=$(date -d "60 minutes ago" +"%Y-%m-%d %H:%M" 2>/dev/null)
    if [[ -n "$CUTOFF_TS" ]]; then
        # awk single-pass: cuenta invocaciones por agente en ventana, retorna "N|top3|extra"
        AGENTS_RESULT=$(awk -v cutoff="$CUTOFF_TS" '
            {
              match($0, /"ts":[[:space:]]*"([^"]+)"/, ts)
              match($0, /"agente":[[:space:]]*"([^"]+)"/, ag)
              if (ts[1] >= cutoff && ag[1] != "") count[ag[1]]++
            }
            END {
              n = length(count)
              # ordenar por count desc usando arrays paralelos
              i = 0
              for (a in count) { i++; names[i] = a; counts[i] = count[a] }
              # bubble sort simple (n pequeño)
              for (i=1; i<=n; i++) for (j=i+1; j<=n; j++)
                if (counts[j] > counts[i]) {
                  tn=names[i]; names[i]=names[j]; names[j]=tn
                  tc=counts[i]; counts[i]=counts[j]; counts[j]=tc
                }
              top = ""
              for (i=1; i<=3 && i<=n; i++) {
                short = names[i]
                sub(/^council-/, "", short)
                if (length(short) > 12) short = substr(short, 1, 11) "…"
                top = top (i==1 ? "" : ",") short
              }
              extra = (n > 3) ? n - 3 : 0
              printf "%d|%s|%d", n, top, extra
            }' "$ROUTING_LOG" 2>/dev/null)
        if [[ -n "$AGENTS_RESULT" ]]; then
            N_AGENTS_ACTIVE=$(printf '%s' "$AGENTS_RESULT" | cut -d'|' -f1)
            TOP_AGENTS=$(printf '%s' "$AGENTS_RESULT" | cut -d'|' -f2)
            EXTRA_AGENTS=$(printf '%s' "$AGENTS_RESULT" | cut -d'|' -f3)
        fi
    fi
fi
# sanitize inline (sanitize_int aún no definida en este punto)
[[ "$N_AGENTS_ACTIVE" =~ ^[0-9]+$ ]] || N_AGENTS_ACTIVE=0
[[ "$EXTRA_AGENTS" =~ ^[0-9]+$ ]] || EXTRA_AGENTS=0

# Stale: helix-staleness.sh count (cached)
STALE_COUNT="—"
STALE_KEY="stale"
if cache_get "$STALE_KEY" >/dev/null 2>&1; then
    STALE_COUNT=$(cache_get "$STALE_KEY")
else
    if [[ -x "${HELIX_DIR}/helpers/helix-staleness.sh" ]]; then
        # asumimos que con --count devuelve un entero; si no, 0
        sc=$(timeout 1 "${HELIX_DIR}/helpers/helix-staleness.sh" --count 2>/dev/null | grep -oE '^[0-9]+' | head -1)
        [[ -n "$sc" ]] && STALE_COUNT="$sc" || STALE_COUNT=0
        printf '%s' "$STALE_COUNT" | cache_set "$STALE_KEY"
    else
        STALE_COUNT=0
    fi
fi

# ─────────────────────────────────────────────────────────────
# Sanitize integer values (eliminar whitespace que rompe %d en printf)
# ─────────────────────────────────────────────────────────────
sanitize_int() {
    local v="${1:-0}"
    v=$(printf '%s' "$v" | tr -d '[:space:]')
    [[ "$v" =~ ^[0-9]+$ ]] || v=0
    printf '%s' "$v"
}
N_AGENTS=$(sanitize_int "$N_AGENTS")
N_SKILLS=$(sanitize_int "$N_SKILLS")
N_TOPICS=$(sanitize_int "$N_TOPICS")
N_CLAUDE_LINES=$(sanitize_int "$N_CLAUDE_LINES")
N_HOOKS=$(sanitize_int "$N_HOOKS")
N_BACKLOG=$(sanitize_int "$N_BACKLOG")
N_EVOLUTIONS=$(sanitize_int "$N_EVOLUTIONS")
SESSION_NUM=$(sanitize_int "$SESSION_NUM")
GIT_DIRTY=$(sanitize_int "$GIT_DIRTY")

# ─────────────────────────────────────────────────────────────
# Build dirty indicator
# ─────────────────────────────────────────────────────────────
DIRTY_IND=""
if [[ "$GIT_DIRTY" -gt 0 ]]; then
    DIRTY_IND=" ${C_BR_YELLOW}~${GIT_DIRTY}${C_RESET}"
fi

# ─────────────────────────────────────────────────────────────
# Render — PLC++ (Pulse-Lite-Conservative) v0.2
# Council #2 audit log: ~/.claude/council/log/20260504T020347Z_*.yaml
# Decisión creator: identidad propia recognizable (no solo "no-RuFlo")
#
# Ataca 6/8 fingerprints RuFlo:
#   #1 ▊ block char           → eliminado, "HELIX" texto plano
#   #2 ──── horizontal rule   → eliminado, línea en blanco
#   #3 │ pipe separator       → eliminado completamente, sustituido por · middle dot
#   #4 header structure       → reorganizado con · (no │)
#   #5 color-per-row          → color-per-section (corpus/runtime/state)
#   #6 4-data-line emoji      → 3 secciones nombradas + footer status
# Conserva intencionalmente:
#   #7 ANSI 256 palette       (universal)
#   #8 densidad de slots      (18 slots informativos)
# ─────────────────────────────────────────────────────────────

# Helix-native middle dot separator (slate gray, on-brand)
DOT="${C_HELIX_SLATE}·${C_RESET}"

# Health gate: HEALTHY si hsl=6/6 y stale=0 y backlog razonable; sino WARN/CRITICAL
# Health gate — HEALTHY usa Electric Cyan brand. WARN/CRITICAL convencionales.
HEALTH_TXT="HEALTHY"
HEALTH_COLOR="${C_HELIX_CYAN}"
HEALTH_GLYPH="✓"
if [[ "$STALE_COUNT" =~ ^[0-9]+$ ]] && [[ "$STALE_COUNT" -gt 0 ]]; then
    HEALTH_TXT="WARN"
    HEALTH_COLOR="${C_BR_YELLOW}"
    HEALTH_GLYPH="⚠"
fi
if [[ "$N_HOOKS" -lt 4 ]] || [[ "$HSL_LAYERS" -lt 6 ]]; then
    HEALTH_TXT="CRITICAL"
    HEALTH_COLOR="${C_RED}"
    HEALTH_GLYPH="✗"
fi

# L1: header — ≋ HELIX · user@branch · model · 📁 project (axolotl signature ≋)
printf '%s≋ HELIX%s  %s  %s%s@%s%s%s  %s  %s%s%s  %s  📁 %s%s%s\n' \
    "${C_HELIX_BOLD_CYAN}" "${C_RESET}" \
    "${DOT}" \
    "${C_HELIX_OFFWHITE}" "${GIT_USER}" "${GIT_BRANCH}" "${C_RESET}" "${DIRTY_IND}" \
    "${DOT}" \
    "${C_HELIX_COBALT}" "${MODEL_NAME}" "${C_RESET}" \
    "${DOT}" \
    "${C_HELIX_CYAN}" "${PROJECT_NAME}" "${C_RESET}"

# L2: blank
printf '\n'

# L3: 🧬 corpus — agentes/skills/topics/vectors/claude.md/stack
VEC_DOT="${C_HELIX_SLATE}○${C_RESET}"
[[ "$N_VECTORS" != "—" && "$N_VECTORS" != "?" && "$N_VECTORS" -gt 0 ]] 2>/dev/null && VEC_DOT="${C_HELIX_CYAN}●${C_RESET}"
printf '  %s🧬 corpus%s     🧠 %s%d%s  🛠 %s%d%s  📚 %s%d%s  🔬 %s%s%s%s  📄 %s%dL%s  🏷 %s%s%s\n' \
    "${C_HELIX_BOLD_CYAN}" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_AGENTS" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_SKILLS" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_TOPICS" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_VECTORS" "${C_RESET}" "$VEC_DOT" \
    "${C_HELIX_OFFWHITE}" "$N_CLAUDE_LINES" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "${STACK_TIER}" "${C_RESET}"

# L4: ⚡ runtime — ctx/cache/hooks/hsl/cost/snap
printf '  %s⚡ runtime%s    🔋 %s%s%%%s  💾 %s%s%%%s  🪝 %s%d%s  🛡 %s%d/%d%s  💰 %s%s%s  💤 %s%s%s\n' \
    "${C_HELIX_COBALT}" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$CTX_PCT" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$CACHE_PCT" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_HOOKS" "${C_RESET}" \
    "${C_HELIX_CYAN}" "$HSL_LAYERS" "$HSL_LAYERS" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$COST_DAY" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$SNAP_AGE" "${C_RESET}"

# L5: 🌀 state — backlog/evolutions/stale/session
printf '  %s🌀 state%s      📋 %s%d%s  🌿 %s%d%s  ⏳ %s%s%s  ✦ %s#%d%s\n' \
    "${C_HELIX_SLATE}" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_BACKLOG" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$N_EVOLUTIONS" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$STALE_COUNT" "${C_RESET}" \
    "${C_HELIX_OFFWHITE}" "$SESSION_NUM" "${C_RESET}"

# L5b: 👥 agents — agentes invocados en ventana 60min (count + top 3 nombres)
if [[ "$N_AGENTS_ACTIVE" -gt 0 ]]; then
    AGENTS_DISPLAY="$TOP_AGENTS"
    if [[ "$EXTRA_AGENTS" -gt 0 ]]; then
        AGENTS_DISPLAY="${AGENTS_DISPLAY} ${C_HELIX_SLATE}+${EXTRA_AGENTS}${C_RESET}"
    fi
    printf '  %s👥 agents%s     %s%d%s  %s·%s  %s%s%s\n' \
        "${C_HELIX_CYAN}" "${C_RESET}" \
        "${C_HELIX_OFFWHITE}" "$N_AGENTS_ACTIVE" "${C_RESET}" \
        "${C_HELIX_SLATE}" "${C_RESET}" \
        "${C_HELIX_OFFWHITE}" "$AGENTS_DISPLAY" "${C_RESET}"
fi

# L6: blank
printf '\n'

# L7: footer — health gate
printf '  %s%s %s%s\n' \
    "${HEALTH_COLOR}" "${HEALTH_GLYPH}" "${HEALTH_TXT}" "${C_RESET}"

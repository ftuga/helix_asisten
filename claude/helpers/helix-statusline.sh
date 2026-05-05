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

# Cache get/set — pura bash. Devuelve valor en variable global REPLY (sin subshell).
# Antes: 350ms/call por stat+date+cat fork × 6 calls = ~2s. Ahora: ~5ms total.
# Uso:
#   if cache_get_v "$key"; then val="$REPLY"; else miss=1; fi
#   printf '%s' "$val" | cache_set "$key"
#
# IMPORTANTE: cache_get_v sólo lee la PRIMERA LÍNEA del archivo (read -r).
# Para valores multilínea (ej: GIT_DATA con user/branch/dirty), usar cache_get_v
# para el TTL check y luego "$(<file)" para releer entero. Ver bloque GIT_DATA abajo.
#
# Mantengo cache_get original (con cat al stdout) para compatibilidad con código existente
# que ya usa $(cache_get k); pero ahora delegado a cache_get_v + echo.
cache_get_v() {
    local key="$1"
    local file="${CACHE_DIR}/statusline-${key}.txt"
    [[ -f "$file" ]] || return 1
    # printf %T es bash 4.2+ builtin (sin fork). $EPOCHSECONDS es bash 5.0+ builtin.
    local now mtime age
    if [[ -n "${EPOCHSECONDS:-}" ]]; then
        now=$EPOCHSECONDS
    else
        printf -v now '%(%s)T' -1
    fi
    mtime=$(stat -c %Y "$file" 2>/dev/null) || return 1
    age=$((now - mtime))
    (( age < CACHE_TTL )) || return 1
    # read en lugar de cat — sin fork
    IFS= read -r REPLY < "$file" || REPLY=""
    return 0
}

cache_get() {
    cache_get_v "$1" || return 1
    printf '%s' "$REPLY"
}

cache_set() {
    local key="$1"
    local file="${CACHE_DIR}/statusline-${key}.txt"
    cat > "$file"
}

# Extraer string/número de JSON con regex bash. Resultado en variable global REPLY
# para evitar subshell de $(json_*). Save: 4 forks × ~60ms = 240ms por render.
# Uso: json_str <json> <key>  → REPLY="..."
json_str() {
    if [[ "$1" =~ \"${2}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
        REPLY="${BASH_REMATCH[1]}"
    else
        REPLY=""
    fi
}

json_num() {
    if [[ "$1" =~ \"${2}\"[[:space:]]*:[[:space:]]*([0-9.]+) ]]; then
        REPLY="${BASH_REMATCH[1]}"
    else
        REPLY=""
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
json_str "$INPUT" "display_name";              MODEL_NAME="${REPLY:-Claude}"
json_str "$INPUT" "current_dir";               CWD="${REPLY:-$PWD}"
json_num "$INPUT" "context_window_used_pct";   CTX_PCT="${REPLY:-—}"
json_num "$INPUT" "cache_efficiency_pct";      CACHE_PCT="${REPLY:-—}"

PROJECT_NAME=$(basename "$CWD")

# ─────────────────────────────────────────────────────────────
# Git info (single call con cache TTL=30s)
# ─────────────────────────────────────────────────────────────
GIT_KEY="git-${CWD//\//_}"
GIT_KEY="${GIT_KEY//[^A-Za-z0-9._-]/_}"
GIT_DATA=""
if cache_get_v "$GIT_KEY"; then
    # cache_get_v sólo lee la primera línea con read; recargamos con cat para multi-línea
    GIT_DATA=$(<"${CACHE_DIR}/statusline-${GIT_KEY}.txt")
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
# Parse 3 líneas con read (pura bash, sin sed)
{ IFS= read -r GIT_USER; IFS= read -r GIT_BRANCH; IFS= read -r GIT_DIRTY; } <<< "$GIT_DATA"
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

# Skills: subdirectorios bajo ~/.claude/skills/  (bash glob: ~20× más rápido que find|wc en Git Bash)
SKILLS_DIR="${HELIX_DIR}/skills"
N_SKILLS=0
if [[ -d "$SKILLS_DIR" ]]; then
    shopt -s nullglob
    _skills=("$SKILLS_DIR"/*/)
    N_SKILLS=${#_skills[@]}
    unset _skills
    shopt -u nullglob
fi

# Topics: archivos *.md bajo ~/.claude/memory/topics/
TOPICS_DIR="${HELIX_DIR}/memory/topics"
N_TOPICS=0
if [[ -d "$TOPICS_DIR" ]]; then
    shopt -s nullglob
    _topics=("$TOPICS_DIR"/*.md)
    N_TOPICS=${#_topics[@]}
    unset _topics
    shopt -u nullglob
fi

# Stack tier: parse helix-stack.md del proyecto (bash regex en lugar de grep|head|awk)
STACK_FILE="${CWD}/.claude/memory/helix-stack.md"
STACK_TIER="—"
if [[ -f "$STACK_FILE" ]]; then
    while IFS= read -r _line || [[ -n "$_line" ]]; do
        if [[ "$_line" =~ ^tier:[[:space:]]*([a-z]+) ]]; then
            STACK_TIER="${BASH_REMATCH[1]}"
            break
        fi
    done < "$STACK_FILE"
    [[ "$STACK_TIER" == "—" ]] && STACK_TIER="?"
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
VEC_LOCK_TTL=60  # lock huérfano si más viejo que esto

# Lock cleanup: si lock existe pero tiene >60s, asumir subshell muerto y borrar.
# Sin esto, un crash del populator deja el slot mostrando "?" permanente.
if [[ -f "$VEC_LOCK" ]]; then
    lock_mtime=$(stat -c %Y "$VEC_LOCK" 2>/dev/null || echo 0)
    if [[ -n "${EPOCHSECONDS:-}" ]]; then
        lock_now=$EPOCHSECONDS
    else
        printf -v lock_now '%(%s)T' -1
    fi
    (( lock_now - lock_mtime > VEC_LOCK_TTL )) && rm -f "$VEC_LOCK"
fi

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
          else
              # hv no instalado: marca el slot como "no aplica" para no quedarse en "?"
              printf '%s' "—" > "$VEC_FILE"
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
      else
          # hv no instalado: marca el slot como "no aplica" para no quedarse en "?"
          printf '%s' "—" > "$VEC_FILE"
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

# Cost USD — R2 cost-tracker v0.1 con cache 30s a nivel statusline (el rollup mismo
# cachea pero igual fork ~600ms en Windows. Cache local elimina el fork salvo refresh).
COST_DAY="—"
COST_KEY="cost-${PROJECT_NAME//[^A-Za-z0-9._-]/_}"
COST_ROLLUP="${HELIX_DIR}/helpers/helix-cost-rollup.sh"
if cache_get_v "$COST_KEY"; then
    COST_DAY="$REPLY"
elif [[ -x "$COST_ROLLUP" ]]; then
    cost_result=$(cd "$CWD" 2>/dev/null && timeout 2 bash "$COST_ROLLUP" current 2>/dev/null | head -1)
    if [[ -n "$cost_result" ]]; then
        usd="${cost_result%%|*}"
        # Formato: <$1 → "0.42" / 1-99 → "12.4" / ≥100 → "157" — un solo awk
        if [[ "$usd" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            COST_DAY=$(awk -v v="$usd" 'BEGIN{
                if (v >= 100)      printf "$%.0f", v;
                else if (v < 1)    printf "$%.2f", v;
                else               printf "$%.1f", v;
            }')
        fi
    fi
    [[ "$COST_DAY" != "—" ]] && printf '%s' "$COST_DAY" | cache_set "$COST_KEY"
fi
# Fallback contador legacy si rollup no devolvió nada
if [[ "$COST_DAY" == "—" ]]; then
    SESSION_COUNTER="/tmp/helix-cost-${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H)}"
    if [[ -f "$SESSION_COUNTER" ]]; then
        IFS= read -r cnt < "$SESSION_COUNTER" 2>/dev/null || cnt=0
        COST_DAY="${cnt:-0}c"
    fi
fi

# Snapshot age — bash glob + comparación por mtime sin spawn de ls/head
SNAP_DIR="${HELIX_DIR}/snapshots/${PROJECT_NAME}"
SNAP_AGE="—"
if [[ -d "$SNAP_DIR" ]]; then
    shopt -s nullglob
    _newest_mtime=0
    _newest_file=""
    for _f in "$SNAP_DIR"/*.yaml; do
        _m=$(stat -c %Y "$_f" 2>/dev/null) || continue
        if (( _m > _newest_mtime )); then
            _newest_mtime=$_m
            _newest_file=$_f
        fi
    done
    shopt -u nullglob
    if [[ -n "$_newest_file" ]]; then
        SNAP_AGE=$(human_age $(( $(date +%s) - _newest_mtime )))
    fi
    unset _f _m _newest_mtime _newest_file
fi

# Backlog
BACKLOG_FILE="${CWD}/.claude/memory/helix-backlog.md"
N_BACKLOG=0
[[ -f "$BACKLOG_FILE" ]] && N_BACKLOG=$(grep -cE '^- \[ \]' "$BACKLOG_FILE" 2>/dev/null || echo 0)

# Evolutions + Session — parse JSON stats block en CLAUDE.md en una sola pasada (read+regex)
# Ahorra 6 forks (2× grep|grep|tail) por render.
N_EVOLUTIONS=0
SESSION_NUM=0
if [[ -f "$CLAUDE_MD" ]]; then
    while IFS= read -r _line || [[ -n "$_line" ]]; do
        if [[ "$_line" =~ \"total_aprendizajes\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
            N_EVOLUTIONS="${BASH_REMATCH[1]}"
        fi
        if [[ "$_line" =~ \"total_sesiones\"[[:space:]]*:[[:space:]]*([0-9]+) ]]; then
            SESSION_NUM="${BASH_REMATCH[1]}"
        fi
        # Salir temprano si ambos encontrados
        [[ "$N_EVOLUTIONS" != 0 && "$SESSION_NUM" != 0 ]] && break
    done < "$CLAUDE_MD"
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
            # Split por '|' con IFS — pura bash, sin 3 forks de cut
            IFS='|' read -r N_AGENTS_ACTIVE TOP_AGENTS EXTRA_AGENTS _ <<< "$AGENTS_RESULT"
        fi
    fi
fi
# sanitize inline (sanitize_int aún no definida en este punto)
[[ "$N_AGENTS_ACTIVE" =~ ^[0-9]+$ ]] || N_AGENTS_ACTIVE=0
[[ "$EXTRA_AGENTS" =~ ^[0-9]+$ ]] || EXTRA_AGENTS=0

# Stale: helix-staleness.sh count (cached)
STALE_COUNT="—"
STALE_KEY="stale"
if cache_get_v "$STALE_KEY"; then
    STALE_COUNT="$REPLY"
else
    if [[ -x "${HELIX_DIR}/helpers/helix-staleness.sh" ]]; then
        # asumimos que con --count devuelve un entero; si no, 0
        sc=$(timeout 1 "${HELIX_DIR}/helpers/helix-staleness.sh" --count 2>/dev/null)
        # Extraer primer entero con bash regex en lugar de grep|head
        if [[ "$sc" =~ ^[[:space:]]*([0-9]+) ]]; then
            STALE_COUNT="${BASH_REMATCH[1]}"
        else
            STALE_COUNT=0
        fi
        printf '%s' "$STALE_COUNT" | cache_set "$STALE_KEY"
    else
        STALE_COUNT=0
    fi
fi

# ─────────────────────────────────────────────────────────────
# Sanitize integer values (eliminar whitespace que rompe %d en printf)
# ─────────────────────────────────────────────────────────────
# Pura bash — sin tr fork ni subshell. Ahorra ~1.9s sobre 9 invocaciones (medido).
sanitize_int() {
    local v="${1:-0}"
    v="${v//[[:space:]]/}"
    [[ "$v" =~ ^[0-9]+$ ]] || v=0
    REPLY="$v"
}
sanitize_int "$N_AGENTS";        N_AGENTS="$REPLY"
sanitize_int "$N_SKILLS";        N_SKILLS="$REPLY"
sanitize_int "$N_TOPICS";        N_TOPICS="$REPLY"
sanitize_int "$N_CLAUDE_LINES";  N_CLAUDE_LINES="$REPLY"
sanitize_int "$N_HOOKS";         N_HOOKS="$REPLY"
sanitize_int "$N_BACKLOG";       N_BACKLOG="$REPLY"
sanitize_int "$N_EVOLUTIONS";    N_EVOLUTIONS="$REPLY"
sanitize_int "$SESSION_NUM";     SESSION_NUM="$REPLY"
sanitize_int "$GIT_DIRTY";       GIT_DIRTY="$REPLY"

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
# VEC_DOT semántica: "●" = hay vectores, "○" = esperando, "" = no aplica (hv ausente).
if [[ "$N_VECTORS" == "—" ]]; then
    VEC_DOT=""
elif [[ "$N_VECTORS" == "?" ]]; then
    VEC_DOT="${C_HELIX_SLATE}○${C_RESET}"
elif [[ "$N_VECTORS" -gt 0 ]] 2>/dev/null; then
    VEC_DOT="${C_HELIX_CYAN}●${C_RESET}"
else
    VEC_DOT="${C_HELIX_SLATE}○${C_RESET}"
fi
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

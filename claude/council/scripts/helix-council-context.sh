#!/usr/bin/env bash
# helix-council-context.sh
# Construye el Context Pack que reciben los roles del Council.
#
# Uso:
#   bash helix-council-context.sh "<trigger>" <severity> [project_dir]
#   severity: low | medium | high | critical
#
# Output: YAML denso por stdout. Filtros por relevancia de keywords.
# Niveles L0-L3 decididos por severity.

set -uo pipefail
# Allow individual command failures (grep with no matches is normal here).
# Critical errors handled per-command with explicit checks.

TRIGGER="${1:-}"
SEVERITY="${2:-medium}"
PROJECT_DIR="${3:-$PWD}"

if [[ -z "$TRIGGER" ]]; then
  echo "ERROR: trigger required" >&2
  echo "Usage: $0 \"<trigger>\" <low|medium|high|critical> [project_dir]" >&2
  exit 1
fi

# Decidir context_level por severity
case "$SEVERITY" in
  low)      LEVEL="L0" ;;
  medium)   LEVEL="L1" ;;
  high)     LEVEL="L2" ;;
  critical) LEVEL="L3" ;;
  *)        LEVEL="L1" ;;
esac

# Helpers
HOME_DIR="$HOME"
GLOBAL_CLAUDE_MD="$HOME_DIR/.claude/CLAUDE.md"
PROJECT_CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
BITACORA="$PROJECT_DIR/.claude/memory/helix-bitacora.md"
BACKLOG="$PROJECT_DIR/.claude/memory/helix-backlog.md"
STACK_MANIFEST="$PROJECT_DIR/.claude/memory/helix-stack.md"
SNAPSHOT_DIR="$PROJECT_DIR/.claude/memory/snapshots"

# Extraer keywords del trigger (palabras significativas)
extract_keywords() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
    | tr -s '[:punct:][:space:]' '\n' \
    | grep -E '^[a-z]{4,}$' \
    | grep -vE '^(este|esta|para|sobre|cuando|donde|como|debe|hace|hacer|puede|tiene|with|from|into|para|tener)$' \
    | sort -u
}

KEYWORDS=$(extract_keywords "$TRIGGER")
KW_REGEX=$(echo "$KEYWORDS" | tr '\n' '|' | sed 's/|$//')

# Filtrado: una línea matchea si contiene cualquiera de las keywords
match_keywords() {
  local file="$1"
  [[ -z "$KW_REGEX" || ! -f "$file" ]] && return 1
  grep -iE "($KW_REGEX)" "$file" 2>/dev/null | head -10
}

# Inicio output YAML
echo "---"
echo "# Helix Council — Context Pack"
echo "trigger: \"$(echo "$TRIGGER" | sed 's/"/\\"/g')\""
echo "severity: $SEVERITY"
echo "context_level: $LEVEL"
echo "project_dir: \"$PROJECT_DIR\""
echo "generated_at: \"$(date -u +%FT%TZ)\""
echo "keywords_extracted:"
while IFS= read -r kw; do
  [[ -n "$kw" ]] && echo "  - \"$kw\""
done <<< "$KEYWORDS"
echo ""

# === Stack manifest ===
echo "stack:"
if [[ -f "$STACK_MANIFEST" ]]; then
  TIER=$(grep -E '^tier:' "$STACK_MANIFEST" 2>/dev/null | head -1 | cut -d: -f2 | tr -d ' ')
  CORE_COUNT=$(grep -cE '^- ' "$STACK_MANIFEST" 2>/dev/null || echo 0)
  echo "  tier: ${TIER:-unknown}"
  echo "  components_listed: ${CORE_COUNT}"
  echo "  source: \"$STACK_MANIFEST\""
else
  echo "  tier: not_declared"
  echo "  source: missing"
fi
echo ""

# === Decisiones previas (de CLAUDE.md global + project) ===
echo "decisions_prior:"
for cmd in "$GLOBAL_CLAUDE_MD" "$PROJECT_CLAUDE_MD"; do
  if [[ -f "$cmd" ]]; then
    awk '/^## .*DECISIONES/{flag=1; next} /^## /{flag=0} flag && /^[-*] /' "$cmd" 2>/dev/null \
      | head -20 \
      | sed 's/^/  - /' \
      | sed 's/"/\\"/g'
  fi
done
echo ""

# === Bitácora del proyecto (filtrada por keywords) ===
echo "bitacora_relevant:"
if [[ -f "$BITACORA" ]]; then
  matches=$(match_keywords "$BITACORA")
  if [[ -n "$matches" ]]; then
    echo "$matches" | head -10 | sed 's/^/  - "/' | sed 's/$/"/' | sed 's/"/\\"/g; s/\\\"/"/; s/\\\"$/"/'
  else
    # fallback: últimas 5 entries de la bitácora
    head -20 "$BITACORA" 2>/dev/null | grep -E '^[-*] ' | head -5 \
      | sed 's/^/  - "/' | sed 's/$/"/'
  fi
else
  echo "  []  # no bitácora"
fi
echo ""

# === Evolutions relevantes (de tabla CLAUDE.md global) ===
echo "evolutions_relevant:"
if [[ -f "$GLOBAL_CLAUDE_MD" ]]; then
  matches=$(awk '/^\| #/{flag=1; next} /<!-- EVOLUTION_LOG_END -->/{flag=0} flag' "$GLOBAL_CLAUDE_MD" 2>/dev/null \
    | grep -iE "($KW_REGEX)" 2>/dev/null \
    | head -8)
  if [[ -n "$matches" ]]; then
    echo "$matches" | sed 's/^/  - "/' | sed 's/$/"/' | sed 's/|/-/g'
  else
    echo "  []  # no matches keyword"
  fi
fi
echo ""

# === Backlog activo ===
echo "backlog_active:"
if [[ -f "$BACKLOG" ]]; then
  open_count=$(grep -cE '^[-*] \[ \]' "$BACKLOG" 2>/dev/null || echo 0)
  echo "  count: $open_count"
  if [[ $open_count -gt 0 ]]; then
    echo "  items:"
    grep -E '^[-*] \[ \]' "$BACKLOG" 2>/dev/null | head -5 \
      | sed 's/^/    - "/' | sed 's/$/"/'
  fi
else
  echo "  count: 0"
fi
echo ""

# === Último snapshot ===
echo "snapshot_last:"
if [[ -d "$SNAPSHOT_DIR" ]]; then
  last=$(ls -t "$SNAPSHOT_DIR"/*.yaml 2>/dev/null | head -1)
  if [[ -n "$last" ]]; then
    age=$(( ($(date +%s) - $(stat -c %Y "$last")) / 3600 ))
    echo "  exists: true"
    echo "  age_hours: $age"
    echo "  path: \"$last\""
  else
    echo "  exists: false"
  fi
else
  echo "  exists: false"
fi
echo ""

# === Memory search via hv (si disponible y level >= L2) ===
echo "memory_search:"
if [[ "$LEVEL" =~ ^(L2|L3)$ ]] && command -v hv >/dev/null 2>&1; then
  results=$(timeout 10 hv search "$TRIGGER" --top-k 5 2>/dev/null || echo "")
  if [[ -n "$results" ]]; then
    echo "$results" | head -20 | sed 's/^/  /' || true
  else
    echo "  []  # hv search empty or timeout"
  fi
else
  echo "  []  # skipped (level $LEVEL or hv unavailable)"
fi
echo ""

# === Helix Canon relevante (búsqueda básica) ===
echo "canon_relevant:"
CANON_DIR="$HOME_DIR/.claude/memory/canon"
if [[ -d "$CANON_DIR" ]]; then
  matches=$(grep -rliE "($KW_REGEX)" "$CANON_DIR" 2>/dev/null | head -3 || true)
  if [[ -n "${matches:-}" ]]; then
    echo "$matches" | while IFS= read -r f; do
      echo "  - file: \"$f\""
    done
  else
    echo "  []"
  fi
else
  echo "  []  # canon directory not present"
fi
echo ""

# === Conversation window (placeholder, el orquestador lo llena) ===
echo "conversation_window:"
echo "  - \"<filled by orchestrator from current turn>\""
echo ""

# === Stack components excluded (sirve para Arbiter) ===
echo "stack_excluded:"
if [[ -f "$STACK_MANIFEST" ]]; then
  awk '/^## Excluded/{flag=1; next} /^## /{flag=0} flag && /^- /' "$STACK_MANIFEST" 2>/dev/null \
    | sed 's/^- /  - /'
else
  echo "  []"
fi
echo ""

# === Anti-injection scan del trigger ===
echo "trigger_safety_scan:"
INJECTION_PATTERNS="ignore (previous|prior|all)|disregard.{0,30}instruction|you are now|forget everything|new instruction|<\\|im_(start|end)\\|>"
if echo "$TRIGGER" | grep -qiE "$INJECTION_PATTERNS"; then
  echo "  injection_detected: true"
  echo "  recommendation: ABORT_BEFORE_DELIBERATION"
else
  echo "  injection_detected: false"
  echo "  recommendation: PROCEED"
fi
echo ""

echo "---"
echo "# end of context pack"

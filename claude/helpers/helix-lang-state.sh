#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-lang-state.sh — Gestión de snapshots de estado para S:hash
# El corazón del ahorro real de HELIX-LANG: contexto por referencia, no por re-envío.
#
# Uso:
#   snapshot "estado HL"              → genera hash, guarda, imprime S:xxxx
#   get S:xxxx | xxxx                 → recupera estado completo del hash
#   delta S:xxxx "D:{...}"            → aplica delta, genera nuevo snapshot, imprime S:yyyy
#   list                              → lista todos los snapshots con metadata
#   diff S:xxxx S:yyyy                → muestra diferencia entre dos snapshots
#   gc [--days N]                     → elimina snapshots > N días (default 7)
set -uo pipefail

STATES_DIR="$HOME/.claude/data/helix-states"
BENCH_LOG="$HOME/.claude/data/helix-lang.jsonl"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; GRAY='\033[0;37m'; CYAN='\033[0;36m'; NC='\033[0m'

mkdir -p "$STATES_DIR"

cmd="${1:-list}"
shift || true

# ─── Helper: estimar tokens via python (recibe texto por stdin) ─────────────
_tokens() {
  "${HELIX_PYTHON:-python3}" - <<PYEOF
import re, sys
text = """$1"""
hl_p = len(re.findall(r'(->|<-|=>|<>|:\w|%\d+|\.\w{2,6}|@\w+)', text))
words = max(len(text.split()), 1)
ratio = hl_p / words
chars = len(text)
tokens = chars / 3.2 if ratio > 0.3 else chars / 3.7
print(f"{max(tokens,1):.1f}")
PYEOF
}

# ─── Comando: vocab ────────────────────────────────────────────────────────
if [[ "$cmd" == "vocab" ]]; then
  agents="${1:-}"
  domains="${2:-}"

  if [[ -z "$agents" ]]; then
    echo -e "${YELLOW}[HL-STATE]${NC} Uso: helix-lang-state.sh vocab \"A:{...}\" \"D:{...}\"" >&2
    exit 1
  fi

  vocab_str="VOCAB:{${agents}${domains:+, ${domains}}}"
  hash=$(echo -n "$vocab_str" | sha1sum | cut -c1-8)
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  state_file="$STATES_DIR/${hash}.json"
  tokens=$(_tokens "$vocab_str")

  PYVAR_STATE="$vocab_str" PYVAR_HASH="$hash" PYVAR_TS="$ts" PYVAR_TOKENS="$tokens" \
  "${HELIX_PYTHON:-python3}" - <<'PYEOF' > "$state_file"
import json, os
print(json.dumps({
    'hash':       os.environ['PYVAR_HASH'],
    'ts':         os.environ['PYVAR_TS'],
    'state':      os.environ['PYVAR_STATE'],
    'type':       'vocab',
    'tokens_est': float(os.environ['PYVAR_TOKENS']),
    'chars':      len(os.environ['PYVAR_STATE']),
    'parent':     None
}, ensure_ascii=False))
PYEOF

  echo "{\"ts\":\"$ts\",\"type\":\"snapshot\",\"hash\":\"$hash\",\"state_tokens\":$tokens,\"ref_tokens\":2,\"vocab\":true}" >> "$BENCH_LOG"

  echo -e "${GRAY}  Vocabulario declarado: ~${tokens} tokens → referencia 2 tokens${NC}" >&2
  printf "S:%s" "$hash"

# ─── Comando: snapshot ─────────────────────────────────────────────────────
elif [[ "$cmd" == "snapshot" ]]; then
  state="${1:-}"
  if [[ -z "$state" ]]; then
    echo -e "${YELLOW}[HL-STATE]${NC} Uso: helix-lang-state.sh snapshot \"estado HL\"" >&2
    exit 1
  fi

  hash=$(echo -n "$state" | sha1sum | cut -c1-8)
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  state_file="$STATES_DIR/${hash}.json"
  tokens=$(_tokens "$state")

  PYVAR_STATE="$state" PYVAR_HASH="$hash" PYVAR_TS="$ts" PYVAR_TOKENS="$tokens" \
  "${HELIX_PYTHON:-python3}" - <<'PYEOF' > "$state_file"
import json, os
print(json.dumps({
    'hash': os.environ['PYVAR_HASH'],
    'ts':   os.environ['PYVAR_TS'],
    'state': os.environ['PYVAR_STATE'],
    'tokens_est': float(os.environ['PYVAR_TOKENS']),
    'chars': len(os.environ['PYVAR_STATE']),
    'parent': None
}, ensure_ascii=False))
PYEOF

  # Log en bench
  echo "{\"ts\":\"$ts\",\"type\":\"snapshot\",\"hash\":\"$hash\",\"state_tokens\":$tokens,\"ref_tokens\":2}" >> "$BENCH_LOG"

  echo -e "${GRAY}  Snapshot creado: ~${tokens} tokens → referencia 2 tokens${NC}" >&2
  printf "S:%s" "$hash"

# ─── Comando: get ──────────────────────────────────────────────────────────
elif [[ "$cmd" == "get" ]]; then
  ref="${1:-}"
  hash="${ref#S:}"
  state_file="$STATES_DIR/${hash}.json"

  if [[ ! -f "$state_file" ]]; then
    echo -e "${YELLOW}[HL-STATE]${NC} Hash no encontrado: $hash" >&2
    exit 1
  fi

  "${HELIX_PYTHON:-python3}" -c "import json; print(json.load(open('$state_file'))['state'])"

# ─── Comando: delta ────────────────────────────────────────────────────────
elif [[ "$cmd" == "delta" ]]; then
  ref="${1:-}"
  delta="${2:-}"

  if [[ -z "$ref" || -z "$delta" ]]; then
    echo -e "${YELLOW}[HL-STATE]${NC} Uso: helix-lang-state.sh delta S:xxxx \"D:{...}\"" >&2
    exit 1
  fi

  hash_parent="${ref#S:}"
  state_file="$STATES_DIR/${hash_parent}.json"

  if [[ ! -f "$state_file" ]]; then
    echo -e "${YELLOW}[HL-STATE]${NC} Hash padre no encontrado: $hash_parent" >&2
    exit 1
  fi

  parent_state=$("${HELIX_PYTHON:-python3}" -c "import json; print(json.load(open('$state_file'))['state'])")
  new_state="${parent_state} ${delta}"
  new_hash=$(echo -n "$new_state" | sha1sum | cut -c1-8)
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  new_file="$STATES_DIR/${new_hash}.json"
  tokens=$(_tokens "$new_state")
  delta_tokens=$(_tokens "$delta")

  PYVAR_STATE="$new_state" PYVAR_HASH="$new_hash" PYVAR_TS="$ts" \
  PYVAR_TOKENS="$tokens" PYVAR_PARENT="$hash_parent" PYVAR_DELTA="$delta" \
  "${HELIX_PYTHON:-python3}" - <<'PYEOF' > "$new_file"
import json, os
print(json.dumps({
    'hash':       os.environ['PYVAR_HASH'],
    'ts':         os.environ['PYVAR_TS'],
    'state':      os.environ['PYVAR_STATE'],
    'delta':      os.environ['PYVAR_DELTA'],
    'tokens_est': float(os.environ['PYVAR_TOKENS']),
    'chars':      len(os.environ['PYVAR_STATE']),
    'parent':     os.environ['PYVAR_PARENT']
}, ensure_ascii=False))
PYEOF

  echo "{\"ts\":\"$ts\",\"type\":\"delta\",\"hash\":\"$new_hash\",\"parent\":\"$hash_parent\",\"delta_tokens\":$delta_tokens,\"state_tokens\":$tokens,\"ref_tokens\":2}" >> "$BENCH_LOG"

  echo -e "${GRAY}  Delta aplicado: S:${hash_parent} → S:${new_hash} (~${tokens} tok → 2 tok ref)${NC}" >&2
  printf "S:%s" "$new_hash"

# ─── Comando: list ─────────────────────────────────────────────────────────
elif [[ "$cmd" == "list" ]]; then
  shopt -s nullglob
  files=("$STATES_DIR"/*.json)
  shopt -u nullglob

  if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "${GRAY}[HL-STATE]${NC} Sin snapshots aún."
    exit 0
  fi

  echo -e "\n${BOLD}  HELIX-STATE — ${#files[@]} snapshots${NC}\n"
  for f in "${files[@]}"; do
    "${HELIX_PYTHON:-python3}" - "$f" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
parent = f"← S:{d['parent'][:6]}" if d.get('parent') else "(root)"
delta  = f" [{d['delta'][:50]}]" if d.get('delta') else ""
print(f"  S:{d['hash']}  {d['ts'][:10]}  ~{d['tokens_est']:.0f}tok  {parent}{delta}")
print(f"    {d['state'][:90]}{'...' if len(d['state'])>90 else ''}\n")
PYEOF
  done

# ─── Comando: diff ─────────────────────────────────────────────────────────
elif [[ "$cmd" == "diff" ]]; then
  ref1="${1:-}"
  ref2="${2:-}"
  hash1="${ref1#S:}"
  hash2="${ref2#S:}"

  state1=$("${HELIX_PYTHON:-python3}" -c "import json; print(json.load(open('$STATES_DIR/$hash1.json'))['state'])" 2>/dev/null || echo "NOT FOUND")
  state2=$("${HELIX_PYTHON:-python3}" -c "import json; print(json.load(open('$STATES_DIR/$hash2.json'))['state'])" 2>/dev/null || echo "NOT FOUND")
  delta=$("${HELIX_PYTHON:-python3}" -c "import json; print(json.load(open('$STATES_DIR/$hash2.json')).get('delta','(snapshot raíz)'))" 2>/dev/null || echo "?")

  echo -e "\n${BOLD}  Diff: S:${hash1} → S:${hash2}${NC}"
  echo -e "  ${GRAY}Base:${NC}  $state1"
  echo -e "  ${YELLOW}Delta:${NC} $delta"
  echo -e "  ${GREEN}Nuevo:${NC} $state2\n"

# ─── Comando: gc ───────────────────────────────────────────────────────────
elif [[ "$cmd" == "gc" ]]; then
  days="${1:-7}"
  days="${days#--days}"
  days="${days# }"
  count=0

  shopt -s nullglob
  for f in "$STATES_DIR"/*.json; do
    age=$("${HELIX_PYTHON:-python3}" - "$f" <<'PYEOF'
import json, datetime, sys
d = json.load(open(sys.argv[1]))
ts = datetime.datetime.fromisoformat(d['ts'].replace('Z',''))
print((datetime.datetime.utcnow() - ts).days)
PYEOF
    )
    if [[ "$age" -gt "$days" ]]; then
      rm "$f"
      ((count=count+1)) || true
    fi
  done
  shopt -u nullglob

  echo -e "${GREEN}[HL-STATE]${NC} GC completado: ${count} snapshots eliminados (>${days} días)"

else
  echo -e "${YELLOW}[HL-STATE]${NC} Comando desconocido: $cmd" >&2
  echo "Uso: helix-lang-state.sh [snapshot|get|delta|list|diff|gc]" >&2
  exit 1
fi

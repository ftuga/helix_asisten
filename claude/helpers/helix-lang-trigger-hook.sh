#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-lang-trigger-hook.sh — PreToolUse(Agent): advierte cuando prompt >500 tokens sin HELIX-LANG
# Objetivo Helix: maximizar contexto, reducir costos. Output NO se cachea → comprimirlo es ahorro real.
# No bloqueante (exit 0 + stderr). Cementa el hábito sin requerir que el usuario recuerde.
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import sys, json, os, re

payload_str = os.environ.get("HOOK_PAYLOAD", "")
try:
    data = json.loads(payload_str)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
prompt = tool_input.get("prompt") or ""
description = tool_input.get("description") or ""
agent = (tool_input.get("subagent_type") or "").strip()

# Aproximación: 1 token ≈ 4 chars (conservador para inglés/español)
combined = prompt + " " + description
char_count = len(combined)
approx_tokens = char_count // 4

THRESHOLD_TOKENS = 500

if approx_tokens < THRESHOLD_TOKENS:
    sys.exit(0)  # prompt corto, sin presión

# Detectar marcadores HELIX-LANG (gramática del protocolo)
# Patrones reales del SKILL: A:agent, S:hash, H:hint, T:task, R:result, etc.
HELIX_LANG_MARKERS = [
    r'\bA:[a-zA-Z0-9_-]+',     # agent reference
    r'\bS:[a-f0-9]{6,}',        # state hash
    r'\bT:[A-Z][a-zA-Z0-9_]*',  # task reference
    r'\bR:[A-Z][a-zA-Z0-9_]*',  # result
    r'\bH:[a-zA-Z0-9_]+',       # hint
    r'^\s*[A-Z]:[a-zA-Z]',      # leading short codes
]
has_helix_lang = any(re.search(p, combined, re.MULTILINE) for p in HELIX_LANG_MARKERS)

# Heurística adicional: si tiene MUCHA prosa natural (oraciones largas), es candidato a comprimir
sentences = re.split(r'[.!?]\s+', combined)
long_sentences = [s for s in sentences if len(s) > 80]
prose_heavy = len(long_sentences) >= 3

if not has_helix_lang and prose_heavy:
    # Estimación de ahorro (bench midió 58.7% promedio)
    estimated_savings = int(approx_tokens * 0.587)
    print(
        f"⚡ HELIX-LANG SUGGEST: prompt para Agent('{agent}') ≈{approx_tokens} tokens prosa natural. "
        f"Comprimir vía HELIX-LANG ahorraría ~{estimated_savings} tokens output (output NO se cachea). "
        f"Skill: helix-lang | Helper: ~/.claude/helpers/helix-lang-state.sh",
        file=sys.stderr
    )

sys.exit(0)
PYEOF

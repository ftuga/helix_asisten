#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-read-staleness-hook.sh — PreToolUse(Read):
# Advierte si un helix-*.md de memoria esta desactualizado vs git log.
# NUNCA bloquea (exit 0 siempre). Solo emite warning a stderr.
# Latencia objetivo <30ms; timeout interno 3s.
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import os, sys, json

raw = os.environ.get("HOOK_PAYLOAD", "")
if not raw:
    sys.exit(0)

try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
file_path  = tool_input.get("file_path", "") or ""

if not file_path:
    sys.exit(0)

import re
if not re.search(r'\.claude/memory/helix-.+\.md$', file_path):
    sys.exit(0)

# Verificar que el archivo existe
from pathlib import Path
p = Path(file_path)
if not p.exists():
    sys.exit(0)

sys.exit(42)  # señal: hay que correr staleness check
PYEOF
PY_EXIT=$?

# Si Python no marcó el path como helix-*.md, salir silenciosamente
[[ "$PY_EXIT" -ne 42 ]] && exit 0

# Extraer file_path para pasarlo al script de staleness
FILE_PATH=$(HOOK_PAYLOAD="$PAYLOAD" "${HELIX_PYTHON:-python3}" -c "
import os, json
data = json.loads(os.environ.get('HOOK_PAYLOAD','{}'))
print(data.get('tool_input',{}).get('file_path',''))
" 2>/dev/null || echo "")

[[ -z "$FILE_PATH" ]] && exit 0

# Invocar staleness con timeout de 3s para no bloquear
# Capturar stdout en archivo temporal para poder leer exit code correctamente
_STALE_TMP=$(mktemp 2>/dev/null || echo "/tmp/helix-stale-$$")
timeout 3 bash "$HOME/.claude/helpers/helix-staleness.sh" "$FILE_PATH" > "$_STALE_TMP" 2>/dev/null
STALE_EXIT=$?
STALE_OUT=$(cat "$_STALE_TMP" 2>/dev/null || echo "")
rm -f "$_STALE_TMP"

# exit 1 = stale; exit 124 = timeout (silencioso); exit 0 = ok
if [[ "$STALE_EXIT" -eq 1 && -n "$STALE_OUT" ]]; then
    echo "[helix-staleness] $STALE_OUT — considera /helix-actualiza" >&2
fi

# Siempre exit 0: nunca bloquear la Read
exit 0

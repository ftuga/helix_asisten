#!/usr/bin/env bash
# ============================================================
# sanitize-memory-agents.sh
# Elimina secciones de contexto de proyecto de memory/agents/*.md
#
# Dos mecanismos:
#   1. Markers explícitos:
#      <!-- PROJECT-CONTEXT:START --> ... <!-- PROJECT-CONTEXT:END -->
#   2. Fallback: elimina ## Contexto del proyecto (y su contenido hasta
#      el siguiente ## o EOF) si no hay markers
#
# Uso: bash sanitize-memory-agents.sh <directorio>
# ============================================================
set -euo pipefail

TARGET_DIR="${1:-}"
if [[ -z "$TARGET_DIR" || ! -d "$TARGET_DIR" ]]; then
  echo "Uso: $0 <directorio con *.md>" >&2
  exit 1
fi

SANITIZED=0
FLAGGED=0

for f in "$TARGET_DIR"/*.md; do
  [[ -f "$f" ]] || continue

  # Mecanismo 1: strip markers explícitos
  if grep -q "<!-- PROJECT-CONTEXT:START -->" "$f" 2>/dev/null; then
    python3 - "$f" <<'PYEOF'
import re, sys
path = sys.argv[1]
content = open(path).read()
# Strip todo entre los markers (inclusive)
cleaned = re.sub(
    r'<!-- PROJECT-CONTEXT:START -->.*?<!-- PROJECT-CONTEXT:END -->',
    '',
    content,
    flags=re.DOTALL
).strip() + '\n'
open(path, 'w').write(cleaned)
PYEOF
    SANITIZED=$((SANITIZED + 1))
    continue
  fi

  # Mecanismo 2 (fallback): strip ## Contexto del proyecto hasta el próximo ##
  if grep -q "^## Contexto del proyecto" "$f" 2>/dev/null; then
    python3 - "$f" <<'PYEOF'
import re, sys
path = sys.argv[1]
content = open(path).read()
# Eliminar desde "## Contexto del proyecto" hasta el próximo ## o EOF
cleaned = re.sub(
    r'\n## Contexto del proyecto.*?(?=\n## |\Z)',
    '',
    content,
    flags=re.DOTALL
).strip() + '\n'
open(path, 'w').write(cleaned)
PYEOF
    SANITIZED=$((SANITIZED + 1))
    echo "  ⚠  Fallback sanitize en $(basename $f) — agregar markers PROJECT-CONTEXT para mayor precisión"
    FLAGGED=$((FLAGGED + 1))
    continue
  fi

done

echo "  ✓ sanitize-memory-agents: $SANITIZED archivos procesados (${FLAGGED} por fallback)"

#!/usr/bin/env bash
# helix-staleness.sh — Detecta si un archivo de memoria helix está stale vs git log
# Uso: bash ~/.claude/helpers/helix-staleness.sh <path-al-archivo>
# Exit 0: no stale (o entorno no aplica). Exit 1: stale con mensaje en stdout.

set -euo pipefail

FILE="${1:-}"

# Archivo no proporcionado o no existe → silencioso, exit 0
[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

# Obtener mtime del archivo (segundos epoch)
FILE_MTIME=$(stat -c %Y "$FILE" 2>/dev/null || exit 0)

# Detectar repo git desde el directorio del archivo o PWD
REPO_DIR=$(cd "$(dirname "$FILE")" && git rev-parse --show-toplevel 2>/dev/null || git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "")
[[ -z "$REPO_DIR" ]] && exit 0

# Último commit timestamp del repo
LAST_COMMIT_CT=$(git -C "$REPO_DIR" log -1 --format="%ct" 2>/dev/null || echo "")
[[ -z "$LAST_COMMIT_CT" ]] && exit 0

# No stale: último commit no es posterior al archivo
[[ "$LAST_COMMIT_CT" -le "$FILE_MTIME" ]] && exit 0

# Hay commits posteriores → contar cuántos
N_COMMITS=$(git -C "$REPO_DIR" log --oneline --after="@${FILE_MTIME}" 2>/dev/null | wc -l || echo "?")
FILE_DATE=$(date -d "@${FILE_MTIME}" '+%Y-%m-%d' 2>/dev/null || date -r "$FILE_MTIME" '+%Y-%m-%d' 2>/dev/null || echo "desconocida")

echo "STALE: $(basename "$FILE") (last update: ${FILE_DATE}) — ${N_COMMITS} commit(s) posteriores no reflejados"
exit 1

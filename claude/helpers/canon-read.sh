#!/bin/bash
# canon-read.sh - Helix Canon: lee capítulo de fuente canónica y extrae reglas con citas
# Uso: canon-read.sh <agent> <book_id> <chapter>
# Status: STUB v0.1 — implementación piloto

set -euo pipefail

AGENT="${1:?uso: canon-read.sh <agent> <book_id> <chapter>}"
BOOK_ID="${2:?falta book_id}"
CHAPTER="${3:?falta chapter}"

CANON_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/canon/$AGENT"
LOG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/canon/_cron.log"
mkdir -p "$CANON_DIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] [canon-read] $*" | tee -a "$LOG"; }

# Validacion: el agente debe existir
AGENT_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents/$AGENT.md"
if [[ ! -f "$AGENT_FILE" ]]; then
    log "ERROR: agente $AGENT no existe en $AGENT_FILE"
    exit 1
fi

# Validacion: el frontmatter debe declarar canon
if ! grep -q "^canon:" "$AGENT_FILE"; then
    log "WARN: agente $AGENT no declara campo 'canon:' en frontmatter — saltando"
    exit 0
fi

OUT="$CANON_DIR/$BOOK_ID.md"
log "Iniciando lectura: $AGENT / $BOOK_ID / cap $CHAPTER"

# STUB: por ahora solo deja un placeholder
# TODO Fase 1: integrar con pageindex MCP / context7 para lectura real
# TODO Fase 1: prompt estructurado para extraer reglas con citas
# TODO Fase 1: parser que valida el formato R-<book>-<chapter>-<page>

cat >> "$OUT" <<EOF

<!-- canon-read STUB | $(ts) | cap $CHAPTER -->
## R-${BOOK_ID}-cap${CHAPTER}-PENDING
**Regla:** [pendiente — implementacion fase 1]
**Cita:** $BOOK_ID, Cap $CHAPTER, p.???
**Aplicabilidad:** [pendiente]
**Confianza:** N/A

EOF

log "STUB ejecutado para $AGENT/$BOOK_ID cap $CHAPTER → $OUT"
log "Implementacion real pendiente (ver topics/canon-design.md §Plan de prototipo)"

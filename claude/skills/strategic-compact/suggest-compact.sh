#!/usr/bin/env bash
# suggest-compact.sh — Compactación estratégica para Helix
# Cuenta tool calls por sesión y sugiere /compact en momentos lógicos.
# Fuente original: affaan-m/everything-claude-code (hackathon winner 2025)
# Adaptado para Helix — 2026-03-24

# Configuración (override con variables de entorno)
THRESHOLD="${COMPACT_THRESHOLD:-50}"
INTERVAL="${COMPACT_INTERVAL:-25}"

# Identificador de sesión: usar CLAUDE_SESSION_ID o fallback a fecha/hora
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H)}"
COUNTER_FILE="/tmp/helix-tool-count-${SESSION_ID}"

# Incrementar contador atómicamente
if [[ -f "$COUNTER_FILE" ]]; then
    COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
    COUNT=$((COUNT + 1))
else
    COUNT=1
fi
echo "$COUNT" > "$COUNTER_FILE"

# Decidir si sugerir compactación
should_suggest=false

if [[ "$COUNT" -eq "$THRESHOLD" ]]; then
    should_suggest=true
elif [[ "$COUNT" -gt "$THRESHOLD" ]]; then
    CALLS_AFTER=$((COUNT - THRESHOLD))
    if [[ $((CALLS_AFTER % INTERVAL)) -eq 0 ]]; then
        should_suggest=true
    fi
fi

if [[ "$should_suggest" == "true" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 Helix · Strategic Compact — $COUNT tool calls en esta sesión"
    echo ""
    echo "   Si acabas de terminar una fase (exploración, plan, hito),"
    echo "   considera ejecutar /compact antes de continuar."
    echo ""
    echo "   Qué persiste: instrucciones, TodoWrite, archivos en disco, git."
    echo "   Qué se pierde: análisis, archivos leídos, historial de contexto."
    echo ""
    echo "   → /compact [resumen opcional de lo que quieres preservar]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

exit 0

#!/usr/bin/env bash
# helix-capa0-toggle.sh — Override manual de Capa 0 (FASE 6 OPCIÓN E pre-step)
#
# Permite al usuario forzar OFF de Capa 0 independiente del HW.
# El override gana sobre la heurística HW de helix-capa0-policy.sh.
#
# Uso:
#   helix-capa0-toggle.sh off --session       → desactiva solo esta sesión
#   helix-capa0-toggle.sh off --persistent    → desactiva en todas las sesiones
#   helix-capa0-toggle.sh on                  → reactiva (vuelve a comportamiento HW)
#   helix-capa0-toggle.sh status              → muestra estado actual
#
# El archivo override es ~/.claude/capa0-disabled.
# session-end.sh lo limpia automáticamente si tiene mode:session.
#
# Default Helix: Capa 0 ACTIVADA (según HW). Este toggle solo desactiva.

set -uo pipefail

readonly OVERRIDE_FILE="${HOME}/.claude/capa0-disabled"
readonly POLICY_HELPER="${HOME}/.claude/helpers/helix-capa0-policy.sh"

ACTION="${1:-status}"
MODE_FLAG="${2:-}"

# ─── Helpers ────────────────────────────────────────────────
read_metadata() {
    local key="$1"
    [[ -f "$OVERRIDE_FILE" ]] || { echo ""; return; }
    grep -E "^${key}:" "$OVERRIDE_FILE" 2>/dev/null | head -1 | sed -E "s/^${key}:[[:space:]]*//"
}

usage_error() {
    echo "Error: $1" >&2
    echo "" >&2
    echo "Uso:" >&2
    echo "  helix-capa0-toggle.sh off --session       solo esta sesión" >&2
    echo "  helix-capa0-toggle.sh off --persistent    todas las sesiones" >&2
    echo "  helix-capa0-toggle.sh on                  reactivar" >&2
    echo "  helix-capa0-toggle.sh status              estado actual" >&2
    exit 2
}

# ─── Acciones ────────────────────────────────────────────────
case "$ACTION" in
    off)
        case "$MODE_FLAG" in
            --session)    MODE="session" ;;
            --persistent) MODE="persistent" ;;
            "")           usage_error "off requiere --session o --persistent" ;;
            *)            usage_error "flag desconocido: $MODE_FLAG" ;;
        esac

        cat > "$OVERRIDE_FILE" <<EOF
# Helix Capa 0 — override manual del usuario
# Generado por helix-capa0-toggle.sh
mode: ${MODE}
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
hostname: $(hostname)
EOF
        echo "Capa 0 desactivada (modo: ${MODE})."
        if [[ "$MODE" == "session" ]]; then
            echo "Se reactivará automáticamente al cerrar esta sesión."
        else
            echo "Persistirá hasta /helix_activa_CAPA0 (o helix-capa0-toggle.sh on)."
        fi
        ;;

    on)
        if [[ -f "$OVERRIDE_FILE" ]]; then
            rm -f "$OVERRIDE_FILE"
            echo "Capa 0 reactivada. Comportamiento vuelve a depender del HW."
        else
            echo "Capa 0 ya estaba activada (sin override manual)."
        fi
        ;;

    status)
        echo "── Estado de Capa 0 ──"

        # Override manual
        if [[ -f "$OVERRIDE_FILE" ]]; then
            ovr_mode=$(read_metadata "mode")
            ovr_when=$(read_metadata "created_at")
            echo "Override manual:    ACTIVO (mode=${ovr_mode}, desde ${ovr_when})"
        elif [[ "${HELIX_CAPA0_DISABLED:-0}" == "1" ]]; then
            echo "Override manual:    ACTIVO (env var HELIX_CAPA0_DISABLED=1)"
        else
            echo "Override manual:    ninguno"
        fi

        # HW policy + efectiva
        if [[ -x "$POLICY_HELPER" ]]; then
            policy_json=$(bash "$POLICY_HELPER" --json 2>/dev/null)
            policy=$(echo "$policy_json" | grep -oE '"policy":[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
            reason=$(echo "$policy_json" | grep -oE '"reason":[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
            echo "Policy efectiva:    ${policy}"
            echo "Razón:              ${reason}"
        else
            echo "Policy helper no disponible: $POLICY_HELPER"
        fi
        ;;

    -h|--help|help)
        usage_error "ayuda"
        ;;

    *)
        usage_error "acción desconocida: $ACTION"
        ;;
esac

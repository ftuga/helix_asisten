#!/usr/bin/env bash
# ============================================================
# Helix Capa 0 — Enrutador a modelos Ollama locales
# Uso desde Claude Code (vía Bash tool):
#   bash ~/helix_asisten/scripts/capa0.sh logs   "$(cat archivo.log)"
#   bash ~/helix_asisten/scripts/capa0.sh code   "Explica este error: ..."
#   bash ~/helix_asisten/scripts/capa0.sh transform "class User: ..."
#
# Wireado a HW2 helix-capa0-policy.sh (FASE 9 plan v4):
# - Policy OFF → exit 2 (caller debe escalar a Capa 1 inmediatamente)
# - Policy OPT_IN → permitido pero solo modelos pequeños
# - Policy ON → proceder normal
# - Timeout 30s duro en ollama run → fallback automático
# ============================================================
set -uo pipefail

readonly CAPA0_TIMEOUT="${CAPA0_TIMEOUT:-30}"

MODE="${1:-logs}"
INPUT="${2:-}"

if [[ -z "$INPUT" ]]; then
  echo "❌ Uso: capa0.sh <modo> <input>"
  echo "   Modos: logs | code | transform"
  exit 1
fi

# ─── HW2 policy gate ────────────────────────────────────────
POLICY_HELPER="${HOME}/.claude/helpers/helix-capa0-policy.sh"
if [[ -x "$POLICY_HELPER" ]]; then
  POLICY=$(bash "$POLICY_HELPER" 2>/dev/null || echo "ON")
  if [[ "$POLICY" == "OFF" ]]; then
    echo "⚠️  Capa 0 deshabilitada por HW policy ($(bash "$POLICY_HELPER" --json 2>/dev/null | grep -oE '"reason":[^,]*' | head -1)). Escalando a Capa 1." >&2
    exit 2
  fi
fi

# Verificar que ollama está disponible
if ! command -v ollama &>/dev/null; then
  echo "⚠️  Ollama no está instalado. Escalando a Capa 1." >&2
  exit 2
fi

case "$MODE" in
  logs)
    # helix-scout: análisis de logs, stacktraces, salida Docker
    if ! ollama list 2>/dev/null | grep -q "helix-scout"; then
      echo "⚠️  helix-scout no está instalado. Ejecutar: ollama create helix-scout -f ~/helix_asisten/ollama/helix-scout.Modelfile" >&2
      exit 2
    fi
    if ! timeout "$CAPA0_TIMEOUT" ollama run helix-scout "$INPUT"; then
      echo "⚠️  Timeout ${CAPA0_TIMEOUT}s en helix-scout. Escalando a Capa 1." >&2
      exit 2
    fi
    ;;
  code|transform)
    # helix-coder: bugs, refactors, transformaciones Python↔TS
    if ! ollama list 2>/dev/null | grep -q "helix-coder"; then
      echo "⚠️  helix-coder no está instalado. Ejecutar: ollama create helix-coder -f ~/helix_asisten/ollama/helix-coder.Modelfile" >&2
      exit 2
    fi
    if ! timeout "$CAPA0_TIMEOUT" ollama run helix-coder "$INPUT"; then
      echo "⚠️  Timeout ${CAPA0_TIMEOUT}s en helix-coder. Escalando a Capa 1." >&2
      exit 2
    fi
    ;;
  *)
    echo "❌ Modo desconocido: $MODE. Usar: logs | code | transform"
    exit 1
    ;;
esac

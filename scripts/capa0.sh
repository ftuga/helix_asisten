#!/usr/bin/env bash
# ============================================================
# Helix Capa 0 — Enrutador a modelos Ollama locales
# Uso desde Claude Code (vía Bash tool):
#   bash ~/helix_asisten/scripts/capa0.sh logs   "$(cat archivo.log)"
#   bash ~/helix_asisten/scripts/capa0.sh code   "Explica este error: ..."
#   bash ~/helix_asisten/scripts/capa0.sh transform "class User: ..."
# ============================================================
set -euo pipefail

MODE="${1:-logs}"
INPUT="${2:-}"

if [[ -z "$INPUT" ]]; then
  echo "❌ Uso: capa0.sh <modo> <input>"
  echo "   Modos: logs | code | transform"
  exit 1
fi

# Verificar que ollama está disponible
if ! command -v ollama &>/dev/null; then
  echo "⚠️  Ollama no está instalado. Escalando a Capa 1."
  exit 2
fi

case "$MODE" in
  logs)
    # helix-scout: análisis de logs, stacktraces, salida Docker
    if ! ollama list 2>/dev/null | grep -q "helix-scout"; then
      echo "⚠️  helix-scout no está instalado. Ejecutar: ollama create helix-scout -f ~/helix_asisten/ollama/helix-scout.Modelfile"
      exit 2
    fi
    ollama run helix-scout "$INPUT"
    ;;
  code|transform)
    # helix-coder: bugs, refactors, transformaciones Python↔TS
    if ! ollama list 2>/dev/null | grep -q "helix-coder"; then
      echo "⚠️  helix-coder no está instalado. Ejecutar: ollama create helix-coder -f ~/helix_asisten/ollama/helix-coder.Modelfile"
      exit 2
    fi
    ollama run helix-coder "$INPUT"
    ;;
  *)
    echo "❌ Modo desconocido: $MODE. Usar: logs | code | transform"
    exit 1
    ;;
esac

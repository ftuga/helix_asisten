#!/usr/bin/env bash
# hv — Helix Vector: wrapper rápido para helix-vector.py
# Uso: hv search <collection> "<query>" [--top-k N]
#      hv store <collection> "<text>" [--meta key=val]
#      hv index-memories
#      hv index-agents
#      hv index-project [directorio] [collection]
#      hv sync   → re-indexa memorias + agentes modificados
#      hv status → muestra colecciones y conteos

set -euo pipefail

SCRIPT="$HOME/.claude/helix-vector.py"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"

_qdrant_up() {
    curl -sf "$QDRANT_URL/healthz" &>/dev/null
}

_ensure_qdrant() {
    if ! _qdrant_up; then
        echo "⚠️  Qdrant no está corriendo. Iniciando..." >&2
        docker start helix-qdrant &>/dev/null || {
            echo "❌ No se pudo iniciar helix-qdrant. Ejecuta: docker start helix-qdrant" >&2
            exit 1
        }
        sleep 2
    fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    search)
        _ensure_qdrant
        # Si busca en helix_agents, usar --translate por defecto (queries en español, descriptions en inglés)
        collection="${2:-}"
        if [[ "$collection" == "helix_agents" ]] && [[ "$*" != *"--translate"* ]]; then
            python3 "$SCRIPT" search "$@" --translate
        else
            python3 "$SCRIPT" search "$@"
        fi
        ;;
    store|index-dir|index-memories|index-agents|list-collections|delete)
        _ensure_qdrant
        python3 "$SCRIPT" "$cmd" "$@"
        ;;

    index-project)
        _ensure_qdrant
        DIR="${1:-$(pwd)}"
        COLLECTION="${2:-helix_project_$(basename "$DIR")}"
        echo "Indexando proyecto: $DIR → colección: $COLLECTION" >&2
        python3 "$SCRIPT" index-dir "$DIR" "$COLLECTION" --pattern "*.md"
        python3 "$SCRIPT" index-dir "$DIR" "$COLLECTION" --pattern "*.py"
        python3 "$SCRIPT" index-dir "$DIR" "$COLLECTION" --pattern "*.ts"
        python3 "$SCRIPT" index-dir "$DIR" "$COLLECTION" --pattern "*.tsx"
        ;;

    sync)
        _ensure_qdrant
        echo "🔄 Sincronizando memorias..." >&2
        python3 "$SCRIPT" index-memories
        echo "🔄 Sincronizando agentes..." >&2
        python3 "$SCRIPT" index-agents
        echo "✅ Sync completo" >&2
        ;;

    status)
        _ensure_qdrant
        python3 "$SCRIPT" list-collections | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('Colecciones en Helix Vector Store:')
for c in d['collections']:
    print(f\"  {c['name']:<35} {c['points_count']:>6} puntos\")
"
        ;;

    help|--help|-h)
        echo "hv — Helix Vector Memory"
        echo ""
        echo "Comandos:"
        echo "  hv search <collection> \"<query>\" [--top-k 5] [--threshold 0.55]"
        echo "  hv store  <collection> \"<text>\" [--meta key=val ...]"
        echo "  hv index-memories              → indexa ~/.claude/memory/"
        echo "  hv index-agents                → indexa agent descriptions"
        echo "  hv index-project [dir] [col]   → indexa código del proyecto"
        echo "  hv sync                        → re-indexa memorias + agentes"
        echo "  hv status                      → muestra colecciones y conteos"
        ;;

    *)
        echo "Comando desconocido: $cmd. Usa 'hv help'" >&2
        exit 1
        ;;
esac

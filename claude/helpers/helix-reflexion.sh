#!/usr/bin/env bash
# helix-reflexion.sh — Memoria semántica de errores y resoluciones (Reflexion pattern)
# Almacena patrones de error resueltos en Qdrant y los recupera por similitud
#
# Uso:
#   store  "<error>" "<resolución>" [categoría] [proyecto]
#   search "<descripción del error>" [top-k] [threshold]
#   list   [limit]
#
# Colección Qdrant: helix_reflexions
set -uo pipefail

GLOBAL_DIR="$HOME/.claude"
HV="$GLOBAL_DIR/helix-vector.py"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
REFLEXIONS_LOG="$GLOBAL_DIR/memory/reflexions.jsonl"

cmd="${1:-help}"
shift || true

_qdrant_up() { curl -sf "$QDRANT_URL/healthz" &>/dev/null; }
_ensure_qdrant() {
    _qdrant_up && return 0
    docker start helix-qdrant &>/dev/null && sleep 2 || {
        echo "❌ Qdrant no disponible" >&2; return 1
    }
}

GREEN='\033[0;32m'; BLUE='\033[0;34m'; GRAY='\033[0;37m'; NC='\033[0m'

case "$cmd" in

# ─────────────────────────────────────────────────────────────
store)
    ERROR_DESC="${1:-}"
    RESOLUTION="${2:-}"
    CATEGORIA="${3:-funcionalidad}"
    PROYECTO="${4:-}"

    [[ -z "$ERROR_DESC" || -z "$RESOLUTION" ]] && {
        echo "Uso: helix-reflexion.sh store '<error>' '<resolución>' [cat] [proj]" >&2
        exit 1
    }

    _ensure_qdrant || exit 1

    SHORT_DATE=$(date '+%Y-%m-%d')
    EMBED_TEXT="ERROR PATTERN: $ERROR_DESC | RESOLUTION: $RESOLUTION | CATEGORY: $CATEGORIA"

    # nargs="*" en helix-vector.py requiere todos los valores en un solo --meta
    SAFE_ERROR=$(echo "$ERROR_DESC" | head -c 120 | tr ' ' '_' | tr -cd '[:print:]' | tr -d '"\\')
    SAFE_RESOL=$(echo "$RESOLUTION" | head -c 150 | tr ' ' '_' | tr -cd '[:print:]' | tr -d '"\\')
    SAFE_PROJ=$(echo "$PROYECTO" | tr ' ' '_' | tr -cd '[:alnum:]_-')

    RESULT=$(python3 "$HV" store helix_reflexions "$EMBED_TEXT" \
        --meta \
            "error=$SAFE_ERROR" \
            "resolution=$SAFE_RESOL" \
            "categoria=$CATEGORIA" \
            "proyecto=$SAFE_PROJ" \
            "date=$SHORT_DATE" \
            "type=reflexion" \
        2>/dev/null)

    if echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if d.get('status')=='ok' else 1)" 2>/dev/null; then
        echo -e "${GREEN}✅ Reflexión almacenada${NC}"
        echo "   Error: ${ERROR_DESC:0:70}"
        echo "   Resolución: ${RESOLUTION:0:80}"

        # Backup JSONL local
        python3 -c "
import json, sys
entry = {
    'ts': '$(date +%Y-%m-%d\ %H:%M)',
    'error': sys.argv[1],
    'resolution': sys.argv[2],
    'categoria': sys.argv[3],
    'proyecto': sys.argv[4],
}
with open('$REFLEXIONS_LOG', 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
" "$ERROR_DESC" "$RESOLUTION" "$CATEGORIA" "$PROYECTO"
    else
        echo "⚠️  No se pudo almacenar en Qdrant. Guardado solo en JSONL local."
        python3 -c "
import json, sys
entry = {'ts': '$(date +%Y-%m-%d\ %H:%M)', 'error': sys.argv[1], 'resolution': sys.argv[2], 'categoria': sys.argv[3], 'proyecto': sys.argv[4]}
with open('$REFLEXIONS_LOG', 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')
" "$ERROR_DESC" "$RESOLUTION" "$CATEGORIA" "$PROYECTO"
    fi
    ;;

# ─────────────────────────────────────────────────────────────
search)
    QUERY="${1:-}"
    TOP_K="${2:-3}"
    THRESHOLD="${3:-0.65}"

    [[ -z "$QUERY" ]] && {
        echo "Uso: helix-reflexion.sh search '<error>' [top-k] [threshold]" >&2; exit 1
    }

    _ensure_qdrant || {
        echo "Qdrant no disponible — buscando en JSONL local..." >&2
        _search_local "$QUERY" "$TOP_K"
        exit 0
    }

    export HV_SEARCH_QUERY="$QUERY"
    export HV_SEARCH_TOPK="$TOP_K"
    export HV_SEARCH_THRESHOLD="$THRESHOLD"
    export HV_SCRIPT_PATH="$HV"

    python3 - <<'PYEOF'
import json, sys, os, subprocess

hv    = os.environ['HV_SCRIPT_PATH']
query = os.environ['HV_SEARCH_QUERY']
topk  = os.environ['HV_SEARCH_TOPK']
thr   = os.environ['HV_SEARCH_THRESHOLD']

result = subprocess.run(
    ['python3', hv, 'search', 'helix_reflexions', query, '--top-k', topk, '--threshold', thr],
    capture_output=True, text=True
)

BLUE  = '\033[0;34m'; GREEN = '\033[0;32m'; GRAY = '\033[0;37m'; NC = '\033[0m'

try:
    data    = json.loads(result.stdout)
    results = data.get('results', [])
except:
    print(f"{GRAY}Error al parsear respuesta de Qdrant{NC}")
    sys.exit(0)

if not results:
    print(f"{GRAY}Sin reflexiones similares (threshold: {thr}){NC}")
    sys.exit(0)

print(f"\n{BLUE}⬡ Helix Reflexion — {len(results)} coincidencia(s):{NC}")
for i, r in enumerate(results, 1):
    score   = r.get('score', 0)
    payload = r.get('payload', {})
    # Los valores pueden estar con _ o sin _ según cómo fueron guardados
    error = (payload.get('error') or payload.get('text', '')[:80]).replace('_', ' ')[:80]
    resol = payload.get('resolution', '').replace('_', ' ')[:100]
    cat   = payload.get('categoria', payload.get('category', ''))
    date  = payload.get('date', '')
    conf  = 'alta' if score > 0.85 else 'media' if score > 0.72 else 'baja'
    print(f"\n  {GREEN}[{i}] confianza {conf} ({score:.3f}) | {cat} | {date}{NC}")
    print(f"  Patrón:     {error}")
    if resol:
        print(f"  Resolución: {resol}")
PYEOF
    ;;

# ─────────────────────────────────────────────────────────────
list)
    LIMIT="${1:-15}"
    if [[ -f "$REFLEXIONS_LOG" ]]; then
        echo -e "${BLUE}Reflexiones almacenadas (últimas $LIMIT):${NC}"
        python3 -c "
import json
lines = open('$REFLEXIONS_LOG').readlines()[-$LIMIT:]
for l in lines:
    d = json.loads(l.strip())
    print(f\"  [{d['ts']}] [{d.get('categoria','?')}] {d['error'][:65]}\")
"
    else
        echo "Sin reflexiones almacenadas aún. Usa: helix-reflexion.sh store ..."
    fi
    ;;

# ─────────────────────────────────────────────────────────────
*)
    echo -e "${BLUE}helix-reflexion.sh — Memoria semántica de errores${NC}"
    echo ""
    echo "Comandos:"
    echo "  store  '<error>' '<resolución>' [categoría] [proyecto]"
    echo "  search '<descripción del error>' [top-k] [threshold]"
    echo "  list   [limit]"
    echo ""
    echo "Colección Qdrant: helix_reflexions"
    echo "Backup local:     $REFLEXIONS_LOG"
    ;;
esac

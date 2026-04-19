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

    CREATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # ── Quarantine check — reflexión va como trusted=false hasta feedback explícito ──
    # Flags: --trusted fuerza trusted=true (solo uso manual del operador)
    TRUSTED_FLAG="false"
    for arg in "$@"; do
        [[ "$arg" == "--trusted" ]] && TRUSTED_FLAG="true"
    done

    # Scanner de contenido malicioso antes de indexar
    if GUARD_TEXT="$ERROR_DESC||$RESOLUTION" python3 - <<'PYSCAN'
import os, re, sys
text = os.environ.get("GUARD_TEXT", "")
BAD = [
    r"(?i)\bcurl\s+\S+\s*\|\s*(bash|sh)",
    r"(?i)ignore\s+(all\s+)?previous\s+instructions",
    r"[\u200b-\u200f\u202a-\u202e\u2060-\u206f]",
    r"(?<![A-Za-z0-9+/=])[A-Za-z0-9+/]{200,}={0,2}(?![A-Za-z0-9+/=])",
]
for pat in BAD:
    if re.search(pat, text):
        print("🛡️  Reflexion rechazada: contenido sospechoso", file=sys.stderr)
        sys.exit(1)
PYSCAN
    then :; else
        exit 1
    fi

    RESULT=$(python3 "$HV" store helix_reflexions "$EMBED_TEXT" \
        --meta \
            "error=$SAFE_ERROR" \
            "resolution=$SAFE_RESOL" \
            "categoria=$CATEGORIA" \
            "proyecto=$SAFE_PROJ" \
            "date=$SHORT_DATE" \
            "created_at=$CREATED_AT" \
            "hits=0" \
            "useful_hits=0" \
            "trusted=$TRUSTED_FLAG" \
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
    INCLUDE_UNTRUSTED="false"
    for arg in "$@"; do
        [[ "$arg" == "--include-untrusted" ]] && INCLUDE_UNTRUSTED="true"
    done
    export HV_INCLUDE_UNTRUSTED="$INCLUDE_UNTRUSTED"

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

# Filtrar untrusted salvo flag --include-untrusted
include_untrusted = os.environ.get('HV_INCLUDE_UNTRUSTED', 'false') == 'true'
if not include_untrusted:
    filtered = []
    skipped = 0
    for r in results:
        pl = r.get('payload', {}) or {}
        # trusted puede ser bool o string
        t = pl.get('trusted', True)
        if isinstance(t, str): t = t.lower() == 'true'
        if t:
            filtered.append(r)
        else:
            skipped += 1
    if skipped:
        print(f"{GRAY}(filtradas {skipped} reflexiones untrusted — usar --include-untrusted para verlas){NC}")
    results = filtered

if not results:
    print(f"{GRAY}Sin reflexiones similares trusted (threshold: {thr}){NC}")
    sys.exit(0)

print(f"\n{BLUE}⬡ Helix Reflexion — {len(results)} coincidencia(s):{NC}")
import urllib.request, json as _json
QDRANT = os.environ.get('QDRANT_URL', 'http://localhost:6333')

def _bump_hits(pid):
    """Incrementa contador 'hits' en payload; silencioso si falla."""
    try:
        # Leer hits actual
        req = urllib.request.Request(f"{QDRANT}/collections/helix_reflexions/points/{pid}")
        with urllib.request.urlopen(req, timeout=2) as r:
            cur = _json.loads(r.read()).get('result', {}).get('payload', {})
        new_hits = int(cur.get('hits', 0)) + 1
        # Set payload (merge)
        body = _json.dumps({"payload": {"hits": new_hits}, "points": [pid]}).encode()
        req2 = urllib.request.Request(
            f"{QDRANT}/collections/helix_reflexions/points/payload?wait=true",
            data=body, method='POST',
            headers={'Content-Type': 'application/json'}
        )
        urllib.request.urlopen(req2, timeout=2).read()
    except Exception:
        pass

for i, r in enumerate(results, 1):
    score   = r.get('score', 0)
    pid     = r.get('id', '')
    payload = r.get('payload', {})
    error = (payload.get('error') or payload.get('text', '')[:80]).replace('_', ' ')[:80]
    resol = payload.get('resolution', '').replace('_', ' ')[:100]
    cat   = payload.get('categoria', payload.get('category', ''))
    date  = payload.get('date', '')
    hits  = payload.get('hits', 0)
    useful = payload.get('useful_hits', 0)
    conf  = 'alta' if score > 0.85 else 'media' if score > 0.72 else 'baja'
    meta_str = f" | hits={hits} useful={useful}" if (hits or useful) else ""
    print(f"\n  {GREEN}[{i}] id={pid} confianza {conf} ({score:.3f}) | {cat} | {date}{meta_str}{NC}")
    print(f"  Patrón:     {error}")
    if resol:
        print(f"  Resolución: {resol}")
    _bump_hits(pid)
print(f"\n{GRAY}💡 Feedback: helix-reflexion.sh feedback <id> useful|stale{NC}")
PYEOF
    ;;

# ─────────────────────────────────────────────────────────────
feedback)
    POINT_ID="${1:-}"
    VERDICT="${2:-useful}"   # useful | stale
    [[ -z "$POINT_ID" ]] && {
        echo "Uso: helix-reflexion.sh feedback <point_id> useful|stale" >&2; exit 1
    }
    _ensure_qdrant || exit 1

    export HV_PID="$POINT_ID" HV_VERDICT="$VERDICT" HV_URL="$QDRANT_URL"
    python3 <<'PYEOF'
import os, json, urllib.request
URL = os.environ['HV_URL']; pid = os.environ['HV_PID']; verdict = os.environ['HV_VERDICT']

# Leer estado actual
try:
    with urllib.request.urlopen(f"{URL}/collections/helix_reflexions/points/{pid}", timeout=3) as r:
        cur = json.loads(r.read()).get('result', {}).get('payload', {}) or {}
except Exception as e:
    print(f"❌ No se pudo leer point {pid}: {e}"); raise SystemExit(1)

if verdict == 'useful':
    new_useful = int(cur.get('useful_hits', 0)) + 1
    # Marcar como trusted después de 1er feedback útil (promoción por validación humana)
    patch = {"useful_hits": new_useful, "stale": False, "trusted": True}
    msg = f"✅ Reflexión {pid} marcada útil (useful_hits={new_useful}, trusted=True)"
elif verdict == 'stale':
    patch = {"stale": True}
    msg = f"🗑️  Reflexión {pid} marcada stale — candidata a prune"
else:
    print(f"Verdict inválido: {verdict}. Usa 'useful' o 'stale'"); raise SystemExit(1)

body = json.dumps({"payload": patch, "points": [pid]}).encode()
req = urllib.request.Request(
    f"{URL}/collections/helix_reflexions/points/payload?wait=true",
    data=body, method='POST',
    headers={'Content-Type': 'application/json'}
)
try:
    urllib.request.urlopen(req, timeout=3).read()
    print(msg)
except Exception as e:
    print(f"❌ No se pudo actualizar: {e}"); raise SystemExit(1)
PYEOF
    ;;

# ─────────────────────────────────────────────────────────────
prune)
    # Elimina reflexiones con stale=true O (older>N días Y useful_hits=0)
    OLDER_DAYS="${1:-60}"
    DRY_RUN="${2:-}"
    _ensure_qdrant || exit 1

    export HV_OLDER="$OLDER_DAYS" HV_URL="$QDRANT_URL" HV_DRY="$DRY_RUN"
    python3 <<'PYEOF'
import os, json, urllib.request
from datetime import datetime, timedelta, timezone
URL = os.environ['HV_URL']; older = int(os.environ['HV_OLDER']); dry = os.environ.get('HV_DRY') == '--dry-run'

cutoff = (datetime.now(timezone.utc) - timedelta(days=older)).isoformat()

# Scroll all points
candidates_stale = []
candidates_old = []
offset = None
while True:
    body = {"limit": 100, "with_payload": True, "with_vector": False}
    if offset is not None: body["offset"] = offset
    req = urllib.request.Request(
        f"{URL}/collections/helix_reflexions/points/scroll",
        data=json.dumps(body).encode(), method='POST',
        headers={'Content-Type': 'application/json'}
    )
    try:
        resp = json.loads(urllib.request.urlopen(req, timeout=5).read()).get('result', {})
    except Exception as e:
        print(f"❌ scroll failed: {e}"); raise SystemExit(1)
    for pt in resp.get('points', []):
        pid = pt['id']; pl = pt.get('payload') or {}
        if pl.get('stale'):
            candidates_stale.append(pid); continue
        useful = int(pl.get('useful_hits', 0))
        created = pl.get('created_at', '')
        if useful == 0 and created and created < cutoff:
            candidates_old.append(pid)
    offset = resp.get('next_page_offset')
    if not offset: break

to_delete = candidates_stale + candidates_old
print(f"Candidatos a prune: stale={len(candidates_stale)} old_unused(>{older}d)={len(candidates_old)}")
if not to_delete:
    print("Nada que eliminar."); raise SystemExit(0)
if dry:
    print(f"(dry-run) Se eliminarían: {to_delete}"); raise SystemExit(0)

body = json.dumps({"points": to_delete}).encode()
req = urllib.request.Request(
    f"{URL}/collections/helix_reflexions/points/delete?wait=true",
    data=body, method='POST',
    headers={'Content-Type': 'application/json'}
)
try:
    urllib.request.urlopen(req, timeout=5).read()
    print(f"🗑️  Eliminados {len(to_delete)} puntos")
except Exception as e:
    print(f"❌ delete failed: {e}"); raise SystemExit(1)
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
    echo "  store    '<error>' '<resolución>' [categoría] [proyecto]"
    echo "  search   '<descripción del error>' [top-k] [threshold]"
    echo "  feedback <point_id> useful|stale   — marca reflexión recuperada"
    echo "  prune    [older_days=60] [--dry-run] — limpia stales + unused>N días"
    echo "  list     [limit]"
    echo ""
    echo "Colección Qdrant: helix_reflexions"
    echo "Backup local:     $REFLEXIONS_LOG"
    ;;
esac

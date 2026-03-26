#!/usr/bin/env bash
# helix-project-index.sh — Indexa el codebase de un proyecto en su propia colección Qdrant
# Cada proyecto es AISLADO: no se mezcla con global ni con otros proyectos.
#
# Uso:
#   helix-project-index.sh [PROJECT_DIR]           → indexar proyecto
#   helix-project-index.sh --search "query"        → buscar en proyecto actual
#   helix-project-index.sh --drop                  → borrar índice del proyecto
#   helix-project-index.sh --status                → ver estado del índice
#
# Colección: proj_{nombre_sanitizado_del_directorio}
# Ejemplo: /home/user/mis-proyectos/facturacion → proj_facturacion
# Esta colección SOLO existe localmente. Nunca sube al repo.

set -euo pipefail

VECTOR_PY="$HOME/.claude/helix-vector.py"
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"

# ── Colores ────────────────────────────────────────────────
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[0;34m'; NC='\033[0m'

_qdrant_up() { curl -sf "$QDRANT_URL/healthz" &>/dev/null; }

_ensure_qdrant() {
    if ! _qdrant_up; then
        echo -e "${Y}Iniciando Qdrant...${NC}" >&2
        docker start helix-qdrant &>/dev/null && sleep 2
    fi
}

# ── Detectar proyecto ────────────────────────────────────
_detect_project_dir() {
    local dir="${1:-$PWD}"
    # Buscar raíz del proyecto (tiene CLAUDE.md o .git)
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/CLAUDE.md" ]] || [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "$PWD"
}

_collection_name() {
    local dir="$1"
    local name
    name=$(basename "$dir" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | cut -c1-40)
    echo "proj_${name}"
}

# ── Extensiones indexables ────────────────────────────────
PATTERNS=("*.py" "*.ts" "*.tsx" "*.js" "*.jsx" "*.go" "*.md" "*.yaml" "*.yml" "*.json" "*.sql" "*.sh")

# ── Exclusiones ──────────────────────────────────────────
EXCLUDE_DIRS=("node_modules" ".git" "__pycache__" ".venv" "venv" "dist" "build" ".next" "coverage" "*.egg-info")

_index_project() {
    local project_dir="$1"
    local collection
    collection=$(_collection_name "$project_dir")

    echo -e "${B}Indexando proyecto: ${NC}$(basename "$project_dir")"
    echo -e "${B}Colección: ${NC}$collection"
    echo ""

    _ensure_qdrant

    local total=0
    local errors=0

    for pattern in "${PATTERNS[@]}"; do
        # Build exclude args
        local exclude_args=()
        for exc in "${EXCLUDE_DIRS[@]}"; do
            exclude_args+=(--exclude-dir="$exc")
        done

        # Find files matching pattern, excluding unwanted dirs
        while IFS= read -r fpath; do
            [[ -z "$fpath" ]] && continue
            local size
            size=$(wc -c < "$fpath" 2>/dev/null || echo 0)
            # Skip files > 50KB (demasiado grandes para un chunk)
            [[ "$size" -gt 51200 ]] && continue

            result=$(python3 "$VECTOR_PY" store "$collection" \
                "$(cat "$fpath" 2>/dev/null | head -c 3000)" \
                --meta "file=$fpath" "project=$(basename "$project_dir")" "pattern=$pattern" \
                2>/dev/null) && total=$((total+1)) || errors=$((errors+1))

            [[ "$((total % 10))" == "0" ]] && echo -ne "\r  Indexados: $total archivos..." >&2
        done < <(find "$project_dir" -name "$pattern" \
            $(printf " -not -path '*/%s/*'" "${EXCLUDE_DIRS[@]}") \
            -type f 2>/dev/null)
    done

    echo ""
    echo -e "${G}✓ Completado: $total archivos indexados${NC} ($errors errores)"

    # Guardar metadata del índice
    local meta_file="$project_dir/.claude/vector-index.json"
    mkdir -p "$(dirname "$meta_file")"
    python3 -c "
import json
from datetime import datetime
data = {
    'collection': '$collection',
    'project': '$(basename "$project_dir")',
    'indexed_at': datetime.utcnow().isoformat(),
    'total_files': $total,
    'project_dir': '$project_dir'
}
with open('$meta_file', 'w') as f:
    json.dump(data, f, indent=2)
print('Metadata guardada en $meta_file')
"
}

_search_project() {
    local query="$1"
    local project_dir
    project_dir=$(_detect_project_dir)
    local collection
    collection=$(_collection_name "$project_dir")

    _ensure_qdrant

    python3 "$VECTOR_PY" search "$collection" "$query" --top-k 5 | python3 -c "
import json,sys
d = json.load(sys.stdin)
results = d.get('results', [])
if not results:
    print('Sin resultados para: $query')
    sys.exit(0)
print(f'Top {len(results)} resultados en $(basename "$project_dir"):')
for r in results:
    f = r['payload'].get('file','?')
    # Mostrar path relativo
    f_short = f.replace('$project_dir/', '')
    print(f\"  {r['score']:.3f}  {f_short}\")
"
}

_drop_project() {
    local project_dir
    project_dir=$(_detect_project_dir)
    local collection
    collection=$(_collection_name "$project_dir")

    _ensure_qdrant

    python3 -c "
from qdrant_client import QdrantClient
c = QdrantClient(url='$QDRANT_URL')
cols = [x.name for x in c.get_collections().collections]
if '$collection' in cols:
    c.delete_collection('$collection')
    print('✓ Colección $collection eliminada')
else:
    print('Colección $collection no existe')
"
}

_status_project() {
    local project_dir
    project_dir=$(_detect_project_dir "$@")
    local collection
    collection=$(_collection_name "$project_dir")

    _ensure_qdrant

    python3 -c "
from qdrant_client import QdrantClient
import json, os
from pathlib import Path

c = QdrantClient(url='$QDRANT_URL')
cols = [x.name for x in c.get_collections().collections]

print(f'Proyecto: $(basename "$project_dir")')
print(f'Colección: $collection')

if '$collection' in cols:
    info = c.get_collection('$collection')
    print(f'Estado: ✓ indexado ({info.points_count} vectores)')
else:
    print('Estado: ✗ no indexado (ejecutar: helix-project-index.sh)')

# Leer metadata si existe
meta = Path('$project_dir/.claude/vector-index.json')
if meta.exists():
    d = json.loads(meta.read_text())
    print(f'Última indexación: {d.get(\"indexed_at\",\"?\")}')
    print(f'Archivos indexados: {d.get(\"total_files\",\"?\")}')
"
}

# ── Main ─────────────────────────────────────────────────
case "${1:-index}" in
    --search|-s)
        _search_project "${2:-}"
        ;;
    --drop)
        _drop_project
        ;;
    --status)
        _status_project "${2:-}"
        ;;
    --help|-h)
        echo "Uso: helix-project-index.sh [PROJECT_DIR | --search 'query' | --drop | --status]"
        ;;
    *)
        _index_project "${1:-$(_detect_project_dir)}"
        ;;
esac

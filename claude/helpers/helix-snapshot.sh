#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-snapshot.sh — Persistencia conversacional + resume opt-in
# Stack: 100% local, sin egress, sin deps externas.
# Diseño: ~/.claude/memory/topics/conversation-context-research.md
#
# Subcomandos:
#   capture           Lee YAML por stdin, persiste a ~/.claude/snapshots/<project>/<ts>.yaml
#   resume [project]  Imprime resumen ejecutivo del snapshot más reciente del proyecto
#   list [project]    Lista snapshots con metadata
#   show <file>       Imprime snapshot completo
#   archive           Mueve snapshots >7d a archive/
#   prune             Elimina archives >30d
#   stale-check <f>   Marca snapshot como stale si >24h o git log posterior

set -euo pipefail

SNAPSHOTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/snapshots"
mkdir -p "$SNAPSHOTS_DIR"

# Auto-detección de proyecto (varios fallbacks)
detect_project() {
    # Override explícito vía env var HELIX_SNAPSHOT_PROJECT
    if [[ -n "${HELIX_SNAPSHOT_PROJECT:-}" ]]; then
        echo "$HELIX_SNAPSHOT_PROJECT"
        return 0
    fi

    local dir="${PROJECT_ROOT:-$PWD}"
    local original_dir="$dir"

    # Búsqueda 1: ascender buscando CLAUDE.md en root
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/CLAUDE.md" && "$dir" != "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ]]; then
            basename "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # Búsqueda 2: en el dir original, mirar subdirs comunes (claude/, .claude/)
    for sub in "claude" ".claude" "template"; do
        if [[ -f "$original_dir/$sub/CLAUDE.md" ]]; then
            basename "$original_dir"
            return 0
        fi
    done

    # Búsqueda 3: si dir original tiene .git o package.json/requirements.txt — usar nombre
    if [[ -d "$original_dir/.git" ]] \
        || [[ -f "$original_dir/package.json" ]] \
        || [[ -f "$original_dir/requirements.txt" ]] \
        || [[ -f "$original_dir/pyproject.toml" ]] \
        || [[ -f "$original_dir/Cargo.toml" ]] \
        || [[ -f "$original_dir/go.mod" ]]; then
        basename "$original_dir"
        return 0
    fi

    echo "global"
}

cmd_capture() {
    local project
    project=$(detect_project)
    local proj_dir="$SNAPSHOTS_DIR/$project"
    mkdir -p "$proj_dir"

    local ts
    ts=$(date '+%Y%m%d-%H%M%S')
    local out="$proj_dir/$ts.yaml"

    # Leer YAML del usuario por stdin
    local user_yaml
    user_yaml=$(cat)

    # Validar mínimamente
    if [[ -z "$user_yaml" ]] || ! grep -q "^summary:" <<< "$user_yaml"; then
        echo "ERROR: stdin debe contener YAML con al menos 'summary:' field" >&2
        exit 1
    fi

    # Generar metadata automática + concatenar con user input
    cat > "$out" <<EOF
# Helix Conversation Snapshot
# Generated: $(date -Iseconds)
# Project: $project
# Schema: ~/.claude/memory/topics/conversation-context-research.md §D5

session_id: ${HELIX_SESSION_ID:-$(uuidgen 2>/dev/null || echo "$(date +%s)-$$")}
project: $project
captured_at: $(date -Iseconds)
host: $(hostname -s)

EOF
    echo "$user_yaml" >> "$out"

    # Permisos restrictivos (pueden tener info sensible)
    chmod 600 "$out"

    echo "OK snapshot $project: $out ($(wc -c < "$out") bytes)"
}

cmd_resume() {
    local project="${1:-}"
    [[ -z "$project" ]] && project=$(detect_project)
    local proj_dir="$SNAPSHOTS_DIR/$project"

    if [[ ! -d "$proj_dir" ]]; then
        echo "Sin snapshots para proyecto '$project'."
        echo "Iniciar nuevo chat o cambiar de proyecto."
        return 0
    fi

    local latest
    latest=$(ls -t "$proj_dir"/*.yaml 2>/dev/null | head -1)
    if [[ -z "$latest" ]]; then
        echo "Sin snapshots para proyecto '$project'."
        return 0
    fi

    # Edad del snapshot
    local mtime now age_h
    mtime=$(stat -c %Y "$latest")
    now=$(date +%s)
    age_h=$(( (now - mtime) / 3600 ))

    local stale_flag=""
    if (( age_h > 24 )); then
        stale_flag=" [STALE: ${age_h}h, posiblemente desactualizado]"
    fi

    echo "═══ Snapshot más reciente — $project$stale_flag ═══"
    echo "Archivo: $(basename "$latest")"
    echo "Hace: ${age_h}h"
    echo
    # Solo imprimir summary, current_task, pending — el ejecutivo
    "${HELIX_PYTHON:-python3}" <<PYEOF
import re
with open("$latest") as f:
    content = f.read()

def get_field(name):
    m = re.search(rf"^{name}:\s*(.+?)$", content, re.MULTILINE)
    return m.group(1).strip() if m else "(no definido)"

def get_list(name, max_items=5):
    pattern = rf"^{name}:\s*\n((?:  - .+\n)*)"
    m = re.search(pattern, content, re.MULTILINE)
    if not m: return []
    items = re.findall(r"  - (.+)", m.group(1))
    return items[:max_items]

print(f"Resumen: {get_field('summary')}")
print(f"Tarea actual: {get_field('current_task')}")
print(f"Estado: {get_field('status')}")

pending = get_list('pending')
if pending:
    print(f"\\nPendiente:")
    for p in pending:
        print(f"  • {p}")

questions = get_list('open_questions')
if questions:
    print(f"\\nPreguntas abiertas:")
    for q in questions:
        print(f"  • {q}")
PYEOF
    echo
    echo "Para detalle completo: bash $0 show $latest"
}

cmd_list() {
    local project="${1:-}"
    if [[ -n "$project" ]]; then
        local proj_dir="$SNAPSHOTS_DIR/$project"
        [[ ! -d "$proj_dir" ]] && { echo "Sin snapshots para '$project'."; exit 0; }
        echo "═══ Snapshots: $project ═══"
        ls -lht "$proj_dir"/*.yaml 2>/dev/null | awk '{print $9, "("$5" bytes,", $6, $7, $8")"}'
    else
        echo "═══ Snapshots por proyecto ═══"
        for pd in "$SNAPSHOTS_DIR"/*/; do
            [[ -d "$pd" ]] || continue
            local proj count latest
            proj=$(basename "$pd")
            count=$(ls "$pd"/*.yaml 2>/dev/null | wc -l)
            latest=$(ls -t "$pd"/*.yaml 2>/dev/null | head -1)
            if [[ -n "$latest" ]]; then
                local age_h
                age_h=$(( ($(date +%s) - $(stat -c %Y "$latest")) / 3600 ))
                echo "  $proj: $count snapshots, último hace ${age_h}h"
            fi
        done
    fi
}

cmd_show() {
    local file="${1:?file requerido}"
    [[ ! -f "$file" ]] && { echo "No existe: $file"; exit 1; }
    cat "$file"
}

cmd_archive() {
    # Mueve snapshots >7d a archive/ por proyecto
    local moved=0
    local cutoff=$(( $(date +%s) - 7*86400 ))
    for proj_dir in "$SNAPSHOTS_DIR"/*/; do
        [[ -d "$proj_dir" ]] || continue
        local archive_dir="$proj_dir/archive"
        for f in "$proj_dir"/*.yaml; do
            [[ -f "$f" ]] || continue
            local mtime
            mtime=$(stat -c %Y "$f")
            if (( mtime < cutoff )); then
                mkdir -p "$archive_dir"
                mv "$f" "$archive_dir/"
                ((moved++))
            fi
        done
    done
    echo "Archivados: $moved snapshots"
}

cmd_prune() {
    # Elimina archives >30d
    local removed=0
    local cutoff=$(( $(date +%s) - 30*86400 ))
    for archive_dir in "$SNAPSHOTS_DIR"/*/archive/; do
        [[ -d "$archive_dir" ]] || continue
        for f in "$archive_dir"/*.yaml; do
            [[ -f "$f" ]] || continue
            local mtime
            mtime=$(stat -c %Y "$f")
            if (( mtime < cutoff )); then
                rm "$f"
                ((removed++))
            fi
        done
    done
    echo "Removidos: $removed archives"
}

cmd_stale_check() {
    local file="${1:?file requerido}"
    [[ ! -f "$file" ]] && { echo "No existe: $file"; exit 1; }

    local mtime age_h
    mtime=$(stat -c %Y "$file")
    age_h=$(( ($(date +%s) - mtime) / 3600 ))

    local stale=false
    local reasons=()

    if (( age_h > 24 )); then
        stale=true
        reasons+=("edad ${age_h}h > 24h")
    fi

    # Detectar git commits posteriores en el proyecto
    local proj
    proj=$(grep "^project:" "$file" | awk '{print $2}')
    local proj_path="$HOME/$proj"
    [[ "$proj" == "global" ]] && proj_path=""

    if [[ -n "$proj_path" && -d "$proj_path/.git" ]]; then
        local commits_since
        commits_since=$(cd "$proj_path" && git log --since="@$mtime" --oneline 2>/dev/null | wc -l)
        if (( commits_since > 0 )); then
            stale=true
            reasons+=("$commits_since commits posteriores en $proj")
        fi
    fi

    if [[ "$stale" == "true" ]]; then
        echo "STALE: ${reasons[*]}"
        exit 1
    else
        echo "FRESH"
        exit 0
    fi
}

CMD="${1:-help}"
shift || true

case "$CMD" in
    capture)     cmd_capture ;;
    resume)      cmd_resume "${1:-}" ;;
    list)        cmd_list "${1:-}" ;;
    show)        cmd_show "${1:-}" ;;
    archive)     cmd_archive ;;
    prune)       cmd_prune ;;
    stale-check) cmd_stale_check "${1:-}" ;;
    help|*)
        cat <<EOF
helix-snapshot.sh — Persistencia conversacional opt-in

Uso: bash $0 <comando> [args]

Comandos:
  capture           Lee YAML por stdin, persiste snapshot
                    (Claude llena: summary, current_task, status, completed, pending,
                     critical_decisions, open_questions, files_modified)
  resume [project]  Imprime resumen ejecutivo del snapshot más reciente
  list [project]    Lista snapshots con metadata
  show <file>       Imprime snapshot completo
  archive           Mueve snapshots >7d a archive/ (idempotente)
  prune             Elimina archives >30d (idempotente)
  stale-check <f>   Verifica si snapshot está stale (>24h o git posterior)

Storage: ~/.claude/snapshots/<project>/<ts>.yaml (chmod 600)
Archive: ~/.claude/snapshots/<project>/archive/<ts>.yaml
Diseño:  ~/.claude/memory/topics/conversation-context-research.md
EOF
        ;;
esac

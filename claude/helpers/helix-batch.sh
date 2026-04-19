#!/usr/bin/env bash
# helix-batch.sh — Worktree batch dispatcher (patrón /batch del ecosistema Claude Code).
# Crea git worktrees aislados para N tareas independientes, ejecuta en paralelo y consolida resultados.
#
# Uso:
#   helix-batch.sh plan <spec.md>              — lista tareas a ejecutar
#   helix-batch.sh run  <spec.md> [--parallel] — crea worktrees + invoca claude -p <task>
#   helix-batch.sh status                       — lista worktrees activos
#   helix-batch.sh cleanup [--force]           — elimina worktrees terminados
#
# Formato de spec.md:
#   # title
#   - [ ] ID:TASK-01 | branch:feat/x | prompt: "implementa endpoint /users"
#   - [ ] ID:TASK-02 | branch:fix/y  | prompt: "arregla bug auth JWT"
set -uo pipefail

REPO="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "")"
if [[ -z "$REPO" ]]; then
    echo "❌ No estás en un repo git" >&2; exit 1
fi

WORKTREE_ROOT="${WORKTREE_ROOT:-$REPO/.helix-worktrees}"
mkdir -p "$WORKTREE_ROOT"

cmd="${1:-help}"
shift || true

GREEN="\033[0;32m"; BLUE="\033[0;34m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"

# ── Parser de spec ──────────────────────────────────────────
_parse_spec() {
    local spec="$1"
    [[ ! -f "$spec" ]] && { echo "Spec no encontrado: $spec" >&2; return 1; }

    # Salida: ID|branch|prompt (una línea por tarea)
    python3 - "$spec" <<'PYEOF'
import sys, re
spec = open(sys.argv[1]).read()
pattern = re.compile(r"^\s*-\s*\[\s*\]\s*ID:(\S+)\s*\|\s*branch:(\S+)\s*\|\s*prompt:\s*['\"](.+?)['\"]\s*$", re.M)
for m in pattern.finditer(spec):
    print(f"{m.group(1)}|{m.group(2)}|{m.group(3)}")
PYEOF
}

case "$cmd" in

plan)
    SPEC="${1:-}"
    [[ -z "$SPEC" ]] && { echo "Uso: helix-batch.sh plan <spec.md>" >&2; exit 1; }
    tasks=$(_parse_spec "$SPEC") || exit 1
    [[ -z "$tasks" ]] && { echo "Sin tareas parseables en $SPEC"; exit 0; }

    echo -e "${BLUE}⬡ Helix Batch — plan desde $SPEC${NC}"
    n=0
    while IFS='|' read -r id branch prompt; do
        n=$((n + 1))
        echo "  [$n] $id  branch=$branch"
        echo "        → ${prompt:0:80}"
    done <<< "$tasks"
    echo
    echo "  Total: $n tareas. Para ejecutar: helix-batch.sh run $SPEC"
    ;;

run)
    SPEC="${1:-}"
    [[ -z "$SPEC" ]] && { echo "Uso: helix-batch.sh run <spec.md> [--parallel]" >&2; exit 1; }
    PARALLEL=0
    [[ "${2:-}" == "--parallel" ]] && PARALLEL=1

    tasks=$(_parse_spec "$SPEC") || exit 1
    [[ -z "$tasks" ]] && { echo "Sin tareas"; exit 0; }

    # Verificar claude CLI
    if ! command -v claude &>/dev/null; then
        echo -e "${YELLOW}⚠️  claude CLI no encontrado. El batch solo creará worktrees.${NC}"
    fi

    LOG_DIR="$WORKTREE_ROOT/.logs"
    mkdir -p "$LOG_DIR"

    pids=()
    while IFS='|' read -r id branch prompt; do
        WT="$WORKTREE_ROOT/$id"
        if [[ -d "$WT" ]]; then
            echo -e "${YELLOW}  ~ $id: worktree ya existe${NC}"
        else
            echo -e "${BLUE}  + $id: creando worktree en $branch${NC}"
            # Crear desde current branch si branch no existe
            if git -C "$REPO" rev-parse --verify "$branch" &>/dev/null; then
                git -C "$REPO" worktree add "$WT" "$branch" 2>&1 | sed 's/^/    /'
            else
                git -C "$REPO" worktree add -b "$branch" "$WT" 2>&1 | sed 's/^/    /'
            fi
        fi

        # Ejecutar claude -p si CLI disponible
        if command -v claude &>/dev/null; then
            LOG="$LOG_DIR/$id.log"
            if [[ $PARALLEL -eq 1 ]]; then
                (cd "$WT" && claude -p "$prompt" > "$LOG" 2>&1 && \
                    echo -e "${GREEN}  ✓ $id completado${NC}" || \
                    echo -e "${RED}  ✗ $id falló — ver $LOG${NC}") &
                pids+=($!)
            else
                echo -e "${BLUE}  ▶ $id: ejecutando claude -p (ver $LOG)${NC}"
                (cd "$WT" && claude -p "$prompt" > "$LOG" 2>&1) && \
                    echo -e "${GREEN}  ✓ $id completado${NC}" || \
                    echo -e "${RED}  ✗ $id falló${NC}"
            fi
        fi
    done <<< "$tasks"

    # Esperar paralelos
    if [[ $PARALLEL -eq 1 && ${#pids[@]} -gt 0 ]]; then
        echo -e "${BLUE}  ... esperando ${#pids[@]} tareas en paralelo${NC}"
        wait "${pids[@]}"
    fi

    echo
    echo -e "${GREEN}✅ Batch terminado. Worktrees en $WORKTREE_ROOT/${NC}"
    echo "   Siguiente: revisar, mergear con git worktree add + git merge, o:"
    echo "   helix-batch.sh cleanup  (al terminar)"
    ;;

status)
    git -C "$REPO" worktree list | awk -v root="$WORKTREE_ROOT" '
        $1 ~ root { print "  " $0 }
        END { if (NR == 0) print "  (sin worktrees activos)" }
    '
    ;;

cleanup)
    FORCE=""
    [[ "${1:-}" == "--force" ]] && FORCE="--force"

    # Listar worktrees bajo WORKTREE_ROOT
    WTS=$(git -C "$REPO" worktree list --porcelain | awk -v root="$WORKTREE_ROOT" '
        /^worktree/ { wt=$2; if (index(wt, root) == 1) print wt }
    ')
    if [[ -z "$WTS" ]]; then
        echo "Sin worktrees para limpiar."
        exit 0
    fi

    echo "Worktrees a eliminar:"
    echo "$WTS" | sed 's/^/  /'
    if [[ -z "$FORCE" ]]; then
        read -rp "¿Confirmar? [y/N]: " ans
        [[ "$ans" != "y" && "$ans" != "Y" ]] && { echo "Cancelado."; exit 0; }
    fi
    while IFS= read -r wt; do
        git -C "$REPO" worktree remove "$wt" $FORCE 2>&1 | sed 's/^/  /'
    done <<< "$WTS"
    echo -e "${GREEN}✅ Cleanup completo${NC}"
    ;;

*)
    echo -e "${BLUE}helix-batch.sh — Worktree batch dispatcher${NC}"
    echo ""
    echo "Comandos:"
    echo "  plan    <spec.md>              Listar tareas parseables"
    echo "  run     <spec.md> [--parallel] Crear worktrees + ejecutar claude -p"
    echo "  status                          Worktrees activos"
    echo "  cleanup [--force]              Eliminar worktrees"
    echo ""
    echo "Formato spec.md:"
    echo "  - [ ] ID:TASK-01 | branch:feat/x | prompt: \"implementa endpoint /users\""
    ;;
esac

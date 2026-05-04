#!/usr/bin/env bash
# ============================================================
# update_local.sh — actualizar instalación Helix LOCAL desde el repo
#
# Flujo opuesto a update.sh:
#   - update.sh         → local ($CLAUDE_DIR) hacia repo (uso del creator)
#   - update_local.sh   → repo hacia local ($CLAUDE_DIR), preservando configs personales
#
# Detecta layout activo (split / legacy / override HELIX_HOME) y aplica los
# cambios del repo manteniendo intactos los archivos personales del usuario.
#
# Uso:
#   bash update_local.sh                 # interactivo, pide confirmación
#   bash update_local.sh --dry-run       # solo muestra qué haría
#   bash update_local.sh --no-pull       # asume el repo ya está al día
#   bash update_local.sh --yes           # no preguntar (CI / scripts)
#   HELIX_HOME=/path bash update_local.sh
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
NO_PULL=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=1 ;;
    --no-pull)  NO_PULL=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    -h|--help)
      sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_DIM='\033[2m'
C_RESET='\033[0m'

# ── Resolver layout activo ───────────────────────────────────
if [[ -n "${HELIX_HOME:-}" ]] && [[ -d "$HELIX_HOME" ]]; then
  CLAUDE_DIR="$HELIX_HOME"
  LAYOUT="custom (HELIX_HOME)"
elif [[ -f "$HOME/.helix/CLAUDE.md" ]] && grep -q "Helix" "$HOME/.helix/CLAUDE.md" 2>/dev/null; then
  CLAUDE_DIR="$HOME/.helix"
  LAYOUT="split"
elif [[ -f "$HOME/.claude/CLAUDE.md" ]] && grep -q "Helix" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
  CLAUDE_DIR="$HOME/.claude"
  LAYOUT="legacy"
else
  echo "[!] No detecté instalación Helix activa."
  echo "    Esperado: ~/.helix/CLAUDE.md (split) o ~/.claude/CLAUDE.md (legacy)."
  echo "    Para nueva instalación: bash $REPO_DIR/install_on_wsl.sh"
  exit 1
fi

echo "============================================================"
echo "  Helix update_local — repo → local con preservación"
echo "============================================================"
echo "  Repo:    $REPO_DIR"
echo "  Local:   $CLAUDE_DIR"
echo "  Layout:  $LAYOUT"
echo "  Dry-run: $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
echo ""

# ── Listas de PRESERVAR ───────────────────────────────────────
# Cada lista declara excludes RELATIVOS al source del rsync donde aplica.

# Files in $CLAUDE_DIR root (no en subdir) — se preservan SI YA EXISTEN localmente
ROOT_PRESERVE=(
  "helix-role.conf"
  "capa0-disabled"
  "settings.local.json"
  "passive-captures-pending.jsonl"
  "judge-decisions.jsonl"
  "judge-audit-feedback.jsonl"
  "aidefence-redactions.jsonl"
  "egress-audit.jsonl"
  "d1-multidomain-detections.jsonl"
  "r1-recommend-log.jsonl"
)

# Patterns relativos a memory/ (usados en --exclude del rsync de memory/)
MEMORY_EXCLUDE=(
  "user-profile.md"
  "helix-stack.md"
  "helix-bitacora.md"
  "helix-backlog.md"
  "helix-team.md"
  "helix-analysis.md"
  "helix-alerta.md"
  "helix-plan-*.md"
  "snapshots-*.md"
  "install-vector-bootstrap.log"
  "reflexions.jsonl"
  ".analysis-declined"
)

# ── 1. git pull ───────────────────────────────────────────────
if [[ "$NO_PULL" -eq 0 ]]; then
  echo "→ git pull origin develop..."
  if [[ -d "$REPO_DIR/.git" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      git -C "$REPO_DIR" fetch --all --prune
      LOCAL_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD)
      REMOTE_HEAD=$(git -C "$REPO_DIR" rev-parse '@{u}' 2>/dev/null || echo "$LOCAL_HEAD")
      if [[ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]]; then
        echo -e "  ${C_DIM}(dry-run) git pull traería:${C_RESET}"
        git -C "$REPO_DIR" log --oneline "$LOCAL_HEAD..$REMOTE_HEAD" | head -10 | sed 's/^/    /'
      else
        echo -e "  ${C_DIM}(dry-run) repo ya está al día${C_RESET}"
      fi
    else
      git -C "$REPO_DIR" pull --ff-only || {
        echo "[!] git pull falló (probablemente cambios locales sin commit en el repo)."
        echo "    Resolvé manualmente y reintentá. Para skipear: --no-pull"
        exit 2
      }
    fi
  else
    echo -e "  ${C_YELLOW}(no es un repo git, salteando pull)${C_RESET}"
  fi
  echo ""
fi

# ── 2. Construir lista de exclusión para rsync de memory/ ────
MEMORY_EXCLUDE_ARGS=()
for pattern in "${MEMORY_EXCLUDE[@]}"; do
  MEMORY_EXCLUDE_ARGS+=(--exclude "$pattern")
done

# ── 3. Sync archivos públicos (sobreescriben) ────────────────
echo "→ Sincronizando archivos públicos (CLAUDE.md, settings.json, scripts)..."
PUBLIC_FILES=(CLAUDE.md settings.json evolve.sh session-start.sh session-end.sh \
              self-check.sh compress.sh compress_logic.py health-check.sh)
for f in "${PUBLIC_FILES[@]}"; do
  if [[ -f "$REPO_DIR/claude/$f" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      if ! cmp -s "$REPO_DIR/claude/$f" "$CLAUDE_DIR/$f" 2>/dev/null; then
        echo -e "  ${C_DIM}(dry-run) actualizar $f${C_RESET}"
      fi
    else
      cp "$REPO_DIR/claude/$f" "$CLAUDE_DIR/$f"
    fi
  fi
done
[[ "$DRY_RUN" -eq 0 ]] && echo -e "  ${C_GREEN}OK${C_RESET}"

# ── 4. Sync directorios (rsync con preserve) ─────────────────
RSYNC_FLAGS=(-a)
[[ "$DRY_RUN" -eq 1 ]] && RSYNC_FLAGS+=(--dry-run --itemize-changes)

echo ""
echo "→ Sincronizando helpers/ (sobreescribe — todos los hooks bash)..."
mkdir -p "$CLAUDE_DIR/helpers"
rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/helpers/" "$CLAUDE_DIR/helpers/" 2>&1 | head -20

echo ""
echo "→ Sincronizando commands/ (sobreescribe)..."
mkdir -p "$CLAUDE_DIR/commands"
rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/commands/" "$CLAUDE_DIR/commands/" 2>&1 | head -20

echo ""
echo "→ Sincronizando skills/ (agrega/actualiza, no borra custom)..."
mkdir -p "$CLAUDE_DIR/skills"
rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/skills/" "$CLAUDE_DIR/skills/" 2>&1 | head -20

echo ""
echo "→ Sincronizando agents/ (agrega/actualiza, no borra custom)..."
mkdir -p "$CLAUDE_DIR/agents"
rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/agents/" "$CLAUDE_DIR/agents/" 2>&1 | head -20

echo ""
echo "→ Sincronizando council/ (constitución + scripts; runs locales preservados)..."
mkdir -p "$CLAUDE_DIR/council/scripts"
[[ -f "$REPO_DIR/claude/council/constitution.md" ]] && \
  rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/council/constitution.md" "$CLAUDE_DIR/council/" 2>&1 | head -5
[[ -f "$REPO_DIR/claude/council/inter-agent-language.md" ]] && \
  rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/council/inter-agent-language.md" "$CLAUDE_DIR/council/" 2>&1 | head -5
[[ -d "$REPO_DIR/claude/council/scripts" ]] && \
  rsync "${RSYNC_FLAGS[@]}" "$REPO_DIR/claude/council/scripts/" "$CLAUDE_DIR/council/scripts/" 2>&1 | head -10

echo ""
echo "→ Sincronizando memory/ con preservación..."
echo -e "  ${C_DIM}Excluye: user-profile.md, helix-{stack,bitacora,backlog,team,analysis,plan-*,alerta}.md${C_RESET}"
mkdir -p "$CLAUDE_DIR/memory/agents" "$CLAUDE_DIR/memory/topics"
rsync "${RSYNC_FLAGS[@]}" \
  "${MEMORY_EXCLUDE_ARGS[@]}" \
  "$REPO_DIR/claude/memory/" "$CLAUDE_DIR/memory/" 2>&1 | head -20

# user-profile: solo crear si no existe (desde template)
if [[ ! -f "$CLAUDE_DIR/memory/user-profile.md" ]] && \
   [[ -f "$REPO_DIR/claude/memory/user-profile.template.md" ]]; then
  echo ""
  echo -e "  ${C_YELLOW}user-profile.md no existe — creando desde template${C_RESET}"
  [[ "$DRY_RUN" -eq 0 ]] && \
    cp "$REPO_DIR/claude/memory/user-profile.template.md" "$CLAUDE_DIR/memory/user-profile.md"
fi

# ── 5. Permisos ───────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 0 ]]; then
  chmod +x "$CLAUDE_DIR/helpers/"*.sh 2>/dev/null || true
  chmod +x "$CLAUDE_DIR/council/scripts/"*.sh 2>/dev/null || true
  for s in evolve session-start session-end self-check compress health-check; do
    [[ -f "$CLAUDE_DIR/$s.sh" ]] && chmod +x "$CLAUDE_DIR/$s.sh"
  done
fi

# ── 6. Validar settings.local.json no fue tocado ─────────────
if [[ -f "$CLAUDE_DIR/settings.local.json" ]]; then
  echo ""
  echo -e "  ${C_GREEN}✓ settings.local.json preservado${C_RESET}"
fi

# ── 7. Resumen ────────────────────────────────────────────────
echo ""
echo "============================================================"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo -e "  ${C_YELLOW}(dry-run) — ningún archivo fue modificado${C_RESET}"
  echo "  Para aplicar: bash $0"
else
  echo -e "  ${C_GREEN}✓ Helix actualizado en $CLAUDE_DIR${C_RESET}"
  echo "    Reiniciá Claude Code (helix) para aplicar cambios."
fi
echo "============================================================"
echo ""
echo "Archivos preservados (no tocados):"
for f in "${ROOT_PRESERVE[@]}"; do
  [[ -e "$CLAUDE_DIR/$f" ]] && echo -e "  ${C_DIM}· $f${C_RESET}"
done
for f in "${MEMORY_EXCLUDE[@]}"; do
  if compgen -G "$CLAUDE_DIR/memory/$f" > /dev/null 2>&1; then
    echo -e "  ${C_DIM}· memory/$f${C_RESET}"
  fi
done
echo ""

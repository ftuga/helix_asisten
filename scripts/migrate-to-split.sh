#!/usr/bin/env bash
# ============================================================
# migrate-to-split.sh — Migrar Helix de ~/.claude/ a ~/.helix/
#
# Convierte instalación legacy (Helix mezclado con Claude Code stock en
# ~/.claude/) a layout split (Helix aislado en ~/.helix/, ~/.claude/ queda
# limpio para Claude Code).
#
# Reversible: hace backup completo de ~/.claude/ antes de mover. No elimina
# nada hasta confirmación final.
#
# Uso:
#   bash migrate-to-split.sh             # interactivo, pregunta antes de mover
#   bash migrate-to-split.sh --dry-run   # solo muestra qué haría
#   bash migrate-to-split.sh --yes       # no preguntar (CI / install_on_wsl.sh)
# ============================================================
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HELIX_DIR="$HOME/.helix"
BACKUP_DIR="$HOME/.claude.backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
  esac
done

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_DIM='\033[2m'
C_RESET='\033[0m'

# Componentes Helix conocidos en ~/.claude/ — los movemos a ~/.helix/
HELIX_COMPONENTS=(
  CLAUDE.md
  settings.json
  evolve.sh
  session-start.sh
  session-end.sh
  self-check.sh
  compress.sh
  compress_logic.py
  health-check.sh
  agents
  commands
  helpers
  memory
  skills
  council
  capa0-disabled
  helix-role.conf
  hv.sh
  helix-vector.py
  helix-agent-evolve.py
  helix-project-index.sh
  cache
)

# Componentes nativos de Claude Code que NO debemos mover
CLAUDE_NATIVE=(
  projects
  sessions
  backups
  ide
  todos
  history.jsonl
  shell-snapshots
  settings.local.json
  statsig
)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Helix migrate-to-split"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Validar precondiciones
if [[ ! -d "$CLAUDE_DIR" ]]; then
  echo -e "${C_RED}[!] No existe $CLAUDE_DIR. Nada que migrar.${C_RESET}"
  exit 1
fi

if [[ ! -f "$CLAUDE_DIR/CLAUDE.md" ]] || ! grep -q "Helix" "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null; then
  echo -e "${C_YELLOW}[!] $CLAUDE_DIR no parece tener Helix instalado.${C_RESET}"
  echo "    (No encontré 'Helix' en CLAUDE.md). Aborto."
  exit 1
fi

if [[ -d "$HELIX_DIR" ]]; then
  echo -e "${C_RED}[!] $HELIX_DIR ya existe. Aborto para no pisar.${C_RESET}"
  echo "    Eliminalo o renombralo manualmente si querés re-migrar."
  exit 1
fi

# Plan de migración
echo "Plan:"
echo "  1. Backup completo: $CLAUDE_DIR -> $BACKUP_DIR"
echo "  2. Crear $HELIX_DIR"
echo "  3. Mover componentes Helix de $CLAUDE_DIR a $HELIX_DIR"
echo "  4. Dejar componentes nativos de Claude Code en $CLAUDE_DIR"
echo ""

echo "Componentes Helix que se moverán:"
for c in "${HELIX_COMPONENTS[@]}"; do
  if [[ -e "$CLAUDE_DIR/$c" ]]; then
    SIZE=$(du -sh "$CLAUDE_DIR/$c" 2>/dev/null | cut -f1)
    echo -e "  ${C_GREEN}+ $c${C_RESET} ${C_DIM}($SIZE)${C_RESET}"
  fi
done
echo ""

echo "Componentes Claude Code que QUEDAN en $CLAUDE_DIR:"
for c in "${CLAUDE_NATIVE[@]}"; do
  if [[ -e "$CLAUDE_DIR/$c" ]]; then
    SIZE=$(du -sh "$CLAUDE_DIR/$c" 2>/dev/null | cut -f1)
    echo -e "  ${C_DIM}· $c ($SIZE)${C_RESET}"
  fi
done
echo ""

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(dry-run, no se ejecutó nada)"
  exit 0
fi

if [[ "$ASSUME_YES" -eq 0 ]]; then
  read -r -p "Proceder con la migración? [y/N] " _ans
  [[ "${_ans,,}" != "y" ]] && { echo "Aborted."; exit 0; }
fi
echo ""

# 1. Backup
echo "→ Backup: $CLAUDE_DIR -> $BACKUP_DIR"
cp -a "$CLAUDE_DIR" "$BACKUP_DIR"
echo -e "  ${C_GREEN}✓ backup completo${C_RESET}"

# 2. Crear ~/.helix/
mkdir -p "$HELIX_DIR"

# 3. Mover componentes Helix
echo ""
echo "→ Moviendo componentes Helix..."
for c in "${HELIX_COMPONENTS[@]}"; do
  if [[ -e "$CLAUDE_DIR/$c" ]]; then
    mv "$CLAUDE_DIR/$c" "$HELIX_DIR/"
    echo -e "  ${C_GREEN}✓ $c${C_RESET}"
  fi
done

# Post-migration fixup: settings.json y helpers/*.sh pueden tener paths
# $HOME/.claude/ hardcoded (instalaciones previas a v3.16). Convertir a
# ${CLAUDE_CONFIG_DIR:-$HOME/.claude} para que apunten a ~/.helix/ en runtime.
echo ""
echo "→ Fixup paths $HOME/.claude → \${CLAUDE_CONFIG_DIR:-\$HOME/.claude}..."

_hxc_fixup_file() {
  local f="$1"
  [[ -f "$f" ]] || return
  grep -q 'HOME/\.claude\|HOME}/\.claude' "$f" 2>/dev/null || return
  sed -i \
    -e 's|\${HOME}/\.claude|__HXC_DIR__|g' \
    -e 's|\$HOME/\.claude|__HXC_DIR__|g' \
    -e 's|__HXC_DIR__|${CLAUDE_CONFIG_DIR:-$HOME/.claude}|g' \
    "$f"
}

# settings.json (con validación JSON)
if [[ -f "$HELIX_DIR/settings.json" ]] && grep -q 'HOME/\.claude\|HOME}/\.claude' "$HELIX_DIR/settings.json" 2>/dev/null; then
  cp "$HELIX_DIR/settings.json" "$HELIX_DIR/settings.json.bak-pre-split"
  _hxc_fixup_file "$HELIX_DIR/settings.json"
  if python3 -c "import json; json.load(open('$HELIX_DIR/settings.json'))" 2>/dev/null; then
    echo -e "  ${C_GREEN}✓ settings.json actualizado (backup en settings.json.bak-pre-split)${C_RESET}"
  else
    echo -e "  ${C_RED}[!] settings.json quedó inválido. Restaurando backup...${C_RESET}"
    mv "$HELIX_DIR/settings.json.bak-pre-split" "$HELIX_DIR/settings.json"
    exit 3
  fi
fi

# Scripts shell + python (no requieren validación, sintaxis igual)
SCRIPT_FIXED=0
while IFS= read -r f; do
  _hxc_fixup_file "$f"
  ((SCRIPT_FIXED++))
done < <(find "$HELIX_DIR" -type f \( -name "*.sh" -o -name "*.py" \) 2>/dev/null \
         | xargs grep -l 'HOME/\.claude\|HOME}/\.claude' 2>/dev/null)

if [[ $SCRIPT_FIXED -gt 0 ]]; then
  echo -e "  ${C_GREEN}✓ $SCRIPT_FIXED helpers/scripts actualizados${C_RESET}"
else
  echo -e "  ${C_DIM}(scripts ya usan CLAUDE_CONFIG_DIR — skip)${C_RESET}"
fi

# Verificación post-migración
echo ""
echo "→ Verificación..."
if [[ -f "$HELIX_DIR/CLAUDE.md" ]] && [[ -f "$HELIX_DIR/settings.json" ]]; then
  echo -e "  ${C_GREEN}✓ Helix migrado correctamente a $HELIX_DIR${C_RESET}"
else
  echo -e "  ${C_RED}[!] CLAUDE.md o settings.json no aparecen en $HELIX_DIR${C_RESET}"
  echo "      Restaurar desde backup: rm -rf $CLAUDE_DIR $HELIX_DIR && mv $BACKUP_DIR $CLAUDE_DIR"
  exit 2
fi

# Recordar al usuario que hay que actualizar el alias / wrapper
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${C_GREEN}✅ Migración completa.${C_RESET}"
echo ""
echo "  Backup completo en: $BACKUP_DIR"
echo "  Para eliminar el backup cuando confirmes que todo funciona:"
echo "    rm -rf $BACKUP_DIR"
echo ""
echo "  Próximos pasos:"
echo "    1. Cerrar Claude Code si está abierto"
echo "    2. Abrir nueva terminal y correr: helix"
echo "       (el alias ya existe; ahora apunta al layout split)"
echo "    3. 'claude' sin wrapper queda como Claude Code stock (limpio)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

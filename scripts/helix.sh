#!/usr/bin/env bash
# ============================================================
# helix.sh — Launcher de Helix sobre Claude Code
#
# Aisla el ambiente Helix de Claude Code stock seteando
# CLAUDE_CONFIG_DIR=$HOME/.helix antes de invocar `claude`.
#
# Uso:
#   helix [args para claude]   # arranca Claude Code con ambiente Helix
#   helix --where              # muestra qué layout está activo
#   helix --version            # versiones de helix + claude
#
# Layouts:
#   split  — ~/.helix/ aislado, ~/.claude/ queda limpio (recomendado, v3.16+)
#   legacy — Helix mezclado en ~/.claude/ (instalaciones previas a v3.16)
#
# Si ~/.helix/ no existe pero ~/.claude/ tiene Helix instalado, este wrapper
# corre en modo legacy (sin override) y sugiere migrar.
# ============================================================
set -uo pipefail

readonly HELIX_HOME="${HELIX_HOME:-$HOME/.helix}"
readonly CLAUDE_LEGACY="$HOME/.claude"

C_DIM='\033[2m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_PURPLE='\033[1;35m'
C_RESET='\033[0m'

_helix_banner() {
  [[ "${HELIX_NO_BANNER:-0}" == "1" ]] && return
  [[ "${NO_COLOR:-}" == "1" ]] && { _helix_banner_plain; return; }
  printf '\n'
  printf '%b' "${C_CYAN}"
  cat <<'BANNER'
  ██╗  ██╗███████╗██╗     ██╗██╗  ██╗
  ██║  ██║██╔════╝██║     ██║╚██╗██╔╝
  ███████║█████╗  ██║     ██║ ╚███╔╝
  ██╔══██║██╔══╝  ██║     ██║ ██╔██╗
  ██║  ██║███████╗███████╗██║██╔╝ ██╗
  ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═╝
BANNER
  printf '%b' "${C_PURPLE}"
  printf '       Self-Evolving Agent for Claude Code\n'
  printf '%b\n' "${C_RESET}"
}

_helix_banner_plain() {
  cat <<'BANNER'

  H E L I X
  Self-Evolving Agent for Claude Code

BANNER
}

_helix_where() {
  echo "HELIX_HOME    = $HELIX_HOME"
  echo "CLAUDE_LEGACY = $CLAUDE_LEGACY"
  if [[ -d "$HELIX_HOME" ]]; then
    echo "Layout        = split (Helix aislado, claude limpio)"
    echo "CLAUDE_CONFIG_DIR <- $HELIX_HOME"
  elif [[ -f "$CLAUDE_LEGACY/CLAUDE.md" ]] && grep -q "Helix" "$CLAUDE_LEGACY/CLAUDE.md" 2>/dev/null; then
    echo "Layout        = legacy (Helix mezclado con claude en ~/.claude/)"
    echo "CLAUDE_CONFIG_DIR <- (no override)"
  else
    echo "Layout        = sin Helix instalado"
  fi
}

case "${1:-}" in
  --where)
    _helix_where
    exit 0
    ;;
  --version)
    echo -n "helix wrapper "
    grep -m1 'v3\.' "$(dirname "$0")/../README.md" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "(unknown)"
    command -v claude &>/dev/null && claude --version
    exit 0
    ;;
esac

if ! command -v claude &>/dev/null; then
  echo -e "${C_YELLOW}[!] 'claude' no esta en el PATH. Instalar Claude Code primero:${C_RESET}"
  echo "    https://docs.claude.com/en/docs/claude-code"
  exit 1
fi

if [[ -d "$HELIX_HOME" ]]; then
  export CLAUDE_CONFIG_DIR="$HELIX_HOME"
  _helix_banner
  echo -e "${C_DIM}[helix] CLAUDE_CONFIG_DIR=$HELIX_HOME${C_RESET}"
elif [[ -f "$CLAUDE_LEGACY/CLAUDE.md" ]] && grep -q "Helix" "$CLAUDE_LEGACY/CLAUDE.md" 2>/dev/null; then
  _helix_banner
  echo -e "${C_DIM}[helix] layout legacy — Helix dentro de ~/.claude/. 'claude' y 'helix' son equivalentes.${C_RESET}"
  echo -e "${C_DIM}        Migrar a layout split: bash ~/helix_asisten/scripts/migrate-to-split.sh${C_RESET}"
else
  echo -e "${C_YELLOW}[!] Helix no esta instalado.${C_RESET}"
  echo "    Layout split (recomendado): cd ~/helix_asisten && bash install_on_wsl.sh"
  echo "    'claude' seguira funcionando como Claude Code stock."
  exit 1
fi

exec claude "$@"

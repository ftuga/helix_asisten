#!/usr/bin/env bash
# copy-clean.sh — Limpia ANSI y copia al portapapeles
# Uso: echo "texto" | ~/scripts/copy-clean.sh
#      cat archivo | ~/scripts/copy-clean.sh

CLEAN=$(cat | sed 's/\x1b\[[0-9;]*[mGKHF]//g' | tr -d '\r')

if command -v pbcopy &>/dev/null; then
  echo "$CLEAN" | pbcopy
  echo "✓ Copiado con pbcopy"
elif command -v xclip &>/dev/null; then
  echo "$CLEAN" | xclip -selection clipboard
  echo "✓ Copiado con xclip"
elif command -v wl-copy &>/dev/null; then
  echo "$CLEAN" | wl-copy
  echo "✓ Copiado con wl-copy"
else
  echo "✗ No se encontró pbcopy / xclip / wl-copy" >&2
  echo "  En Ubuntu/Debian: sudo apt install xclip" >&2
  echo "  En Wayland:       sudo apt install wl-clipboard" >&2
  exit 1
fi

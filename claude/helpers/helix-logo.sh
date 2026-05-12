#!/usr/bin/env bash
# helix-logo.sh — activa/desactiva el logo (ajolote) como backgroundImage de Windows Terminal.
# Modos: on | off | status | toggle
# Edita profiles.defaults en settings.json de WT. Backup automático antes de cada cambio.
# Limitación: WT solo aplica el cambio a tabs/ventanas NUEVAS (no a la activa).

set -euo pipefail

# Resolver WT_DIR:
#   1) HELIX_WT_DIR override (manual)
#   2) Auto-detect: primer settings.json bajo /mnt/c/Users/*/AppData/.../WindowsTerminal_*/LocalState
if [[ -n "${HELIX_WT_DIR:-}" ]]; then
  WT_DIR="$HELIX_WT_DIR"
else
  # find puede recibir SIGPIPE con head; aislamos para no romper -e/pipefail.
  WT_DIR="$(set +o pipefail; find /mnt/c/Users -maxdepth 7 -type f \
    -path '*/AppData/Local/Packages/Microsoft.WindowsTerminal_*/LocalState/settings.json' \
    2>/dev/null | head -n1 | xargs -r dirname || true)"
fi
WT_SETTINGS="$WT_DIR/settings.json"
LOGO_PNG_WT='%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\ajolote-final-v3.png'
LOGO_PNG_LINUX="$WT_DIR/ajolote-final-v3.png"
OPACITY="0.35"
ALIGNMENT="topRight"
STRETCH="uniform"

usage() {
  cat <<EOF
Uso: helix-logo.sh <on|off|status|toggle>

  on       Activa el logo (ajolote) como fondo de Windows Terminal.
  off      Desactiva el logo. Conserva el resto de profiles.defaults.
  status   Reporta si el logo está activo o no.
  toggle   Invierte el estado actual.

Notas:
  - WT aplica el cambio solo a tabs/ventanas NUEVAS.
  - Backup automático en: $WT_DIR/settings.json.bak.helix-logo.<ts>
EOF
}

mode="${1:-}"
[[ -z "$mode" ]] && { usage; exit 2; }

if [[ -z "$WT_DIR" || ! -f "$WT_SETTINGS" ]]; then
  echo "ERROR: no encontré settings.json de Windows Terminal." >&2
  echo "       Probado: $WT_SETTINGS" >&2
  echo "       Tip: exportar HELIX_WT_DIR=/mnt/c/Users/<TU_USER>/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState" >&2
  exit 1
fi
# Auto-bootstrap del PNG: si no está en LocalState, copiarlo desde el asset
# replicado por update_local_on_{wsl,windows} a $CLAUDE_DIR/assets/.
if [[ ! -f "$LOGO_PNG_LINUX" ]]; then
  CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-${HELIX_HOME:-$HOME/.helix}}"
  [[ -d "$CLAUDE_DIR" ]] || CLAUDE_DIR="$HOME/.claude"
  ASSET_SRC="$CLAUDE_DIR/assets/ajolote-final-v3.png"
  if [[ -f "$ASSET_SRC" ]]; then
    cp "$ASSET_SRC" "$LOGO_PNG_LINUX"
    echo "logo: PNG copiado desde $ASSET_SRC -> $LOGO_PNG_LINUX"
  else
    echo "WARN: PNG del logo ausente en: $LOGO_PNG_LINUX" >&2
    echo "      Y tampoco encontrado en: $ASSET_SRC" >&2
    echo "      Corré 'bash update_local_on_wsl.sh' (o el equivalente Windows) en helix_asisten." >&2
  fi
fi

read_status() {
  python3 - "$WT_SETTINGS" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
defaults = d.get("profiles", {}).get("defaults", {})
bg = defaults.get("backgroundImage", "")
print("on" if "ajolote" in bg.lower() else "off")
PY
}

backup() {
  local ts; ts="$(date +%Y%m%d-%H%M%S)"
  cp "$WT_SETTINGS" "$WT_DIR/settings.json.bak.helix-logo.$ts"
  echo "$WT_DIR/settings.json.bak.helix-logo.$ts"
}

apply_on() {
  python3 - "$WT_SETTINGS" "$LOGO_PNG_WT" "$OPACITY" "$ALIGNMENT" "$STRETCH" <<'PY'
import json, sys
path, png, op, align, stretch = sys.argv[1:6]
with open(path) as f:
    d = json.load(f)
d.setdefault("profiles", {}).setdefault("defaults", {})
df = d["profiles"]["defaults"]
df["backgroundImage"] = png
df["backgroundImageOpacity"] = float(op)
df["backgroundImageAlignment"] = align
df["backgroundImageStretchMode"] = stretch
with open(path, "w") as f:
    json.dump(d, f, indent=4)
PY
}

apply_off() {
  python3 - "$WT_SETTINGS" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
df = d.get("profiles", {}).get("defaults", {})
for k in ("backgroundImage", "backgroundImageOpacity",
          "backgroundImageAlignment", "backgroundImageStretchMode"):
    df.pop(k, None)
with open(path, "w") as f:
    json.dump(d, f, indent=4)
PY
}

case "$mode" in
  status)
    s="$(read_status)"
    echo "logo: $s"
    ;;
  on)
    s="$(read_status)"
    if [[ "$s" == "on" ]]; then
      echo "logo: ya estaba ON (sin cambios)"
      exit 0
    fi
    bk="$(backup)"
    apply_on
    echo "logo: ON"
    echo "backup: $bk"
    echo "nota: abre una tab nueva de WT para verlo."
    ;;
  off)
    s="$(read_status)"
    if [[ "$s" == "off" ]]; then
      echo "logo: ya estaba OFF (sin cambios)"
      exit 0
    fi
    bk="$(backup)"
    apply_off
    echo "logo: OFF"
    echo "backup: $bk"
    echo "nota: abre una tab nueva de WT para verlo."
    ;;
  toggle)
    s="$(read_status)"
    if [[ "$s" == "on" ]]; then exec "$0" off; else exec "$0" on; fi
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac

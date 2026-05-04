#!/usr/bin/env bash
# helix-banner.sh — Banner ASCII con axolotl mascot
# Asset para FASE 6 installer (TRANCH 3 pospuesto). NO integrado en flujos hoy.
# Brand palette: Electric Cyan #00F5D4, Cobalt Deep Blue #002058,
#                Slate Gray #2D3436, Off-White #F9F9F9
# Modos: full | compact | axolotl
# Uso futuro: invocar al inicio de helix-installer.sh

set -uo pipefail

readonly HELIX_DIR="${HOME}/.claude"
readonly AXOLOTL_FILE="${HELIX_DIR}/helpers/banner-axolotl.txt"
readonly HELIX_VERSION="${HELIX_VERSION:-v3.13}"

# Truecolor brand palette
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'
readonly C_DIM=$'\033[2m'
readonly C_CYAN=$'\033[38;2;0;245;212m'        # #00F5D4 Electric Cyan
readonly C_COBALT=$'\033[38;2;58;130;220m'     # acento legible derivado de #002058
readonly C_SLATE=$'\033[38;2;106;115;120m'     # slate gray
readonly C_OFFWHITE=$'\033[38;2;249;249;249m'  # #F9F9F9
readonly C_BOLD_CYAN=$'\033[1;38;2;0;245;212m'

# Modo: "full" (axolotl + wordmark + tagline), "compact" (wordmark + tagline solo)
MODE="${1:-full}"

# ─────────────────────────────────────────────────────────────
# Wordmark "HELIX" estilo block-letters monospace
# ─────────────────────────────────────────────────────────────
print_wordmark() {
    cat <<'EOF'
   ██╗  ██╗ ███████╗ ██╗      ██╗ ██╗  ██╗
   ██║  ██║ ██╔════╝ ██║      ██║ ╚██╗██╔╝
   ███████║ █████╗   ██║      ██║  ╚███╔╝
   ██╔══██║ ██╔══╝   ██║      ██║  ██╔██╗
   ██║  ██║ ███████╗ ███████╗ ██║ ██╔╝ ██╗
   ╚═╝  ╚═╝ ╚══════╝ ╚══════╝ ╚═╝ ╚═╝  ╚═╝
EOF
}

# ─────────────────────────────────────────────────────────────
# Render
# ─────────────────────────────────────────────────────────────

print_blank() { printf '\n'; }

case "$MODE" in
    full)
        print_blank
        # Axolotl en Electric Cyan
        if [[ -f "$AXOLOTL_FILE" ]]; then
            printf '%s' "$C_CYAN"
            cat "$AXOLOTL_FILE"
            printf '%s' "$C_RESET"
        fi
        print_blank
        # Wordmark en Bold Cyan
        printf '%s' "$C_BOLD_CYAN"
        print_wordmark
        printf '%s' "$C_RESET"
        print_blank
        # Tagline + version
        printf '   %s≋≋≋%s  %sself-evolving agent harness%s  %s≋≋≋%s\n' \
            "$C_CYAN" "$C_RESET" \
            "$C_OFFWHITE" "$C_RESET" \
            "$C_CYAN" "$C_RESET"
        printf '   %s%s%s  %s·%s  %sopus 4.7%s  %s·%s  %s100%% local%s\n' \
            "$C_COBALT" "$HELIX_VERSION" "$C_RESET" \
            "$C_SLATE" "$C_RESET" \
            "$C_OFFWHITE" "$C_RESET" \
            "$C_SLATE" "$C_RESET" \
            "$C_OFFWHITE" "$C_RESET"
        print_blank
        ;;
    compact)
        print_blank
        printf '%s' "$C_BOLD_CYAN"
        print_wordmark
        printf '%s' "$C_RESET"
        print_blank
        printf '   %s≋ self-evolving agent harness%s  %s·%s  %s%s%s\n' \
            "$C_CYAN" "$C_RESET" \
            "$C_SLATE" "$C_RESET" \
            "$C_COBALT" "$HELIX_VERSION" "$C_RESET"
        print_blank
        ;;
    axolotl)
        # Solo axolotl, sin wordmark — para overlays
        if [[ -f "$AXOLOTL_FILE" ]]; then
            printf '%s' "$C_CYAN"
            cat "$AXOLOTL_FILE"
            printf '%s' "$C_RESET"
        fi
        ;;
    *)
        printf 'Usage: helix-banner.sh [full|compact|axolotl]\n' >&2
        exit 1
        ;;
esac

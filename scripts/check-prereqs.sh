#!/usr/bin/env bash
# ============================================================
# Helix — Verificación bloqueante de prerequisitos (v2)
# Uso: bash scripts/check-prereqs.sh
# Devuelve 0 si OK, 1 si hay fallas críticas.
#
# v2 (FASE 6 OPCIÓN E):
# - docker, ollama, zstd, claude CLI son FAIL (no WARN).
# - Output agrupado: bloque único copy-paste con solo lo que falta.
# - Solo soporta Ubuntu/Debian/WSL en v1. Otros OS: ver
#   ~/.claude/memory/topics/install-os-support.md
# ============================================================
set -uo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

# ─── Estado de checks ────────────────────────────────────────
FAILS_LABELS=()
WARNS_LABELS=()
WARNS_CMDS=()
OK_LABELS=()

# Grupos de instalación que se necesitan generar al final
declare -A GROUPS_NEEDED=()
APT_PKGS=()        # paquetes apt requeridos (deduplicados al final)
OLLAMA_MODELS=()   # modelos ollama a pull

mark_ok()    { OK_LABELS+=("$1"); }
mark_fail()  { FAILS_LABELS+=("$1"); GROUPS_NEEDED[$2]=1; }
mark_warn()  { WARNS_LABELS+=("$1"); WARNS_CMDS+=("${2:-}"); }
add_apt()    { APT_PKGS+=("$1"); GROUPS_NEEDED[apt]=1; }
add_model()  { OLLAMA_MODELS+=("$1"); GROUPS_NEEDED[ollama_models]=1; }

# ─── Detección de OS (FAIL si no soportado) ──────────────────
echo -e "${BLUE}🔍 Verificando prerequisitos (v2)...${NC}"
echo ""

OS_KERNEL="$(uname -s)"
IS_WSL=0
IS_WIN_NATIVE=0
case "$OS_KERNEL" in
    Linux)
        if ! command -v apt-get &>/dev/null; then
            echo -e "${RED}✗ Distribución Linux sin apt-get${NC}" >&2
            echo "  v1 soporta solo Debian/Ubuntu/WSL." >&2
            echo "  Otros gestores (dnf/yum/pacman): ver ~/.claude/memory/topics/install-os-support.md" >&2
            exit 1
        fi
        if grep -qi microsoft /proc/version 2>/dev/null; then
            IS_WSL=1
            mark_ok "WSL detectado"
        fi
        ;;
    MINGW*|MSYS*|CYGWIN*)
        IS_WIN_NATIVE=1
        mark_ok "Windows nativo + Git Bash ($OS_KERNEL)"
        ;;
    *)
        echo -e "${RED}✗ OS no soportado: $OS_KERNEL${NC}" >&2
        echo "  Soportados: Linux (Ubuntu/Debian/WSL) y Windows nativo (Git Bash / MSYS2 / Cygwin)." >&2
        echo "  macOS/Fedora/Arch: ver ~/.claude/memory/topics/install-os-support.md" >&2
        exit 1
        ;;
esac

# ─── 1. Sistema dpkg saludable (solo Linux) ──────────────────
if [[ "$IS_WIN_NATIVE" -eq 0 ]]; then
    if dpkg --audit 2>/dev/null | grep -q .; then
        mark_fail "dpkg en estado inconsistente" "dpkg_fix"
    fi
fi

# ─── 2. Herramientas base ────────────────────────────────────
for cmd in git curl; do
    if command -v "$cmd" &>/dev/null; then
        mark_ok "$cmd"
    else
        if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
            mark_fail "$cmd no encontrado — reinstalar Git for Windows" "git_for_windows"
        else
            mark_fail "$cmd no encontrado" "apt"
            add_apt "$cmd"
        fi
    fi
done

# rsync — en Windows Git Bash no está disponible; el instalador usa cp -a como fallback
if command -v rsync &>/dev/null; then
    mark_ok "rsync"
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_warn "rsync no encontrado — usando cp -a como fallback (no bloquea)"
    else
        mark_fail "rsync no encontrado" "apt"
        add_apt "rsync"
    fi
fi

# zstd — en Windows Ollama lo incluye internamente; no es un prereq externo
if command -v zstd &>/dev/null; then
    mark_ok "zstd"
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_warn "zstd no encontrado en PATH — Ollama lo gestiona internamente en Windows (no bloquea)"
    else
        mark_fail "zstd no encontrado (requerido por Ollama)" "apt"
        add_apt "zstd"
    fi
fi

# ─── 3. Node.js ≥ 18 ─────────────────────────────────────────
# En Linux/WSL puro: node debe ser nativo (no /mnt/c/...).
# En Git Bash: node.exe en /c/Program Files/nodejs es válido.
NODE_OK=0
if command -v node &>/dev/null; then
    NODE_PATH="$(command -v node)"
    if [[ "$IS_WIN_NATIVE" -eq 0 && "$NODE_PATH" == /mnt/* ]]; then
        mark_fail "Node.js apunta a Windows ($NODE_PATH) — se requiere nativo Linux" "node"
    else
        NODE_VER=$(node --version | sed 's/v//')
        NODE_MAJOR="${NODE_VER%%.*}"
        if [[ "$NODE_MAJOR" -lt 18 ]]; then
            mark_fail "Node.js ${NODE_VER} < 18" "node"
        else
            if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
                mark_ok "node ${NODE_VER} (Windows)"
            else
                mark_ok "node ${NODE_VER} (Linux nativo)"
            fi
            NODE_OK=1
        fi
    fi
else
    mark_fail "node no encontrado" "node"
fi

if command -v npx &>/dev/null; then
    NPX_PATH="$(command -v npx)"
    if [[ "$IS_WIN_NATIVE" -eq 0 && "$NPX_PATH" == /mnt/* ]]; then
        mark_fail "npx apunta a Windows ($NPX_PATH) — se requiere nativo Linux" "node"
    else
        mark_ok "npx"
    fi
fi

# ─── 4. Python ≥ 3.9 + pip ───────────────────────────────────
# Linux: python3 / pip3 (apt). Windows: python / pip (winget Python.Python.3).
# Windows extra: el stub Microsoft Store en %LOCALAPPDATA%\Microsoft\WindowsApps
# responde a `python3.exe --version` con "Python was not found; ..." en stdout
# y exit 9009. Detectarlo y saltarlo, o el parser de versión rompe con set -u.
_is_msstore_python_stub() {
    [[ "$IS_WIN_NATIVE" -eq 1 ]] || return 1
    local bin="$1"
    local path
    path=$(command -v "$bin" 2>/dev/null) || return 1
    [[ "$path" == *"WindowsApps"* ]] || return 1
    local out
    out=$("$bin" --version 2>&1) || return 0
    [[ "$out" == *"was not found"* ]] || [[ "$out" == *"Microsoft Store"* ]]
}

PY_BIN=""
if command -v python3 &>/dev/null && ! _is_msstore_python_stub python3; then
    PY_BIN="python3"
elif [[ "$IS_WIN_NATIVE" -eq 1 ]] && command -v python &>/dev/null && ! _is_msstore_python_stub python; then
    PY_BIN="python"
fi

if [[ -n "$PY_BIN" ]]; then
    PY_VER=$("$PY_BIN" --version 2>&1 | awk '{print $2}')
    # Defensa: validar que PY_VER sea version string antes de arithmetic.
    if [[ ! "$PY_VER" =~ ^[0-9]+\.[0-9]+ ]]; then
        if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
            mark_fail "$PY_BIN responde texto inesperado ('$PY_VER') — probable stub Microsoft Store" "winget_python"
        else
            mark_fail "$PY_BIN responde texto inesperado ('$PY_VER')" "apt"
            add_apt "python3"
        fi
    else
        PY_MAJOR="${PY_VER%%.*}"
        PY_MINOR="${PY_VER#*.}"; PY_MINOR="${PY_MINOR%%.*}"
        if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 9 ]]; then
            if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
                mark_fail "Python ${PY_VER} < 3.9" "winget_python"
            else
                mark_fail "Python ${PY_VER} < 3.9" "apt"
                add_apt "python3"
            fi
        else
            mark_ok "$PY_BIN ${PY_VER}"
        fi
    fi
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_fail "python no encontrado" "winget_python"
    else
        mark_fail "python3 no encontrado" "apt"
        add_apt "python3"
    fi
fi

if command -v pip3 &>/dev/null && ! _is_msstore_python_stub pip3; then
    mark_ok "pip3"
elif [[ "$IS_WIN_NATIVE" -eq 1 ]] && command -v pip &>/dev/null && ! _is_msstore_python_stub pip; then
    mark_ok "pip"
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_fail "pip no encontrado" "winget_python"
    else
        mark_fail "pip3 no encontrado" "apt"
        add_apt "python3-pip"
    fi
fi

# ─── 5. Docker (binario + daemon activo) ─────────────────────
if command -v docker &>/dev/null; then
    if docker info &>/dev/null 2>&1; then
        mark_ok "docker (daemon activo)"
    else
        if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
            mark_fail "docker instalado pero Docker Desktop no está corriendo" "docker_daemon_win"
        elif [[ "$IS_WSL" -eq 1 ]]; then
            mark_fail "docker instalado pero daemon no activo (WSL)" "docker_daemon_wsl"
        else
            mark_fail "docker instalado pero daemon no activo" "docker_daemon"
        fi
    fi
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_fail "docker no encontrado (requerido para Qdrant vector memory)" "docker_win"
    else
        mark_fail "docker no encontrado (requerido para Qdrant vector memory)" "docker"
    fi
fi

# ─── 6. Ollama (binario) ─────────────────────────────────────
if command -v ollama &>/dev/null; then
    mark_ok "ollama"
    if ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -qE '^nomic-embed-text'; then
        mark_ok "ollama model nomic-embed-text"
    else
        mark_warn "modelo nomic-embed-text no descargado (vector memory degradado hasta pull)" \
                  "ollama pull nomic-embed-text"
        add_model "nomic-embed-text"
    fi
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_fail "ollama no encontrado (requerido para Capa 0, helix-judge, embeddings)" "ollama_win"
    else
        mark_fail "ollama no encontrado (requerido para Capa 0, helix-judge, embeddings)" "ollama"
    fi
    add_model "nomic-embed-text"
fi

# ─── 7. Claude Code CLI ──────────────────────────────────────
if command -v claude &>/dev/null; then
    mark_ok "claude CLI"
else
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_fail "claude CLI no encontrado (requerido para MCPs y para correr Helix)" "claude_cli_win"
    else
        mark_fail "claude CLI no encontrado (requerido para MCPs y para correr Helix)" "claude_cli"
    fi
fi

# ─── 8. Chromium (puppeteer MCP) — sigue WARN ────────────────
CHROME_FOUND=0
for cmd in chromium-browser chromium google-chrome google-chrome-stable; do
    if command -v "$cmd" &>/dev/null; then
        mark_ok "browser puppeteer ($cmd)"
        CHROME_FOUND=1
        break
    fi
done
if [[ "$CHROME_FOUND" -eq 0 && "$IS_WIN_NATIVE" -eq 1 ]]; then
    # Paths típicos de Chrome/Edge en Windows desde Git Bash.
    for winpath in \
        "/c/Program Files/Google/Chrome/Application/chrome.exe" \
        "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
        "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
        "/c/Program Files/Microsoft/Edge/Application/msedge.exe"; do
        if [[ -x "$winpath" ]]; then
            mark_ok "browser puppeteer ($(basename "$winpath"))"
            CHROME_FOUND=1
            break
        fi
    done
fi
if [[ "$CHROME_FOUND" -eq 0 ]]; then
    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        mark_warn "Chrome/Edge no encontrados — puppeteer MCP en estado degradado" \
                  "winget install --id Google.Chrome -e"
    else
        mark_warn "Chromium/Chrome no encontrado — puppeteer MCP en estado degradado" \
                  "sudo apt-get install -y chromium-browser"
    fi
fi

# ============================================================
# Output
# ============================================================
echo ""
echo -e "${BLUE}── Resultado ──${NC}"

# OK
if [[ ${#OK_LABELS[@]} -gt 0 ]]; then
    for label in "${OK_LABELS[@]}"; do
        echo -e "  ${GREEN}✓${NC} $label"
    done
fi

# WARNS
if [[ ${#WARNS_LABELS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}⚠ Advertencias (no bloquean):${NC}"
    for label in "${WARNS_LABELS[@]}"; do
        echo -e "  ${YELLOW}•${NC} $label"
    done
fi

# FAILS
if [[ ${#FAILS_LABELS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}✗ Prerequisitos críticos faltantes:${NC}"
    for label in "${FAILS_LABELS[@]}"; do
        echo -e "  ${RED}•${NC} $label"
    done

    # ── Bloque copy-paste agrupado ─────────────────────────
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Comandos para instalar lo que falta (copy-paste en orden):${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    step=1

    if [[ "$IS_WIN_NATIVE" -eq 1 ]]; then
        # ─── Windows nativo: winget + manual ───────────────────
        if [[ -n "${GROUPS_NEEDED[git_for_windows]:-}" ]]; then
            echo "# ${step}. Reinstalar/actualizar Git for Windows (incluye git, curl, Git Bash):"
            echo "winget install --id Git.Git -e --source winget"
            echo "# Reabrir Git Bash tras instalar."
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[winget_python]:-}" ]]; then
            echo "# ${step}. Python 3.12+ (incluye pip):"
            echo "winget install --id Python.Python.3.12 -e --source winget"
            echo "# Reabrir Git Bash. Verificar: python --version && python -m pip --version"
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[node]:-}" ]]; then
            echo "# ${step}. Node.js LTS:"
            echo "winget install --id OpenJS.NodeJS.LTS -e --source winget"
            echo "# Reabrir Git Bash. Verificar: node --version && npm --version"
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[docker_win]:-}" ]]; then
            echo "# ${step}. Docker Desktop:"
            echo "winget install --id Docker.DockerDesktop -e --source winget"
            echo "# Tras instalar: abrir Docker Desktop y esperar a 'Engine running'."
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[docker_daemon_win]:-}" ]]; then
            echo "# ${step}. Arrancar Docker Desktop:"
            echo "# Abrir 'Docker Desktop' desde el menú Inicio y esperar a 'Engine running'."
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[ollama_win]:-}" ]]; then
            echo "# ${step}. Ollama (Windows):"
            echo "winget install --id Ollama.Ollama -e --source winget"
            echo "# Reabrir Git Bash. Ollama corre como servicio en background."
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[claude_cli_win]:-}" ]]; then
            echo "# ${step}. Claude Code CLI (requiere Node ≥18):"
            echo "npm install -g @anthropic-ai/claude-code"
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[ollama_models]:-}" ]] && [[ ${#OLLAMA_MODELS[@]} -gt 0 ]]; then
            echo "# ${step}. Modelos Ollama (después de instalar ollama):"
            for m in "${OLLAMA_MODELS[@]}"; do
                echo "ollama pull ${m}"
            done
            echo ""
            step=$((step+1))
        fi
        INSTALLER_HINT='install_on_windows.ps1 (PowerShell) o bash install_on_wsl.sh (Git Bash)'
    else
        # ─── Linux / WSL: apt + scripts ────────────────────────
        if [[ -n "${GROUPS_NEEDED[dpkg_fix]:-}" ]]; then
            echo "# ${step}. Reparar dpkg:"
            echo "sudo dpkg --configure -a && sudo apt-get install -f"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[apt]:-}" ]] && [[ ${#APT_PKGS[@]} -gt 0 ]]; then
            UNIQUE_PKGS=$(printf '%s\n' "${APT_PKGS[@]}" | awk '!seen[$0]++' | tr '\n' ' ')
            echo "# ${step}. Paquetes apt:"
            echo "sudo apt-get update && sudo apt-get install -y ${UNIQUE_PKGS}"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[node]:-}" ]]; then
            echo "# ${step}. Node.js 20 (LTS) nativo Linux:"
            echo "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -"
            echo "sudo apt-get install -y nodejs"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[docker]:-}" ]]; then
            echo "# ${step}. Docker:"
            echo "curl -fsSL https://get.docker.com | sh"
            echo "sudo usermod -aG docker \$USER"
            if [[ "$IS_WSL" -eq 1 ]]; then
                echo "# WSL: el daemon se inicia con:"
                echo "sudo service docker start"
            else
                echo "# Iniciar daemon:"
                echo "sudo systemctl enable --now docker"
            fi
            echo "# Reabrir sesión o:  newgrp docker"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[docker_daemon]:-}" ]]; then
            echo "# ${step}. Activar daemon de Docker:"
            echo "sudo systemctl enable --now docker"
            echo ""
            step=$((step+1))
        fi
        if [[ -n "${GROUPS_NEEDED[docker_daemon_wsl]:-}" ]]; then
            echo "# ${step}. Activar daemon de Docker (WSL):"
            echo "sudo service docker start"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[ollama]:-}" ]]; then
            echo "# ${step}. Ollama (modelos locales — Capa 0):"
            echo "curl -fsSL https://ollama.com/install.sh | sh"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[claude_cli]:-}" ]]; then
            echo "# ${step}. Claude Code CLI (requiere Node ≥18):"
            echo "npm install -g @anthropic-ai/claude-code"
            echo ""
            step=$((step+1))
        fi

        if [[ -n "${GROUPS_NEEDED[ollama_models]:-}" ]] && [[ ${#OLLAMA_MODELS[@]} -gt 0 ]]; then
            echo "# ${step}. Modelos Ollama (después de instalar ollama):"
            for m in "${OLLAMA_MODELS[@]}"; do
                echo "ollama pull ${m}"
            done
            echo ""
            step=$((step+1))
        fi
        INSTALLER_HINT='install_on_wsl.sh'
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${RED}Corregir los prerequisitos anteriores y volver a correr ${INSTALLER_HINT}${NC}"
    exit 1
fi

# Solo OKs y/o WARNs → seguir
echo ""
echo -e "${GREEN}✓ Todos los prerequisitos críticos están presentes.${NC}"
exit 0

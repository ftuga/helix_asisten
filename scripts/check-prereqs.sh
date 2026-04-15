#!/usr/bin/env bash
# ============================================================
# Helix — Verificación de prerequisitos
# Uso: bash scripts/check-prereqs.sh
# Devuelve 0 si todo ok, 1 si hay fallas críticas.
# ============================================================
set -uo pipefail

ERRORS=()
WARNINGS=()

# ── Colores ──────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
fail()  { ERRORS+=("$1"); }
warn()  { WARNINGS+=("$1"); }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }

echo "🔍 Verificando prerequisitos..."

# ── 1. Sistema de paquetes saludable ─────────────────────────
if dpkg --audit 2>/dev/null | grep -q .; then
  fail "dpkg está en estado inconsistente — ejecutar: sudo dpkg --configure -a && sudo apt-get install -f"
fi

# ── 2. Herramientas base ──────────────────────────────────────
for cmd in git curl; do
  if command -v "$cmd" &>/dev/null; then
    ok "$cmd"
  else
    fail "$cmd no encontrado — instalar: sudo apt-get install -y $cmd"
  fi
done

# ── 3. Node.js ≥ 18 — versión nativa Linux (no Windows/WSL) ──
if command -v node &>/dev/null; then
  NODE_PATH="$(command -v node)"
  # Detectar Node de Windows montado en WSL
  if [[ "$NODE_PATH" == /mnt/* ]]; then
    fail "Node.js apunta a una ruta de Windows ($NODE_PATH). Los MCPs de Claude Code requieren Node nativo de Linux.\n  Instalar: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
  else
    NODE_VER=$(node --version | sed 's/v//')
    NODE_MAJOR="${NODE_VER%%.*}"
    if [[ "$NODE_MAJOR" -lt 18 ]]; then
      fail "Node.js ${NODE_VER} < 18. Actualizar: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
    else
      ok "node ${NODE_VER} (Linux nativo)"
    fi
  fi
else
  fail "node no encontrado — instalar: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
fi

# Verificar también npx (viene con node, pero por si acaso)
if command -v npx &>/dev/null; then
  NPX_PATH="$(command -v npx)"
  if [[ "$NPX_PATH" == /mnt/* ]]; then
    fail "npx apunta a Windows ($NPX_PATH). Usar npx nativo de Linux (viene con node)."
  else
    ok "npx"
  fi
fi

# ── 4. Python ≥ 3.9 ───────────────────────────────────────────
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
  PY_MAJOR="${PY_VER%%.*}"
  PY_MINOR="${PY_VER#*.}"; PY_MINOR="${PY_MINOR%%.*}"
  if [[ "$PY_MAJOR" -lt 3 ]] || [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 9 ]]; then
    fail "Python ${PY_VER} < 3.9. Actualizar: sudo apt-get install -y python3"
  else
    ok "python3 ${PY_VER}"
  fi
else
  fail "python3 no encontrado — instalar: sudo apt-get install -y python3"
fi

# ── 5. pip3 ───────────────────────────────────────────────────
if command -v pip3 &>/dev/null; then
  ok "pip3"
else
  fail "pip3 no encontrado — instalar: sudo apt-get install -y python3-pip"
fi

# ── 6. zstd (requerido por Ollama) ───────────────────────────
if command -v zstd &>/dev/null; then
  ok "zstd"
else
  warn "zstd no encontrado — requerido por Ollama. Instalar: sudo apt-get install -y zstd"
fi

# ── 7. Docker (opcional, para Qdrant) ─────────────────────────
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    ok "docker (daemon activo)"
  else
    warn "docker instalado pero daemon no corre — Qdrant no se iniciará. Ejecutar: sudo systemctl start docker (o en WSL: sudo service docker start)"
  fi
else
  warn "docker no encontrado — Qdrant vector memory no estará disponible. Instalar: https://docs.docker.com/engine/install/"
fi

# ── 8. rsync (usado en install.sh) ───────────────────────────
if command -v rsync &>/dev/null; then
  ok "rsync"
else
  fail "rsync no encontrado — instalar: sudo apt-get install -y rsync"
fi

# ── 9. Chromium / Chrome (para puppeteer MCP) ─────────────────
CHROME_FOUND=0
for cmd in chromium-browser chromium google-chrome google-chrome-stable; do
  if command -v "$cmd" &>/dev/null; then
    ok "browser para puppeteer ($cmd)"
    CHROME_FOUND=1
    break
  fi
done
if [[ "$CHROME_FOUND" -eq 0 ]]; then
  warn "Chromium/Chrome no encontrado — puppeteer MCP quedará en estado 'Failed to connect'.\n  Instalar: sudo apt-get install -y chromium-browser"
fi

# ── Resumen ───────────────────────────────────────────────────
echo ""
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo -e "${YELLOW}⚠  Advertencias (no bloquean la instalación):${NC}"
  for w in "${WARNINGS[@]}"; do
    echo -e "  ${YELLOW}•${NC} $w"
  done
  echo ""
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo -e "${RED}✗  Prerequisitos faltantes (la instalación no puede continuar):${NC}"
  for e in "${ERRORS[@]}"; do
    echo -e "  ${RED}•${NC} $e"
  done
  echo ""
  echo -e "${RED}Corregir los errores anteriores y volver a ejecutar install.sh${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Todos los prerequisitos críticos están presentes.${NC}"
exit 0

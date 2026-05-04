#!/usr/bin/env bash
# ============================================================
# Helix — Script de instalación
#
# Uso:
#   bash install.sh                       # layout split (default v3.16+)
#   HELIX_LAYOUT=legacy bash install.sh   # mezclado en ~/.claude/ (instalaciones previas)
#   HELIX_LAYOUT=split  bash install.sh   # explícito split en ~/.helix/
#
# Layouts:
#   split  — Helix vive en ~/.helix/. Claude Code stock queda intocado en ~/.claude/.
#            Se invoca con `helix` (wrapper que setea CLAUDE_CONFIG_DIR).
#   legacy — Helix se instala dentro de ~/.claude/. `claude` y `helix` son equivalentes.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$HOME/.claude-template"

# Resolver layout
HELIX_LAYOUT="${HELIX_LAYOUT:-split}"
case "$HELIX_LAYOUT" in
  split)  CLAUDE_DIR="$HOME/.helix" ;;
  legacy) CLAUDE_DIR="$HOME/.claude" ;;
  *)      echo "❌ HELIX_LAYOUT debe ser 'split' o 'legacy' (recibido: '$HELIX_LAYOUT')"; exit 1 ;;
esac

# Si layout=split y existe instalación legacy en ~/.claude, advertir y ofrecer migrar
if [[ "$HELIX_LAYOUT" == "split" ]] && [[ -f "$HOME/.claude/CLAUDE.md" ]] && grep -q "Helix" "$HOME/.claude/CLAUDE.md" 2>/dev/null && [[ ! -d "$HOME/.helix" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  Detecté Helix instalado en ~/.claude/ (layout legacy)."
  echo ""
  echo "   Para migrar a layout split (Claude Code stock + Helix aislado):"
  echo "     bash $REPO_DIR/scripts/migrate-to-split.sh"
  echo ""
  echo "   O instalar split en paralelo (no toca ~/.claude/):"
  echo "     [Enter] continuar con HELIX_LAYOUT=split en ~/.helix/"
  echo "     [c]    cancelar"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  read -r -p "> " _ans
  [[ "${_ans,,}" == "c" ]] && exit 0
fi

INSTALL_WARNINGS=()

echo "🔷 Instalando Helix en $CLAUDE_DIR (layout=$HELIX_LAYOUT)..."

# ── 0. Verificar prerequisitos ───────────────────────────────
bash "$REPO_DIR/scripts/check-prereqs.sh" || exit 1
echo ""

# ── 1. Crear directorios necesarios ─────────────────────────
mkdir -p \
  "$CLAUDE_DIR/agents/disabled" \
  "$CLAUDE_DIR/commands" \
  "$CLAUDE_DIR/memory/agents" \
  "$CLAUDE_DIR/memory/topics" \
  "$CLAUDE_DIR/skills" \
  "$TEMPLATE_DIR/.claude/memory" \
  "$TEMPLATE_DIR/.claude/skills"

# ── 2. Copiar configuración ~/.claude ───────────────────────
echo "→ Copiando configuración principal..."
cp "$REPO_DIR/claude/CLAUDE.md"         "$CLAUDE_DIR/"
cp "$REPO_DIR/claude/settings.json"     "$CLAUDE_DIR/"

# Scripts ejecutables
for script in evolve.sh session-start.sh session-end.sh self-check.sh compress.sh health-check.sh; do
  if [[ -f "$REPO_DIR/claude/$script" ]]; then
    cp "$REPO_DIR/claude/$script" "$CLAUDE_DIR/"
    chmod +x "$CLAUDE_DIR/$script"
  fi
done

# compress_logic.py
[[ -f "$REPO_DIR/claude/compress_logic.py" ]] && \
  cp "$REPO_DIR/claude/compress_logic.py" "$CLAUDE_DIR/"

# ── 3. Agents ───────────────────────────────────────────────
echo "→ Copiando agents..."
cp "$REPO_DIR/claude/agents/"*.md       "$CLAUDE_DIR/agents/" 2>/dev/null || true
cp "$REPO_DIR/claude/agents/disabled/"*.md "$CLAUDE_DIR/agents/disabled/" 2>/dev/null || true

# ── 4. Commands ─────────────────────────────────────────────
echo "→ Copiando commands..."
cp "$REPO_DIR/claude/commands/"*.md     "$CLAUDE_DIR/commands/" 2>/dev/null || true
# Comando helix_control_total (activa el modo desde cualquier proyecto)
cp "$REPO_DIR/claude/commands/helix_control_total.md" "$CLAUDE_DIR/commands/" 2>/dev/null || true

# ── 5. Memory ───────────────────────────────────────────────
echo "→ Copiando memory..."
cp "$REPO_DIR/claude/memory/"*.md       "$CLAUDE_DIR/memory/" 2>/dev/null || true
cp "$REPO_DIR/claude/memory/"*.txt      "$CLAUDE_DIR/memory/" 2>/dev/null || true

# Idempotente: no sobreescribir agents/ ni topics/ si ya existen personalizaciones
# (detectamos personalización si el directorio no está vacío y no vino del repo)
_copy_if_not_customized() {
  local src="$1" dst="$2" label="$3"
  if [[ -d "$dst" ]] && ls "$dst"/*.md &>/dev/null 2>&1; then
    echo "  → $label ya existe con contenido — omitiendo (usar --force para sobreescribir)"
  else
    cp "$src/"*.md "$dst/" 2>/dev/null || true
    echo "  ✓ $label copiado"
  fi
}

# Con --force sobreescribir todo
if [[ "${HELIX_FORCE:-}" == "1" ]]; then
  cp "$REPO_DIR/claude/memory/agents/"*.md   "$CLAUDE_DIR/memory/agents/" 2>/dev/null || true
  cp "$REPO_DIR/claude/memory/topics/"*.md   "$CLAUDE_DIR/memory/topics/" 2>/dev/null || true
else
  _copy_if_not_customized "$REPO_DIR/claude/memory/agents" "$CLAUDE_DIR/memory/agents" "memory/agents"
  _copy_if_not_customized "$REPO_DIR/claude/memory/topics" "$CLAUDE_DIR/memory/topics" "memory/topics"
fi

# user-profile.md — crear desde template si no existe (contenido local, nunca en repo)
if [[ ! -f "$CLAUDE_DIR/memory/user-profile.md" ]]; then
  if [[ -f "$REPO_DIR/claude/memory/user-profile.template.md" ]]; then
    cp "$REPO_DIR/claude/memory/user-profile.template.md" "$CLAUDE_DIR/memory/user-profile.md"
    echo "  ✅ user-profile.md creado desde template — completar para personalizar Helix"
  fi
fi

# ── 6. Skills ───────────────────────────────────────────────
echo "→ Copiando skills..."
cp -r "$REPO_DIR/claude/skills/." "$CLAUDE_DIR/skills/"

# ── 6b. Helpers globales (sync completo desde claude/helpers/) ──
echo "→ Instalando helpers globales..."
mkdir -p "$CLAUDE_DIR/helpers"
rsync -a "$REPO_DIR/claude/helpers/" "$CLAUDE_DIR/helpers/"
chmod +x "$CLAUDE_DIR/helpers/"*.sh 2>/dev/null || true
# Validar statusline post-install
STATUSLINE_PATH="$CLAUDE_DIR/helpers/helix-statusline.sh"
if [[ ! -x "$STATUSLINE_PATH" ]]; then
  INSTALL_WARNINGS+=("helix-statusline.sh no instalado — el statusline en settings.json fallará silenciosamente")
fi

# ── 6c. Launcher helix + alias ──────────────────────────────
echo "→ Instalando launcher helix..."
mkdir -p "$HOME/helix_asisten/scripts"
cp "$REPO_DIR/scripts/helix.sh" "$HOME/helix_asisten/scripts/"
chmod +x "$HOME/helix_asisten/scripts/helix.sh"

ALIAS_LINE='alias helix="bash $HOME/helix_asisten/scripts/helix.sh"'
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ -f "$RC" ]] && ! grep -q 'helix_asisten/scripts/helix.sh' "$RC"; then
    echo "" >> "$RC"
    echo "# Helix — launcher de Claude Code" >> "$RC"
    echo "$ALIAS_LINE" >> "$RC"
    echo "  → alias helix añadido a $RC"
  fi
done

# ── 6d. Vector Memory — helix-vector + hv ───────────────────
echo "→ Instalando Helix Vector Memory..."
cp "$REPO_DIR/scripts/helix-vector.py"       "$CLAUDE_DIR/"
cp "$REPO_DIR/scripts/hv.sh"                 "$CLAUDE_DIR/"
cp "$REPO_DIR/scripts/helix-agent-evolve.py" "$CLAUDE_DIR/"
cp "$REPO_DIR/scripts/helix-project-index.sh" "$CLAUDE_DIR/"
chmod +x "$CLAUDE_DIR/hv.sh" "$CLAUDE_DIR/helix-project-index.sh" "$CLAUDE_DIR/helix-agent-evolve.py"

# Crear symlinks globales
mkdir -p "$HOME/.local/bin"
ln -sf "$CLAUDE_DIR/hv.sh" "$HOME/.local/bin/hv" 2>/dev/null || true
ln -sf "$CLAUDE_DIR/helix-project-index.sh" "$HOME/.local/bin/helix-project-index" 2>/dev/null || true

# Instalar dependencia Python
# Ubuntu 24.04+ (PEP 668): pip sin flags falla. Intentar --user primero,
# luego --break-system-packages como fallback.
_pip_install_qdrant() {
  pip3 install --quiet --user qdrant-client 2>/dev/null && return 0
  pip3 install --quiet --user --break-system-packages qdrant-client 2>/dev/null && return 0
  return 1
}
if command -v pip3 &>/dev/null; then
  if _pip_install_qdrant; then
    echo "  ✓ qdrant-client instalado"
  else
    INSTALL_WARNINGS+=("qdrant-client no se pudo instalar — vector memory no disponible. Ejecutar manualmente: pip3 install --user qdrant-client")
  fi
else
  INSTALL_WARNINGS+=("pip3 no disponible — instalar: sudo apt-get install -y python3-pip && pip3 install --user qdrant-client")
fi

# Qdrant vía Docker (no bloquea si Docker no está disponible)
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "helix-qdrant"; then
        echo "  → Iniciando Qdrant..."
        if docker volume create qdrant_storage &>/dev/null && \
           docker run -d --name helix-qdrant --restart unless-stopped \
               -p 6333:6333 -v qdrant_storage:/qdrant/storage \
               qdrant/qdrant:latest &>/dev/null; then
            echo "  ✓ Qdrant iniciado"
        else
            INSTALL_WARNINGS+=("Qdrant no se pudo iniciar. Ejecutar manualmente:\n  docker run -d --name helix-qdrant --restart unless-stopped -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant:latest")
        fi
    else
        echo "  → Qdrant ya está corriendo"
    fi
elif command -v docker &>/dev/null; then
    INSTALL_WARNINGS+=("Docker instalado pero daemon no activo — Qdrant no iniciado. En WSL: sudo service docker start")
else
    INSTALL_WARNINGS+=("Docker no encontrado — Qdrant no disponible. Instalar Docker y ejecutar:\n  docker run -d --name helix-qdrant --restart unless-stopped -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant:latest")
fi

# Embedding model vía Ollama
OLLAMA_PULL_PID=""
if command -v ollama &>/dev/null; then
    ollama pull nomic-embed-text &>/dev/null &
    OLLAMA_PULL_PID=$!
    echo "  → nomic-embed-text descargando en background..."
else
    INSTALL_WARNINGS+=("Ollama no encontrado — Capa 0 (modelos locales) no disponible. Instalar: https://ollama.com/download\n  Luego: ollama pull nomic-embed-text")
fi

echo "  ✓ Vector Memory listo (hv y helix-project-index disponibles)"

# ── 6e. Bootstrap del índice vectorial (background, no bloquea install) ──
# En máquina nueva, qdrant_storage arranca vacío. Las fuentes de verdad
# (agents/*.md, memory/*.md) ya están en disco; los embeddings se generan aquí.
# Sync diferido que espera al pull de nomic-embed-text y luego indexa.
# Idempotente: re-install no duplica (IDs estables por hash).
BOOTSTRAP_LOG="$CLAUDE_DIR/memory/install-vector-bootstrap.log"
(
  echo "[$(date '+%F %T')] bootstrap iniciado" >> "$BOOTSTRAP_LOG"
  if [[ -n "$OLLAMA_PULL_PID" ]]; then
    for _ in $(seq 1 180); do
      kill -0 "$OLLAMA_PULL_PID" 2>/dev/null || break
      sleep 1
    done
  fi
  if ! curl -sf http://localhost:6333/healthz >/dev/null 2>&1; then
    echo "[$(date '+%F %T')] skip: qdrant no responde en :6333 — correr 'hv sync' manualmente tras iniciar Qdrant" >> "$BOOTSTRAP_LOG"
    exit 0
  fi
  if ! command -v ollama >/dev/null 2>&1 || ! ollama list 2>/dev/null | grep -q nomic-embed-text; then
    echo "[$(date '+%F %T')] skip: nomic-embed-text no disponible — correr 'hv sync' cuando termine el pull" >> "$BOOTSTRAP_LOG"
    exit 0
  fi
  HV="$CLAUDE_DIR/hv.sh"
  [[ -x "$HV" ]] || { echo "[$(date '+%F %T')] skip: hv.sh no ejecutable" >> "$BOOTSTRAP_LOG"; exit 0; }
  echo "[$(date '+%F %T')] indexando agentes..." >> "$BOOTSTRAP_LOG"
  bash "$HV" index-agents >> "$BOOTSTRAP_LOG" 2>&1 || echo "[$(date '+%F %T')] fallo index-agents" >> "$BOOTSTRAP_LOG"
  echo "[$(date '+%F %T')] indexando memorias..." >> "$BOOTSTRAP_LOG"
  bash "$HV" index-memories >> "$BOOTSTRAP_LOG" 2>&1 || echo "[$(date '+%F %T')] fallo index-memories" >> "$BOOTSTRAP_LOG"
  echo "[$(date '+%F %T')] bootstrap completo" >> "$BOOTSTRAP_LOG"
) >/dev/null 2>&1 &
disown
echo "  → Bootstrap del índice vectorial lanzado en background"
echo "    Log: $BOOTSTRAP_LOG"

# ── 7. Template de nuevo proyecto ───────────────────────────
echo "→ Copiando template..."
cp "$REPO_DIR/template/CLAUDE.md"       "$TEMPLATE_DIR/"
cp "$REPO_DIR/template/init-project.sh" "$TEMPLATE_DIR/"
chmod +x "$TEMPLATE_DIR/init-project.sh"
cp -r "$REPO_DIR/template/.claude/memory/." "$TEMPLATE_DIR/.claude/memory/" 2>/dev/null || true
cp -r "$REPO_DIR/template/.claude/skills/." "$TEMPLATE_DIR/.claude/skills/" 2>/dev/null || true

# ── 8. MCPs necesarios ──────────────────────────────────────
echo ""
if command -v claude &>/dev/null; then
  echo "→ Claude CLI detectado — instalando MCPs automáticamente..."

  _mcp_add() {
    local name="$1"; shift
    if claude mcp add "$name" -- "$@" &>/dev/null 2>&1; then
      echo "  ✓ MCP $name"
    else
      INSTALL_WARNINGS+=("MCP $name no se pudo instalar automáticamente. Ejecutar: claude mcp add $name -- $*")
    fi
  }

  _mcp_add context7 npx -y @upstash/context7-mcp
  _mcp_add browser-tools npx @agentdeskai/browser-tools-mcp@1.2.0

  # Puppeteer: advertir sobre Chromium antes de instalar
  CHROME_OK=0
  for _c in chromium-browser chromium google-chrome google-chrome-stable; do
    command -v "$_c" &>/dev/null && CHROME_OK=1 && break
  done
  if [[ "$CHROME_OK" -eq 0 ]]; then
    INSTALL_WARNINGS+=("puppeteer MCP instalado pero Chromium no encontrado — quedará en estado 'Failed to connect'.\n  Instalar: sudo apt-get install -y chromium-browser\n  Luego reiniciar Claude Code.")
  fi
  _mcp_add puppeteer npx -y @modelcontextprotocol/server-puppeteer

  echo ""
  echo "→ Para verificar: claude mcp list"
  echo ""
else
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  PASO MANUAL: Instalar MCPs"
  echo "   (claude CLI no encontrado en PATH)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  claude mcp add context7 -- npx -y @upstash/context7-mcp"
  echo "  claude mcp add browser-tools -- npx @agentdeskai/browser-tools-mcp@1.2.0"
  echo ""
  echo "  # Puppeteer requiere Chromium:"
  echo "  sudo apt-get install -y chromium-browser"
  echo "  claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer"
  echo ""
fi

echo "  # Ollama — modelos Capa 0 (opcional, requiere ollama instalado)"
echo "  #    Instalar ollama: https://ollama.com/download"
echo "  ollama pull qwen2.5-coder:7b"
echo "  ollama pull llama3.2:3b"
echo "  ollama create helix-coder -f $REPO_DIR/ollama/helix-coder.Modelfile"
echo "  ollama create helix-scout -f $REPO_DIR/ollama/helix-scout.Modelfile"
echo ""
# ── 9. HELIX-COMPRESS — generar slices frescos ──────────────
echo "→ Generando slices HELIX-DISTILL..."
if bash "$CLAUDE_DIR/helpers/helix-distill.sh" run &>/dev/null; then
  echo "  ✓ Slices generados (78-96% ahorro por agente)"
else
  echo "  ⚠ helix-distill.sh falló — ejecutar manualmente: bash ~/.claude/helpers/helix-distill.sh run"
fi

# ── Prompt user-profile ──────────────────────────────────────
if [[ -f "$CLAUDE_DIR/memory/user-profile.md" ]]; then
  if grep -q "TU NOMBRE\|YOUR NAME\|<completar>" "$CLAUDE_DIR/memory/user-profile.md" 2>/dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 PASO RECOMENDADO: Completar tu perfil"
    echo "   Helix personaliza su comportamiento según tu perfil."
    echo "   Editar: $CLAUDE_DIR/memory/user-profile.md"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
fi

# ── Resumen de warnings acumulados ───────────────────────────
echo ""
if [[ ${#INSTALL_WARNINGS[@]} -gt 0 ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  Componentes opcionales que requieren atención:"
  for w in "${INSTALL_WARNINGS[@]}"; do
    echo -e "  • $w"
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Helix instalado en $CLAUDE_DIR (layout=$HELIX_LAYOUT)"
echo ""
if [[ "$HELIX_LAYOUT" == "split" ]]; then
  echo "   Cómo usarlo:"
  echo "     helix              → arranca Claude Code con ambiente Helix (CLAUDE_CONFIG_DIR=$CLAUDE_DIR)"
  echo "     claude             → arranca Claude Code stock (sin Helix, ~/.claude/ intacto)"
  echo "     helix --where      → muestra qué layout está activo"
  echo ""
  echo "   El alias 'helix' fue agregado a ~/.bashrc / ~/.zshrc — abrí una nueva terminal."
else
  echo "   Reinicia Claude Code para aplicar los cambios. Layout legacy: 'claude' y 'helix' son equivalentes."
fi
echo ""
echo "   Para reinstalar sobreescribiendo todo: HELIX_FORCE=1 bash install.sh"

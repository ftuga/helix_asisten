#!/usr/bin/env bash
# ============================================================
# Helix — Script de instalación en nueva máquina
# Uso: bash install.sh
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TEMPLATE_DIR="$HOME/.claude-template"

echo "🔷 Instalando Helix en $HOME..."

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
cp "$REPO_DIR/claude/memory/agents/"*.md   "$CLAUDE_DIR/memory/agents/" 2>/dev/null || true
cp "$REPO_DIR/claude/memory/topics/"*.md   "$CLAUDE_DIR/memory/topics/" 2>/dev/null || true

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
# statusline también en helix-engine
cp "$REPO_DIR/helix-engine/.claude/helpers/statusline.cjs" "$CLAUDE_DIR/helpers/"

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
pip3 install --quiet qdrant-client 2>/dev/null || echo "  ⚠ pip3 no disponible — instalar manualmente: pip3 install qdrant-client"

# Qdrant vía Docker (no bloquea si Docker no está disponible)
if command -v docker &>/dev/null; then
    if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "helix-qdrant"; then
        echo "  → Iniciando Qdrant..."
        docker volume create qdrant_storage &>/dev/null || true
        docker run -d --name helix-qdrant --restart unless-stopped \
            -p 6333:6333 -v qdrant_storage:/qdrant/storage \
            qdrant/qdrant:latest &>/dev/null || echo "  ⚠ No se pudo iniciar Qdrant — ejecutar manualmente"
    else
        echo "  → Qdrant ya está corriendo"
    fi
else
    echo "  ⚠ Docker no encontrado — Qdrant requiere Docker. Instalar y ejecutar:"
    echo "     docker run -d --name helix-qdrant --restart unless-stopped \\"
    echo "       -p 6333:6333 -v qdrant_storage:/qdrant/storage qdrant/qdrant:latest"
fi

# Embedding model vía Ollama
if command -v ollama &>/dev/null; then
    ollama pull nomic-embed-text &>/dev/null &
    echo "  → nomic-embed-text descargando en background..."
else
    echo "  ⚠ Ollama no encontrado — instalar y ejecutar: ollama pull nomic-embed-text"
fi

echo "  ✓ Vector Memory listo (hv y helix-project-index disponibles)"

# ── 7. Template de nuevo proyecto ───────────────────────────
echo "→ Copiando template..."
cp "$REPO_DIR/template/CLAUDE.md"       "$TEMPLATE_DIR/"
cp "$REPO_DIR/template/init-project.sh" "$TEMPLATE_DIR/"
chmod +x "$TEMPLATE_DIR/init-project.sh"
cp -r "$REPO_DIR/template/.claude/memory/." "$TEMPLATE_DIR/.claude/memory/" 2>/dev/null || true
cp -r "$REPO_DIR/template/.claude/skills/." "$TEMPLATE_DIR/.claude/skills/" 2>/dev/null || true

# ── 8. MCPs necesarios ──────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  PASO MANUAL: Instalar MCPs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ejecutar en la nueva máquina:"
echo ""
echo "  # 1. Ecosistema RuFlo (https://github.com/ruvnet/ruflo)"
echo "  npx ruflo --version                             # verificar (debe ser 3.5.41+)"
echo "  claude mcp add claude-flow -- npx -y @claude-flow/cli@3.5.41 mcp start"
echo "  npx agentic-flow@alpha --version                # calentar caché ONNX"
echo ""
echo "  # 2. Otros MCPs"
echo "  claude mcp add context7 -- npx -y @upstash/context7-mcp"
echo "  claude mcp add browser-tools -- npx @agentdeskai/browser-tools-mcp@1.2.0"
echo "  claude mcp add puppeteer -- npx -y @modelcontextprotocol/server-puppeteer"
echo ""
echo "  # 3. Ollama — modelos Capa 0 (opcional, requiere ollama instalado)"
echo "  #    Instalar ollama: https://ollama.com/download"
echo "  ollama pull qwen2.5-coder:7b"
echo "  ollama pull llama3.2:3b"
echo "  ollama create helix-coder -f \$REPO_DIR/ollama/helix-coder.Modelfile"
echo "  ollama create helix-scout -f \$REPO_DIR/ollama/helix-scout.Modelfile"
echo ""
echo "  # 4. Diagnóstico y verificación"
echo "  ruflo doctor --fix"
echo "  sh \$REPO_DIR/scripts/verify-appliance.sh --quick"
echo ""
# ── 9. HELIX-COMPRESS — generar slices frescos ──────────────
echo "→ Generando slices HELIX-DISTILL..."
if bash "$CLAUDE_DIR/helpers/helix-distill.sh" run &>/dev/null; then
  echo "  ✓ Slices generados (78-96% ahorro por agente)"
else
  echo "  ⚠ helix-distill.sh falló — ejecutar manualmente: bash ~/.claude/helpers/helix-distill.sh run"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Helix instalado correctamente en $HOME"
echo "   Reinicia Claude Code para aplicar los cambios."

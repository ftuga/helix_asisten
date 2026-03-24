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

# ── 6. Skills ───────────────────────────────────────────────
echo "→ Copiando skills..."
cp -r "$REPO_DIR/claude/skills/." "$CLAUDE_DIR/skills/"

# ── 6b. Helpers globales (statusline + scope-guard + cost-tracker + routing) ──
echo "→ Instalando helpers globales..."
mkdir -p "$CLAUDE_DIR/helpers"
cp "$REPO_DIR/helix-engine/.claude/helpers/statusline.cjs" "$CLAUDE_DIR/helpers/"
# Helpers de la base claude/
for helper in helix-bitacora-hook.sh helix-detect-stack.sh helix-metricas.sh \
              scope-guard.sh cost-tracker.sh routing-learn.sh helix-swarm-panel.sh; do
  if [[ -f "$REPO_DIR/claude/helpers/$helper" ]]; then
    cp "$REPO_DIR/claude/helpers/$helper" "$CLAUDE_DIR/helpers/"
    chmod +x "$CLAUDE_DIR/helpers/$helper"
  fi
done

# ── 6c. Configuración tmux ──────────────────────────────────
echo "→ Instalando configuración tmux..."
if [[ -f "$REPO_DIR/scripts/tmux.conf" ]]; then
  cp "$REPO_DIR/scripts/tmux.conf" "$HOME/.tmux.conf"
  echo "  → ~/.tmux.conf actualizado (tema Catppuccin Mocha)"
fi

# ── 6d. Launcher helix + alias ──────────────────────────────
echo "→ Instalando launcher helix..."
mkdir -p "$HOME/helix_asisten/scripts"
cp "$REPO_DIR/scripts/helix.sh" "$HOME/helix_asisten/scripts/"
chmod +x "$HOME/helix_asisten/scripts/helix.sh"

ALIAS_LINE='alias helix="bash $HOME/helix_asisten/scripts/helix.sh"'
for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [[ -f "$RC" ]] && ! grep -q 'helix_asisten/scripts/helix.sh' "$RC"; then
    echo "" >> "$RC"
    echo "# Helix — launcher de Claude Code con panel tmux" >> "$RC"
    echo "$ALIAS_LINE" >> "$RC"
    echo "  → alias helix añadido a $RC"
  fi
done

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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Helix instalado correctamente en $HOME"
echo "   Reinicia Claude Code para aplicar los cambios."

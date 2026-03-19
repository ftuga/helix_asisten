#!/usr/bin/env bash
# ============================================================
# Helix — Sincronizar cambios de ~/.claude al repo
# Uso: bash update.sh  (desde ~/helix_asisten/)
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
TEMPLATE_DIR="$HOME/.claude-template"

echo "🔄 Sincronizando ~/.claude → $REPO_DIR..."

# Scripts y config
for f in CLAUDE.md settings.json evolve.sh session-start.sh session-end.sh \
          self-check.sh compress.sh compress_logic.py health-check.sh; do
  [[ -f "$CLAUDE_DIR/$f" ]] && cp "$CLAUDE_DIR/$f" "$REPO_DIR/claude/"
done

# Agents
cp "$CLAUDE_DIR/agents/"*.md           "$REPO_DIR/claude/agents/" 2>/dev/null || true
cp "$CLAUDE_DIR/agents/disabled/"*.md  "$REPO_DIR/claude/agents/disabled/" 2>/dev/null || true

# Commands
cp "$CLAUDE_DIR/commands/"*.md         "$REPO_DIR/claude/commands/" 2>/dev/null || true

# Memory
cp "$CLAUDE_DIR/memory/"*.md           "$REPO_DIR/claude/memory/" 2>/dev/null || true
cp "$CLAUDE_DIR/memory/"*.txt          "$REPO_DIR/claude/memory/" 2>/dev/null || true
cp "$CLAUDE_DIR/memory/agents/"*.md    "$REPO_DIR/claude/memory/agents/" 2>/dev/null || true
cp "$CLAUDE_DIR/memory/topics/"*.md    "$REPO_DIR/claude/memory/topics/" 2>/dev/null || true

# Skills (sync completo)
rsync -a --delete "$CLAUDE_DIR/skills/" "$REPO_DIR/claude/skills/"

# ── helix-engine (proyecto SerSocial como fuente) ───────────
PROJECT_SRC="$HOME/documentos/proyectos_tecnologicos/registro_retiros/proyecto"
if [[ -d "$PROJECT_SRC/.claude" ]]; then
  echo "→ Sincronizando helix-engine..."
  cp "$PROJECT_SRC/.mcp.json" "$REPO_DIR/helix-engine/" 2>/dev/null || true
  rsync -a --delete "$PROJECT_SRC/.claude/agents/"   "$REPO_DIR/helix-engine/.claude/agents/"
  rsync -a --delete "$PROJECT_SRC/.claude/commands/" "$REPO_DIR/helix-engine/.claude/commands/"
  rsync -a --delete "$PROJECT_SRC/.claude/helpers/"  "$REPO_DIR/helix-engine/.claude/helpers/"
  rsync -a --delete "$PROJECT_SRC/.claude/skills/"   "$REPO_DIR/helix-engine/.claude/skills/"
  cp "$PROJECT_SRC/.claude/settings.json"  "$REPO_DIR/helix-engine/.claude/" 2>/dev/null || true
  cp "$PROJECT_SRC/.claude/statusline.mjs" "$REPO_DIR/helix-engine/.claude/" 2>/dev/null || true
  cp "$PROJECT_SRC/.claude/statusline.sh"  "$REPO_DIR/helix-engine/.claude/" 2>/dev/null || true
  cp "$PROJECT_SRC/.claude-flow/config.yaml"     "$REPO_DIR/helix-engine/.claude-flow/" 2>/dev/null || true
  cp "$PROJECT_SRC/.claude-flow/CAPABILITIES.md" "$REPO_DIR/helix-engine/.claude-flow/" 2>/dev/null || true
  # security (no runtime)
  [[ -f "$PROJECT_SRC/.claude-flow/security/audit-status.json" ]] && \
    cp "$PROJECT_SRC/.claude-flow/security/audit-status.json" "$REPO_DIR/helix-engine/.claude-flow/security/" 2>/dev/null || true
fi

# Template
[[ -f "$TEMPLATE_DIR/CLAUDE.md" ]]       && cp "$TEMPLATE_DIR/CLAUDE.md" "$REPO_DIR/template/"
[[ -f "$TEMPLATE_DIR/init-project.sh" ]] && cp "$TEMPLATE_DIR/init-project.sh" "$REPO_DIR/template/"
rsync -a "$TEMPLATE_DIR/.claude/memory/" "$REPO_DIR/template/.claude/memory/" 2>/dev/null || true
rsync -a "$TEMPLATE_DIR/.claude/skills/" "$REPO_DIR/template/.claude/skills/" 2>/dev/null || true

echo "✅ Sincronización completa."
echo "   Ahora: git add -A && git commit -m 'sync: \$(date +%Y-%m-%d)' && git push"

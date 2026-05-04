#!/usr/bin/env bash
# ============================================================
# Helix — Sincronizar cambios de ~/.claude al repo
# Uso: bash update.sh          → solo sync (muestra diff al final)
#      bash update.sh --push   → sync + commit + push automático
# ============================================================
set -euo pipefail

AUTO_PUSH=0
[[ "${1:-}" == "--push" ]] && AUTO_PUSH=1

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

# user-profile.md está en .gitignore — nunca llega al repo (contenido personal del usuario)
# El template está en user-profile.template.md — install.sh lo copia al instalar

# Sanitize: eliminar contexto de proyecto privado de memory/agents y topics
echo "→ Sanitizando contexto de proyecto..."
bash "$REPO_DIR/scripts/sanitize-memory-agents.sh" "$REPO_DIR/claude/memory/agents"
bash "$REPO_DIR/scripts/sanitize-memory-agents.sh" "$REPO_DIR/claude/memory/topics"

# Skills (sync completo + sanitize inline)
rsync -a --delete "$CLAUDE_DIR/skills/" "$REPO_DIR/claude/skills/"
echo "→ Sanitizando skills..."
PATTERNS_FILE="$REPO_DIR/scripts/private-patterns.txt"
if [[ -f "$PATTERNS_FILE" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    PATTERN="${line%%|*}"
    # Reemplazar patrón en todos los .md de skills (literal, no regex)
    (grep -rl "$PATTERN" "$REPO_DIR/claude/skills/" 2>/dev/null || true) | while read -r f; do
      sed -i "s/$PATTERN//g" "$f"
      echo "  ✓ sanitized: $(basename $f) — '$PATTERN'"
    done
  done < "$PATTERNS_FILE"
fi

# Helpers globales (sync completo)
rsync -a --delete "$CLAUDE_DIR/helpers/" "$REPO_DIR/claude/helpers/"

# Council (constitución + scripts; runs locales excluidos por .gitignore del council)
if [[ -d "$CLAUDE_DIR/council" ]]; then
  mkdir -p "$REPO_DIR/claude/council/scripts"
  [[ -f "$CLAUDE_DIR/council/constitution.md" ]] && \
    cp "$CLAUDE_DIR/council/constitution.md" "$REPO_DIR/claude/council/"
  [[ -f "$CLAUDE_DIR/council/inter-agent-language.md" ]] && \
    cp "$CLAUDE_DIR/council/inter-agent-language.md" "$REPO_DIR/claude/council/"
  rsync -a "$CLAUDE_DIR/council/scripts/" "$REPO_DIR/claude/council/scripts/" 2>/dev/null || true
fi

# Template
[[ -f "$TEMPLATE_DIR/CLAUDE.md" ]]       && cp "$TEMPLATE_DIR/CLAUDE.md" "$REPO_DIR/template/"
[[ -f "$TEMPLATE_DIR/init-project.sh" ]] && cp "$TEMPLATE_DIR/init-project.sh" "$REPO_DIR/template/"
rsync -a "$TEMPLATE_DIR/.claude/memory/" "$REPO_DIR/template/.claude/memory/" 2>/dev/null || true
rsync -a "$TEMPLATE_DIR/.claude/skills/" "$REPO_DIR/template/.claude/skills/" 2>/dev/null || true

echo "✅ Sincronización completa."

# Mostrar resumen de cambios
cd "$REPO_DIR"
CHANGED=$(git status --short | wc -l | tr -d '[:space:]')
if [[ "$CHANGED" -eq 0 ]]; then
  echo "   Sin cambios — repo ya está al día."
  exit 0
fi

echo ""
echo "   Cambios detectados ($CHANGED archivos):"
git status --short | head -20

if [[ "$AUTO_PUSH" -eq 1 ]]; then
  FECHA=$(date +%Y-%m-%d)
  git add -A
  git commit -m "sync: $FECHA"
  git push origin main
  echo ""
  echo "   ✓ Commit y push realizados."
else
  echo ""
  echo "   Para guardar: bash update.sh --push"
  echo "   O manualmente: git add -A && git commit -m 'sync: \$(date +%Y-%m-%d)' && git push"
fi

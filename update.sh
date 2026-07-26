#!/usr/bin/env bash
# ============================================================
# Helix — Sincronizar cambios del entorno Helix activo al repo
#
# Detecta layout automáticamente:
#   - Si ~/.helix/CLAUDE.md existe → split layout (sync desde ~/.helix/)
#   - Si no → legacy layout (sync desde ~/.claude/)
#   - Override manual: HELIX_HOME=/path/to/dir bash update.sh
#
# Uso: bash update.sh          → solo sync (muestra diff al final)
#      bash update.sh --push   → sync + commit + push automático
# ============================================================
set -euo pipefail

AUTO_PUSH=0
[[ "${1:-}" == "--push" ]] && AUTO_PUSH=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$HOME/.claude-template"

# Resolver source dir según layout
if [[ -n "${HELIX_HOME:-}" ]] && [[ -d "$HELIX_HOME" ]]; then
  CLAUDE_DIR="$HELIX_HOME"
elif [[ -f "$HOME/.helix/CLAUDE.md" ]] && grep -q "Helix" "$HOME/.helix/CLAUDE.md" 2>/dev/null; then
  CLAUDE_DIR="$HOME/.helix"
elif [[ -f "$HOME/.claude/CLAUDE.md" ]] && grep -q "Helix" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
  CLAUDE_DIR="$HOME/.claude"
else
  echo "❌ No detecté instalación Helix activa (ni ~/.helix/ ni ~/.claude/ tienen CLAUDE.md con Helix)."
  exit 1
fi

echo "🔄 Sincronizando $CLAUDE_DIR → $REPO_DIR..."

# El privacy guard vivía sólo en .git/hooks/ (no versionado): un clone fresco
# —incluido el derivado institucional— quedaba SIN guard. Ahora está versionado
# en scripts/hooks/ y se activa por core.hooksPath.
if [[ "$(git -C "$REPO_DIR" config core.hooksPath 2>/dev/null)" != "scripts/hooks" ]]; then
  git -C "$REPO_DIR" config core.hooksPath scripts/hooks
  echo "   ⬡ privacy guard activado (core.hooksPath → scripts/hooks)"
fi

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
# El template está en user-profile.template.md — install_on_wsl.sh lo copia al instalar

# Sanitize: eliminar contexto de proyecto privado de memory/agents y topics
echo "→ Sanitizando contexto de proyecto..."
bash "$REPO_DIR/scripts/sanitize-memory-agents.sh" "$REPO_DIR/claude/memory/agents"
bash "$REPO_DIR/scripts/sanitize-memory-agents.sh" "$REPO_DIR/claude/memory/topics"


# Skills (sync completo — la sanitización va en el bloque unificado de abajo)
rsync -a --delete "$CLAUDE_DIR/skills/" "$REPO_DIR/claude/skills/"

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

# ── Exclusión a nivel ARCHIVO ────────────────────────────────────
# Documentos cuyo propósito ES el contexto de cliente: sanearlos línea por línea
# los dejaría en nada. No entran al repo público — el archivo del bloque SESIONES es el
# caso típico: misma categoría, misma regla.
echo "→ Excluyendo documentos inherentemente privados..."
# La lista vive en private-patterns.local.txt (acción `exclude`), NO acá: el
# nombre de archivo delata al cliente, y este script sí se publica.
PATTERNS_LOCAL="$REPO_DIR/scripts/private-patterns.local.txt"
EXCLUDE_INFO="$REPO_DIR/.git/info/exclude"
if [[ -f "$PATTERNS_LOCAL" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    [[ "$line" != *"::exclude" ]] && continue
    pf="${line%%::*}"
    [[ -f "$REPO_DIR/$pf" ]] && rm -f "$REPO_DIR/$pf" && echo "   ✂ excluido: $(basename "$pf")"
    # .git/info/exclude es local y no versionado: ahí sí puede ir el nombre
    grep -qxF "$pf" "$EXCLUDE_INFO" 2>/dev/null || echo "$pf" >> "$EXCLUDE_INFO"
  done < "$PATTERNS_LOCAL"
else
  echo "   ⚠️  sin private-patterns.local.txt — no hay lista de exclusión por archivo"
fi
# Patrones de contexto de proyecto que aparezcan a futuro
find "$REPO_DIR/claude/memory" -name "contexto-proyecto-*.md" -delete 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════
# SANITIZACIÓN POR PATRÓN — corre DESPUÉS de todas las copias
#
# Orden crítico: los `rsync` de helpers y skills son posteriores a las copias
# individuales; si se saneara antes, el rsync sobreescribiría lo saneado y el
# leak volvería en cada sync. Este bloque va al final a propósito.
#
# CLAUDE.md es el archivo que filtró datos de cliente el 2026-07-01 vía el bloque
# SESIONES. La doctrina lo exigía vacío desde entonces, pero nada lo aplicaba: se
# copiaba verbatim. sanitize-memory-agents sólo borra secciones con marker, así
# que las FILAS de tabla con nombres de cliente sobrevivían.
#
# En .md se descarta la línea; en código (.sh/.py) sólo se redacta, para no
# romper heredocs ni dejar sintaxis inválida.
# ══════════════════════════════════════════════════════════════════
echo "→ Sanitizando por patrón (CLAUDE.md, memory, agents, helpers, skills)..."
mapfile -t SANITIZE_TARGETS < <(
  printf '%s\n' "$REPO_DIR/claude/CLAUDE.md"
  find "$REPO_DIR/claude/memory"  -maxdepth 2 -name "*.md" 2>/dev/null
  find "$REPO_DIR/claude/agents"  -maxdepth 2 -name "*.md" 2>/dev/null
  find "$REPO_DIR/claude/commands" -maxdepth 1 -name "*.md" 2>/dev/null
  find "$REPO_DIR/claude/skills"  -name "*.md" 2>/dev/null
  find "$REPO_DIR/claude/helpers" -maxdepth 1 \( -name "*.sh" -o -name "*.py" \) 2>/dev/null
)
bash "$REPO_DIR/scripts/sanitize-private.sh" "${SANITIZE_TARGETS[@]}"

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

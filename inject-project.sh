#!/usr/bin/env bash
# ============================================================
# Helix — Inyectar motor Helix en un proyecto existente
# Uso: bash ~/helix_asisten/inject-project.sh [ruta-proyecto]
# Si no se pasa ruta, usa el directorio actual.
# ============================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$REPO_DIR/helix-engine"
PROJECT_DIR="${1:-$(pwd)}"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "❌ Directorio no existe: $PROJECT_DIR"
  exit 1
fi

echo "🔷 Inyectando Helix en: $PROJECT_DIR"

# ── .mcp.json ───────────────────────────────────────────────
if [[ ! -f "$PROJECT_DIR/.mcp.json" ]]; then
  cp "$ENGINE/.mcp.json" "$PROJECT_DIR/"
  echo "  ✓ .mcp.json creado"
else
  echo "  ⚠️  .mcp.json ya existe — no sobreescrito"
fi

# ── .claude/ ────────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/.claude/memory"

# agents, commands, helpers, skills (sobreescribir OK — son templates)
for dir in agents commands helpers skills; do
  cp -r "$ENGINE/.claude/$dir" "$PROJECT_DIR/.claude/"
done

cp "$ENGINE/.claude/settings.json"  "$PROJECT_DIR/.claude/"
cp "$ENGINE/.claude/statusline.mjs" "$PROJECT_DIR/.claude/" 2>/dev/null || true
cp "$ENGINE/.claude/statusline.sh"  "$PROJECT_DIR/.claude/" 2>/dev/null || true

echo "  ✓ .claude/ inyectado"

# settings.local.json — solo si no existe (tiene permisos acumulados)
if [[ ! -f "$PROJECT_DIR/.claude/settings.local.json" ]]; then
  echo '{"permissions":{"allow":[],"deny":[]}}' > "$PROJECT_DIR/.claude/settings.local.json"
  echo "  ✓ settings.local.json creado (vacío)"
fi

# ── .claude-flow/ ───────────────────────────────────────────
mkdir -p "$PROJECT_DIR/.claude-flow/data" \
         "$PROJECT_DIR/.claude-flow/sessions" \
         "$PROJECT_DIR/.claude-flow/logs" \
         "$PROJECT_DIR/.claude-flow/metrics" \
         "$PROJECT_DIR/.claude-flow/neural"

cp "$ENGINE/.claude-flow/config.yaml"      "$PROJECT_DIR/.claude-flow/"
cp "$ENGINE/.claude-flow/CAPABILITIES.md"  "$PROJECT_DIR/.claude-flow/"

[[ -d "$ENGINE/.claude-flow/security" ]] && \
  cp -r "$ENGINE/.claude-flow/security" "$PROJECT_DIR/.claude-flow/"

echo "  ✓ .claude-flow/ inyectado"

# ── .gitignore — agregar entradas de Helix ──────────────────
GITIGNORE="$PROJECT_DIR/.gitignore"
HELIX_IGNORES=(
  ".claude-flow/data/"
  ".claude-flow/sessions/"
  ".claude-flow/logs/"
  ".claude-flow/neural/"
  ".claude/settings.local.json"
)
for entry in "${HELIX_IGNORES[@]}"; do
  if [[ -f "$GITIGNORE" ]] && grep -qF "$entry" "$GITIGNORE"; then
    true
  else
    echo "$entry" >> "$GITIGNORE"
  fi
done
echo "  ✓ .gitignore actualizado"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Helix engine inyectado en $PROJECT_DIR"
echo ""
echo "   Próximos pasos:"
echo "   1. Declara en tu CLAUDE.md: HELIX_MODE: helix_control_total"
echo "   2. Instala MCPs si no están (ver install.sh)"
echo "   3. Abre Claude Code en el proyecto"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

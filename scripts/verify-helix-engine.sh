#!/usr/bin/env bash
# ============================================================
# Helix — Verificar que el engine está bien inyectado en un proyecto
# Uso: bash ~/helix_asisten/scripts/verify-helix-engine.sh [ruta-proyecto]
# ============================================================
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf "  ✓ %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); printf "  ✗ %s\n" "$1"; }
warn() { printf "  ⚠  %s\n" "$1"; }

echo "╔══════════════════════════════════════════════╗"
echo "║  Helix Engine — Verificación post-inject     ║"
echo "║  Proyecto: $PROJECT_DIR"
echo "╚══════════════════════════════════════════════╝"

echo ""
echo "═══ 1. Archivos críticos ═══"
[[ -f "$PROJECT_DIR/.mcp.json" ]]                          && ok ".mcp.json"              || fail ".mcp.json FALTA"
[[ -f "$PROJECT_DIR/.claude/settings.json" ]]              && ok ".claude/settings.json"  || fail ".claude/settings.json FALTA"
[[ -f "$PROJECT_DIR/.claude-flow/config.yaml" ]]           && ok ".claude-flow/config.yaml" || fail ".claude-flow/config.yaml FALTA"
[[ -f "$PROJECT_DIR/.claude/helpers/hook-handler.cjs" ]]   && ok "hook-handler.cjs"       || fail "hook-handler.cjs FALTA"
[[ -f "$PROJECT_DIR/.claude/helpers/auto-memory-hook.mjs" ]] && ok "auto-memory-hook.mjs" || fail "auto-memory-hook.mjs FALTA"
[[ -f "$PROJECT_DIR/.claude/helpers/router.cjs" ]]         && ok "router.cjs"             || fail "router.cjs FALTA"

echo ""
echo "═══ 2. HELIX_MODE declarado ═══"
if [[ -f "$PROJECT_DIR/CLAUDE.md" ]]; then
  if grep -q "HELIX_MODE:" "$PROJECT_DIR/CLAUDE.md"; then
    MODE=$(grep "HELIX_MODE:" "$PROJECT_DIR/CLAUDE.md" | head -1 | sed 's/.*HELIX_MODE: *//')
    ok "HELIX_MODE: $MODE"
  else
    fail "HELIX_MODE no declarado en CLAUDE.md — Helix correrá en modo minimal"
  fi
else
  fail "CLAUDE.md no existe"
fi

echo ""
echo "═══ 3. Agentes ═══"
AGENT_COUNT=$(find "$PROJECT_DIR/.claude/agents" -name "*.md" 2>/dev/null | wc -l | tr -d '[:space:]')
if [[ "$AGENT_COUNT" -ge 50 ]]; then
  ok "$AGENT_COUNT agentes en .claude/agents/"
elif [[ "$AGENT_COUNT" -gt 0 ]]; then
  warn "$AGENT_COUNT agentes (esperado ≥50 con helix-engine completo)"
  PASS=$((PASS+1))
else
  fail "Sin agentes en .claude/agents/"
fi

echo ""
echo "═══ 4. .gitignore ═══"
if [[ -f "$PROJECT_DIR/.gitignore" ]]; then
  grep -q "claude-flow/data" "$PROJECT_DIR/.gitignore"  && ok ".claude-flow/data/ excluido"   || fail ".claude-flow/data/ NO excluido — riesgo de subir runtime"
  grep -q "settings.local"   "$PROJECT_DIR/.gitignore"  && ok "settings.local.json excluido"  || warn "settings.local.json no en .gitignore"
else
  warn ".gitignore no existe"
fi

echo ""
echo "═══ 5. MCPs ═══"
if command -v claude &>/dev/null; then
  if claude mcp list 2>/dev/null | grep -q "claude-flow"; then
    ok "MCP claude-flow registrado"
  else
    fail "MCP claude-flow NO registrado — ejecutar: claude mcp add claude-flow -- npx -y @claude-flow/cli@3.5.41 mcp start"
  fi
else
  warn "claude CLI no encontrado — verificar MCPs manualmente"
fi

echo ""
echo "═══ 6. Ollama (Capa 0) ═══"
if command -v ollama &>/dev/null; then
  ollama list 2>/dev/null | grep -q "helix-coder" && ok "helix-coder instalado" || warn "helix-coder no instalado (opcional)"
  ollama list 2>/dev/null | grep -q "helix-scout" && ok "helix-scout instalado" || warn "helix-scout no instalado (opcional)"
else
  warn "ollama no instalado — Capa 0 no disponible (opcional)"
fi

echo ""
echo "══════════════════════════════════════════════"
TOTAL=$((PASS+FAIL))
printf "  RESULTADO: Pass:%d  Fail:%d / %d checks\n" "$PASS" "$FAIL" "$TOTAL"
if [[ $FAIL -eq 0 ]]; then
  echo "  ★ Helix engine listo"
else
  echo "  ✗ $FAIL problema(s) crítico(s) — resolver antes de usar"
fi
echo "══════════════════════════════════════════════"
exit $FAIL

#!/usr/bin/env bash
# helix-council-resume.sh
# Verifica el estado del Helix Council y prepara el bootstrap para
# la primera sesión nueva donde los council-* agents son invocables.
#
# Uso: bash helix-council-resume.sh

set -uo pipefail

COUNCIL_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/council"
AGENTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"
LOG_DIR="$COUNCIL_DIR/log"

echo "════════════════════════════════════════════════════════════════"
echo "  Helix Council v1.0 — Status & Resume"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. Verificar artifacts
echo "[1/5] Verificando artifacts..."
ok=0; missing=0
for f in \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/topics/helix-evolution-plan.md" \
  "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/topics/council-design.md" \
  "$COUNCIL_DIR/constitution.md" \
  "$COUNCIL_DIR/scripts/helix-council.sh" \
  "$COUNCIL_DIR/scripts/helix-council-context.sh" \
  "$AGENTS_DIR/council-arbiter.md" \
  "$AGENTS_DIR/council-skeptic.md" \
  "$AGENTS_DIR/council-innovator.md" \
  "$AGENTS_DIR/council-conservative.md" \
  "$AGENTS_DIR/council-synthesizer.md" \
  "$AGENTS_DIR/council-researcher.md" \
  "$AGENTS_DIR/council-devils-advocate.md"
do
  if [[ -f "$f" ]]; then
    ok=$((ok+1))
  else
    echo "  MISSING: $f"
    missing=$((missing+1))
  fi
done
echo "  Artifacts presentes: $ok / $((ok+missing))"
echo ""

# 2. Verificar context files on-demand
echo "[2/5] Verificando context files on-demand..."
ctx_ok=0
for role in arbiter skeptic innovator conservative synthesizer researcher devils-advocate; do
  if [[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/agents/council-$role.md" ]]; then
    ctx_ok=$((ctx_ok+1))
  fi
done
echo "  Context files: $ctx_ok / 7"
echo ""

# 3. Verificar entries en agents-index
echo "[3/5] Verificando entries en agents-index..."
idx_count=$(grep -cE '^\| `council-' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/agents-index.md" 2>/dev/null || echo 0)
echo "  Entries indexadas: $idx_count / 7"
echo ""

# 4. Verificar routing-check exception
echo "[4/5] Verificando bypass del routing-check para council-*..."
if grep -q 'agent.startswith("council-")' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/routing-check-hook.sh" 2>/dev/null; then
  echo "  Bypass: OK"
else
  echo "  Bypass: MISSING (ejecutar fix manual)"
fi
echo ""

# 5. Sesiones council previas
echo "[5/5] Sesiones council registradas..."
session_count=$(ls "$COUNCIL_DIR/context-pack/" 2>/dev/null | wc -l)
echo "  Sesiones en context-pack/: $session_count"
log_count=$(ls "$LOG_DIR/" 2>/dev/null | wc -l)
echo "  Audit logs: $log_count"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "  PRÓXIMOS PASOS (ejecutar en sesión NUEVA de Claude Code)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  1. Verificar que los council-* agents están disponibles:"
echo "     (en Claude principal) preguntá: '¿Existe el agent council-arbiter?'"
echo ""
echo "  2. Si existen → arrancar el council pleno sobre el plan v4:"
echo "     Trigger: 'Deliberar plan de evolución Helix v4'"
echo "     Severity: high"
echo "     Context level: L3 (forense, self-modification)"
echo ""
echo "  3. Comando para preparar la sesión:"
echo "     bash ~/.claude/council/scripts/helix-council.sh prepare \\"
echo "       \"Deliberar plan de evolución Helix v4 (ver topics/helix-evolution-plan.md)\" \\"
echo "       high \\"
echo "       \$HOME/helix_asisten"
echo ""
echo "  4. Después: Claude principal invoca los 7 council-* agents en paralelo,"
echo "     guarda outputs, y corre collect/finalize por rondas."
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Plan persistido en:"
echo "  - ~/.claude/memory/topics/helix-evolution-plan.md"
echo "  - ~/.claude/memory/topics/council-design.md"
echo "  - ~/.claude/council/constitution.md"
echo "════════════════════════════════════════════════════════════════"

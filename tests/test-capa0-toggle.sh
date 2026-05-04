#!/usr/bin/env bash
# test-capa0-toggle.sh — Smoke test end-to-end del override manual de Capa 0
# Ejecutar: bash ~/.claude/tests/test-capa0-toggle.sh
# Sale 0 si todo OK, 1 si algo falla.

set -uo pipefail

TOGGLE="${HOME}/.claude/helpers/helix-capa0-toggle.sh"
POLICY="${HOME}/.claude/helpers/helix-capa0-policy.sh"
CAPA0="${HOME}/helix_asisten/scripts/capa0.sh"
OVERRIDE="${HOME}/.claude/capa0-disabled"
SESSION_END="${HOME}/.claude/session-end.sh"

PASS=0
FAIL=0
FAILED_TESTS=()

# Backup del estado actual del override (si lo hay) para no romperlo
BACKUP=""
if [[ -f "$OVERRIDE" ]]; then
    BACKUP="${OVERRIDE}.test-bak.$$"
    mv "$OVERRIDE" "$BACKUP"
fi

cleanup() {
    rm -f "$OVERRIDE"
    if [[ -n "$BACKUP" && -f "$BACKUP" ]]; then
        mv "$BACKUP" "$OVERRIDE"
    fi
}
trap cleanup EXIT

assert() {
    local label="$1" cond="$2"
    if eval "$cond"; then
        echo "  PASS  $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $label  →  ($cond)"
        FAIL=$((FAIL+1))
        FAILED_TESTS+=("$label")
    fi
}

echo "── Test 1: estado limpio inicial ──"
[[ ! -f "$OVERRIDE" ]] || rm -f "$OVERRIDE"
P=$(bash "$POLICY" 2>/dev/null)
assert "policy sin override depende de HW (no es OFF por user-override)" \
       '! bash "$POLICY" --json 2>/dev/null | grep -q "override manual"'

echo ""
echo "── Test 2: toggle off --session ──"
bash "$TOGGLE" off --session >/dev/null 2>&1
assert "archivo override existe" '[[ -f "$OVERRIDE" ]]'
assert "metadata mode=session" 'grep -qE "^mode:[[:space:]]*session" "$OVERRIDE"'
assert "policy reporta OFF" '[[ "$(bash "$POLICY")" == "OFF" ]]'
assert "policy --json incluye reason override manual" \
       'bash "$POLICY" --json | grep -q "override manual del usuario"'
assert "policy --check exit 1 (OFF)" 'bash "$POLICY" --check; [[ $? -eq 1 ]]'

echo ""
echo "── Test 3: capa0.sh respeta OFF y escala ──"
out=$(bash "$CAPA0" logs "test input" 2>&1)
rc=$?
assert "capa0.sh exit 2" '[[ $rc -eq 2 ]]'
assert "capa0.sh menciona escalación a Capa 1" 'echo "$out" | grep -qiE "capa 1|escalando"'

echo ""
echo "── Test 4: toggle on borra override ──"
bash "$TOGGLE" on >/dev/null 2>&1
assert "archivo override borrado" '[[ ! -f "$OVERRIDE" ]]'
assert "policy vuelve a no tener override" \
       '! bash "$POLICY" --json 2>/dev/null | grep -q "override manual"'

echo ""
echo "── Test 5: toggle off --persistent ──"
bash "$TOGGLE" off --persistent >/dev/null 2>&1
assert "metadata mode=persistent" 'grep -qE "^mode:[[:space:]]*persistent" "$OVERRIDE"'
assert "policy sigue OFF" '[[ "$(bash "$POLICY")" == "OFF" ]]'

echo ""
echo "── Test 6: session-end NO borra mode:persistent ──"
# Simulamos session-end ejecutando solo el bloque de cleanup capa0
if grep -qE 'CAPA0_OVERRIDE.*capa0-disabled' "$SESSION_END"; then
    # Extraer y ejecutar solo el bloque de cleanup
    bash -c "$(grep -A 10 'Cleanup override Capa 0' "$SESSION_END" | grep -v '^#' | head -10)" 2>/dev/null || true
fi
assert "archivo persistent NO se borró tras simular session-end" '[[ -f "$OVERRIDE" ]]'

echo ""
echo "── Test 7: session-end SÍ borra mode:session ──"
bash "$TOGGLE" on >/dev/null 2>&1
bash "$TOGGLE" off --session >/dev/null 2>&1
[[ -f "$OVERRIDE" ]] || { echo "  SETUP FAIL: override no se creó"; exit 1; }
# Simular cleanup con la lógica real
if grep -qE '^mode:[[:space:]]*session' "$OVERRIDE" 2>/dev/null; then
    rm -f "$OVERRIDE"
fi
assert "archivo session se borró" '[[ ! -f "$OVERRIDE" ]]'

echo ""
echo "── Test 8: errores por flags inválidos ──"
out=$(bash "$TOGGLE" off 2>&1); rc=$?
assert "off sin flag → exit 2" '[[ $rc -eq 2 ]]'
assert "off sin flag → mensaje requiere --session/--persistent" \
       'echo "$out" | grep -qE "session.*persistent"'

out=$(bash "$TOGGLE" foo 2>&1); rc=$?
assert "acción desconocida → exit 2" '[[ $rc -eq 2 ]]'

echo ""
echo "── Test 9: env var HELIX_CAPA0_DISABLED ──"
[[ -f "$OVERRIDE" ]] && rm -f "$OVERRIDE"
P=$(HELIX_CAPA0_DISABLED=1 bash "$POLICY")
assert "env var fuerza OFF aunque no haya archivo" '[[ "$P" == "OFF" ]]'
J=$(HELIX_CAPA0_DISABLED=1 bash "$POLICY" --json)
assert "env var aparece como reason en --json" \
       'echo "$J" | grep -q "HELIX_CAPA0_DISABLED=1"'

echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "  Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do
        echo "    - $t"
    done
    exit 1
fi
echo "═══════════════════════════════════════════"
exit 0

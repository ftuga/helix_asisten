#!/usr/bin/env bash
# test-check-prereqs.sh — Smoke test del check-prereqs.sh refactor (FASE 6 OPCIÓN E)
# Estrategia: PATH manipulado con symlinks selectivos para esconder binarios.
# Ejecutar: bash ~/.claude/tests/test-check-prereqs.sh
set -uo pipefail

CHECK="${HOME}/helix_asisten/scripts/check-prereqs.sh"
PASS=0
FAIL=0
FAILED=()

assert() {
    local label="$1" cond="$2"
    if eval "$cond"; then
        echo "  PASS  $label"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $label"
        FAIL=$((FAIL+1))
        FAILED+=("$label")
    fi
}

# ─── Setup PATH controlado ───────────────────────────────────
# Crea dir con symlinks a /usr/bin/* y opcionalmente a ~/.local/bin/*,
# EXCLUYENDO los binarios pasados como args. PATH queda solo con ese dir.
make_test_path() {
    local hide=("$@")
    local td
    td=$(mktemp -d)
    for src in /usr/bin/*; do
        local name
        name=$(basename "$src")
        local skip=0
        for h in "${hide[@]}"; do
            [[ "$name" == "$h" ]] && skip=1 && break
        done
        [[ $skip -eq 1 ]] && continue
        ln -s "$src" "$td/$name" 2>/dev/null
    done
    # Symlink también ~/.local/bin/* excluyendo ocultos
    if [[ -d "$HOME/.local/bin" ]]; then
        for src in "$HOME/.local/bin"/*; do
            [[ -e "$src" ]] || continue
            local name
            name=$(basename "$src")
            local skip=0
            for h in "${hide[@]}"; do
                [[ "$name" == "$h" ]] && skip=1 && break
            done
            [[ $skip -eq 1 ]] && continue
            [[ -e "$td/$name" ]] || ln -s "$src" "$td/$name" 2>/dev/null
        done
    fi
    echo "$td"
}

run_with() {
    local hide_csv="$1"
    IFS=',' read -ra hide <<< "$hide_csv"
    local td
    td=$(make_test_path "${hide[@]}")
    PATH="$td" bash "$CHECK" 2>&1
    local rc=$?
    rm -rf "$td"
    echo "EXIT=$rc"
}

# ─── Test 1: docker oculto ───────────────────────────────────
echo "── Test 1: docker faltante ──"
out=$(run_with "docker")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "docker aparece como FAIL" 'echo "$out" | grep -q "docker no encontrado"'
assert "bloque docker en copy-paste (curl get.docker.com)" \
       'echo "$out" | grep -q "get.docker.com"'

# ─── Test 2: ollama oculto ───────────────────────────────────
echo ""
echo "── Test 2: ollama faltante ──"
out=$(run_with "ollama")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "ollama aparece como FAIL" 'echo "$out" | grep -q "ollama no encontrado"'
assert "bloque ollama en copy-paste (install.sh)" \
       'echo "$out" | grep -q "ollama.com/install.sh"'
assert "modelo nomic-embed-text incluido en bloque" \
       'echo "$out" | grep -q "ollama pull nomic-embed-text"'

# ─── Test 3: docker + ollama ocultos ─────────────────────────
echo ""
echo "── Test 3: docker + ollama faltantes simultáneos ──"
out=$(run_with "docker,ollama")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "ambos bloques aparecen" \
       'echo "$out" | grep -q "get.docker.com" && echo "$out" | grep -q "ollama.com/install.sh"'
assert "no duplica encabezado de copy-paste" \
       '[[ $(echo "$out" | grep -c "copy-paste") -le 1 ]]'

# ─── Test 4: claude CLI oculto ───────────────────────────────
echo ""
echo "── Test 4: claude CLI faltante ──"
out=$(run_with "claude")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "claude aparece como FAIL" 'echo "$out" | grep -q "claude CLI no encontrado"'
assert "bloque claude (npm install -g)" \
       'echo "$out" | grep -q "@anthropic-ai/claude-code"'

# ─── Test 5: zstd oculto → grupo apt ─────────────────────────
echo ""
echo "── Test 5: zstd faltante (grupo apt) ──"
out=$(run_with "zstd")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "zstd aparece como FAIL" 'echo "$out" | grep -q "zstd no encontrado"'
assert "comando apt-get incluye zstd" \
       'echo "$out" | grep -E "apt-get install -y" | grep -q zstd'

# ─── Test 6: múltiples apt deps consolidadas ─────────────────
echo ""
echo "── Test 6: zstd + rsync ocultos → un solo apt-get install ──"
out=$(run_with "zstd,rsync")
apt_lines=$(echo "$out" | grep -cE "^sudo apt-get install" || true)
assert "un solo comando apt-get install" '[[ "$apt_lines" == "1" ]]'
assert "comando incluye zstd Y rsync" \
       'echo "$out" | grep -E "apt-get install -y" | grep -q zstd && echo "$out" | grep -E "apt-get install -y" | grep -q rsync'

# ─── Test 7: solo chromium falta (warn-only) ─────────────────
echo ""
echo "── Test 7: solo chromium falta → exit 0 con WARN ──"
# Estado actual del sistema (sin esconder nada) ya tiene esto
out=$(bash "$CHECK" 2>&1)
rc=$?
assert "exit code 0" '[[ "$rc" == "0" ]]'
assert "WARN chromium aparece" 'echo "$out" | grep -q "Chromium/Chrome no encontrado"'
assert "no aparece bloque copy-paste (sin FAILs)" \
       '! echo "$out" | grep -q "Comandos para instalar"'

# ─── Test 8: numeración correcta del bloque ──────────────────
echo ""
echo "── Test 8: numeración de pasos en el bloque ──"
out=$(run_with "docker,ollama,zstd,claude")
# Esperamos: # 1. apt (zstd), # 2. docker, # 3. ollama, # 4. claude, # 5. modelos
step1=$(echo "$out" | grep -E "^# 1\." | head -1)
step2=$(echo "$out" | grep -E "^# 2\." | head -1)
assert "paso 1 existe" '[[ -n "$step1" ]]'
assert "paso 2 existe" '[[ -n "$step2" ]]'
assert "paso apt antes que docker" \
       'echo "$out" | grep -nE "^# [0-9]+\. (Paquetes apt|Docker)" | sort -k1n | head -1 | grep -q "Paquetes apt"'

# ─── Resumen ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "  Failed:"
    for t in "${FAILED[@]}"; do
        echo "    - $t"
    done
    exit 1
fi
echo "═══════════════════════════════════════════"
exit 0

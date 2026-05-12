#!/usr/bin/env bash
# test-check-prereqs-windows.sh — Smoke test del branch IS_WIN_NATIVE.
# Simula Git Bash en Windows con un shim que reemplaza `uname` por
# `MINGW64_NT-10.0-26200`. Valida que:
#   1. El OS gate no aborta.
#   2. Cuando faltan paquetes, el copy-paste emitido es winget (no apt).
#   3. El mensaje final menciona install_on_windows.ps1.
#
# Ejecutar: bash tests/test-check-prereqs-windows.sh
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$REPO_DIR/scripts/check-prereqs.sh"
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

# Setup PATH con shim de uname → MINGW64, escondiendo binarios opcionales.
make_win_path() {
    local hide=("$@")
    local td
    td=$(mktemp -d)
    # Shim uname (debe aparecer ANTES de /usr/bin en PATH)
    cat > "$td/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) echo "MINGW64_NT-10.0-26200" ;;
  *)  command /usr/bin/uname "$@" ;;
esac
EOF
    chmod +x "$td/uname"
    # Resto de /usr/bin (excluyendo hide)
    for src in /usr/bin/*; do
        local name
        name=$(basename "$src")
        [[ "$name" == "uname" ]] && continue
        local skip=0
        for h in "${hide[@]}"; do
            [[ "$name" == "$h" ]] && skip=1 && break
        done
        [[ $skip -eq 1 ]] && continue
        ln -s "$src" "$td/$name" 2>/dev/null
    done
    if [[ -d "$HOME/.local/bin" ]]; then
        for src in "$HOME/.local/bin"/*; do
            [[ -e "$src" ]] || continue
            local name
            name=$(basename "$src")
            [[ -e "$td/$name" ]] && continue
            local skip=0
            for h in "${hide[@]}"; do
                [[ "$name" == "$h" ]] && skip=1 && break
            done
            [[ $skip -eq 1 ]] && continue
            ln -s "$src" "$td/$name" 2>/dev/null
        done
    fi
    echo "$td"
}

run_win() {
    local hide_csv="$1"
    local hide=()
    [[ -n "$hide_csv" ]] && IFS=',' read -ra hide <<< "$hide_csv"
    local td
    td=$(make_win_path "${hide[@]}")
    PATH="$td" bash "$CHECK" 2>&1
    local rc=$?
    rm -rf "$td"
    echo "EXIT=$rc"
}

# ─── Test 1: OS gate no aborta en MINGW64 ────────────────────
echo "── Test 1: uname=MINGW64 → no aborta en gate OS ──"
out=$(run_win "docker,ollama")
assert "no aparece 'OS no soportado'" '! echo "$out" | grep -q "OS no soportado"'
assert "detecta Windows nativo + Git Bash" \
       'echo "$out" | grep -q "Windows nativo + Git Bash"'

# ─── Test 2: docker faltante → winget no apt ─────────────────
echo ""
echo "── Test 2: docker faltante en Windows → winget Docker.DockerDesktop ──"
out=$(run_win "docker")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "menciona docker no encontrado" 'echo "$out" | grep -q "docker no encontrado"'
assert "copy-paste usa winget Docker.DockerDesktop" \
       'echo "$out" | grep -q "winget install --id Docker.DockerDesktop"'
assert "NO sugiere curl get.docker.com" \
       '! echo "$out" | grep -q "get.docker.com"'
assert "NO sugiere systemctl ni service docker start" \
       '! echo "$out" | grep -qE "systemctl|service docker start"'

# ─── Test 3: ollama faltante → winget Ollama.Ollama ──────────
echo ""
echo "── Test 3: ollama faltante → winget Ollama.Ollama ──"
out=$(run_win "ollama")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "copy-paste usa winget Ollama" \
       'echo "$out" | grep -q "winget install --id Ollama.Ollama"'
assert "NO sugiere ollama.com/install.sh" \
       '! echo "$out" | grep -q "ollama.com/install.sh"'
assert "modelo nomic-embed-text incluido" \
       'echo "$out" | grep -q "ollama pull nomic-embed-text"'

# ─── Test 4: claude CLI faltante ─────────────────────────────
echo ""
echo "── Test 4: claude CLI faltante → npm install -g ──"
out=$(run_win "claude")
rc=$(echo "$out" | tail -1 | sed 's/EXIT=//')
assert "exit code 1" '[[ "$rc" == "1" ]]'
assert "copy-paste menciona @anthropic-ai/claude-code" \
       'echo "$out" | grep -q "@anthropic-ai/claude-code"'

# ─── Test 5: mensaje final menciona instalador correcto ──────
echo ""
echo "── Test 5: mensaje final menciona install_on_windows.ps1 ──"
out=$(run_win "docker")
assert "mensaje final menciona install_on_windows.ps1" \
       'echo "$out" | grep -q "install_on_windows.ps1"'
assert "NO menciona solo 'install_on_wsl.sh' aislado" \
       '! echo "$out" | grep -E "volver a correr install_on_wsl.sh$" >/dev/null'

# ─── Test 6: sin dpkg en Windows ─────────────────────────────
echo ""
echo "── Test 6: dpkg no es chequeado en MINGW ──"
out=$(run_win "dpkg")
assert "no aparece 'dpkg en estado inconsistente'" \
       '! echo "$out" | grep -q "dpkg en estado inconsistente"'

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

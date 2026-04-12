#!/usr/bin/env bash
# session-exit-hook.sh — UserPromptSubmit: detecta "exit" y cierra sesión automáticamente
# Recibe JSON por stdin: { "prompt": "...", "cwd": "..." }
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" python3 - <<'PYEOF'
import os, sys, json, subprocess
from pathlib import Path

payload_str = os.environ.get("HOOK_PAYLOAD", "")
if not payload_str:
    sys.exit(0)

try:
    data = json.loads(payload_str)
except:
    sys.exit(0)

prompt = data.get("prompt", "").strip().lower()

EXIT_TRIGGERS = {
    "exit", "salir", "cerrar sesión", "cierra sesión", "cierra la sesión",
    "fin de sesión", "terminar sesión", "termina la sesión", "bye", "chau",
    "hasta luego", "cerramos", "cerremos", "fin", "done", "nos vemos"
}

# Match exacto o que el prompt solo contenga la trigger (máx 4 palabras)
words = prompt.split()
is_exit = (
    prompt in EXIT_TRIGGERS
    or any(t in prompt for t in EXIT_TRIGGERS)
    and len(words) <= 6
)

if not is_exit:
    sys.exit(0)

# Generar resumen desde git log del día
cwd = data.get("cwd", str(Path.home()))
summary = "Sesión cerrada"
try:
    result = subprocess.run(
        ["git", "log", "--oneline", "--since=today", "--no-walk", "HEAD"],
        cwd=cwd, capture_output=True, text=True, timeout=3
    )
    commits = [l.strip() for l in result.stdout.splitlines() if l.strip()]
    if commits:
        summary = commits[0].split(" ", 1)[-1][:80]
except:
    pass

# Ejecutar session-end.sh
session_end = Path.home() / ".claude/session-end.sh"
if session_end.exists():
    try:
        result = subprocess.run(
            ["bash", str(session_end), summary],
            capture_output=True, text=True, timeout=30
        )
        # Limpiar escape codes ANSI para output limpio
        import re
        output = re.sub(r'\x1b\[[0-9;]*m', '', result.stdout).strip()
        print(output)
    except Exception as e:
        print(f"[session-end error: {e}]")
PYEOF

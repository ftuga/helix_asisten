#!/usr/bin/env bash
# capa0-guard.sh — PreToolUse(Bash/Read): sugiere Capa 0 cuando el input es costoso
# Recibe JSON por stdin con: tool_name, tool_input, cwd
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" python3 <<'PYEOF'
import os, json, sys

payload_str = os.environ.get("HOOK_PAYLOAD", "")
if not payload_str:
    sys.exit(0)

try:
    data = json.loads(payload_str)
except:
    sys.exit(0)

tool_name  = data.get("tool_name", "")
tool_input = data.get("tool_input", {})

# ── Bash: detectar comandos de logs/contenedores ──────────────
if tool_name == "Bash":
    cmd = tool_input.get("command", "").lower()
    triggers = [
        "docker compose logs", "docker logs",
        "journalctl", "tail -f", "tail -n",
        "cat *.log", ".log",
        "dmesg", "kubectl logs",
    ]
    if any(t in cmd for t in triggers):
        print(
            "\n[CAPA-0-SUGERENCIA] Comando produce logs/texto largo — "
            "considerar: bash ~/helix_asisten/scripts/capa0.sh logs \"$(COMANDO)\"\n",
            file=sys.stderr
        )
    sys.exit(0)

# ── Read: detectar archivos grandes ──────────────────────────
if tool_name == "Read":
    from pathlib import Path
    file_path = tool_input.get("file_path", "")
    # Solo verificar si no se especificó limit (lectura completa)
    has_limit = "limit" in tool_input
    if not has_limit and file_path:
        try:
            p = Path(file_path)
            if p.exists() and p.stat().st_size > 0:
                line_count = sum(1 for _ in p.open())
                if line_count > 200:
                    print(
                        f"\n[CAPA-0-SUGERENCIA] {p.name} tiene {line_count} líneas — "
                        f"considerar: bash ~/helix_asisten/scripts/capa0.sh logs \"$(cat {file_path})\"\n",
                        file=sys.stderr
                    )
        except:
            pass
    sys.exit(0)
PYEOF

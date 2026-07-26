#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# session-end-hook.sh — evento SessionEnd: ejecuta session-end.sh SIEMPRE.
#
# Por qué existe (2026-07-26): `session-exit-hook.sh` vive en UserPromptSubmit y
# detecta "exit", pero **`exit` nunca llega como prompt** — Claude Code lo
# intercepta como comando de salida. Por eso "eso es todo helix" cerraba bien
# (es un prompt normal) y `exit` salía sin ejecutar el protocolo.
#
# SessionEnd dispara pase lo que pase: exit, /quit, Ctrl+D o cierre de terminal.
#
# Idempotencia: session-exit-hook.sh y este hook pueden dispararse en la misma
# sesión (el usuario escribe "cerramos" y después sale). Un marcador por
# session_id garantiza que session-end.sh corra UNA vez.
set -uo pipefail

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
PAYLOAD=$(cat 2>/dev/null || echo "{}")

HOOK_PAYLOAD="$PAYLOAD" CONFIG_DIR="$CONFIG_DIR" "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import os, sys, json, subprocess, re
from pathlib import Path

config_dir = Path(os.environ["CONFIG_DIR"])
try:
    data = json.loads(os.environ.get("HOOK_PAYLOAD", "{}"))
except Exception:
    data = {}

session_id = str(data.get("session_id", "")) or "unknown"
reason     = str(data.get("reason", "")) or "session_end"
cwd        = data.get("cwd", str(Path.home()))

# ── Marcador de idempotencia ─────────────────────────────────
marker_dir = config_dir / "cache"
marker_dir.mkdir(parents=True, exist_ok=True)
safe = re.sub(r"[^A-Za-z0-9_.-]", "_", session_id)
marker = marker_dir / f"session-ended-{safe}"
if marker.exists():
    sys.exit(0)

# ── Resumen desde los commits del día ────────────────────────
summary = "Sesión cerrada"
try:
    r = subprocess.run(["git", "log", "--oneline", "--since=today", "--no-walk", "HEAD"],
                       cwd=cwd, capture_output=True, text=True, timeout=3)
    commits = [l.strip() for l in r.stdout.splitlines() if l.strip()]
    if commits:
        summary = commits[0].split(" ", 1)[-1][:80]
except Exception:
    pass

session_end = config_dir / "session-end.sh"
if not session_end.exists():
    sys.exit(0)

try:
    r = subprocess.run(["bash", str(session_end), summary],
                       capture_output=True, text=True, timeout=30)
    marker.write_text(f"{reason}\n")
    # La salida de SessionEnd no se muestra: la sesión ya está terminando.
    # Se deja traza en disco para poder auditar que el protocolo corrió.
    log = config_dir / "memory" / "session-log.txt"
    if log.parent.exists():
        with log.open("a", encoding="utf-8") as f:
            f.write(f"[session-end-hook] reason={reason} session={safe} rc={r.returncode}\n")
except Exception:
    pass
PYEOF
exit 0

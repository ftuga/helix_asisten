#!/usr/bin/env python3
"""frontend-intent-gate-hook.py — gate advisory para edits UI (v1.0)

PreToolUse(Write|Edit|MultiEdit). Always exit 0. NEVER blocks (advisory).

Comportamiento:
  - Detecta file_path con extensión UI (.tsx/.jsx/.css/.scss/.vue/.svelte/.html/.astro).
  - Solo dispara la PRIMERA vez por sesión (flag en session-env/).
  - Emite a stderr el flag [HELIX-FRONTEND-INTENT] que Claude lee y traduce a 2 preguntas
    para el creator: (1) usar experto frontend-developer? (2) brief de referencia?
  - Lista briefs disponibles en ~/.helix/memory/frontend-briefs/

Reversibilidad:
  HELIX_FRONTEND_GATE_ENABLED=0  → exit 0 inmediato
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

UI_EXTENSIONS = {".tsx", ".jsx", ".css", ".scss", ".sass", ".vue", ".svelte", ".html", ".astro"}
BRIEFS_DIR = Path(os.environ.get("HOME", "")) / ".helix/memory/frontend-briefs"
SESSION_ENV_BASE = Path(os.environ.get("HOME", "")) / ".claude/session-env"


def main() -> int:
    if os.environ.get("HELIX_FRONTEND_GATE_ENABLED", "1") == "0":
        return 0

    raw = sys.stdin.read()
    if not raw:
        return 0

    try:
        data = json.loads(raw)
    except Exception:
        return 0

    tool_input = data.get("tool_input") or {}
    file_path = tool_input.get("file_path") or tool_input.get("path") or ""
    if not file_path:
        return 0

    ext = Path(file_path).suffix.lower()
    if ext not in UI_EXTENSIONS:
        return 0

    session_id = os.environ.get("CLAUDE_SESSION_ID", "default")
    flag_dir = SESSION_ENV_BASE / session_id
    flag_path = flag_dir / "frontend-gate-asked"

    if flag_path.exists():
        return 0

    try:
        flag_dir.mkdir(parents=True, exist_ok=True)
        flag_path.touch()
    except Exception:
        return 0

    briefs = []
    if BRIEFS_DIR.is_dir():
        briefs = sorted(p.name for p in BRIEFS_DIR.glob("*.md"))

    msg_lines = [
        f"[HELIX-FRONTEND-INTENT] Primera edición UI de la sesión: {file_path}",
        "",
        "Antes de continuar, preguntá al creator:",
        "  1. ¿Querés que el experto `frontend-developer` haga este trabajo en lugar de edits directos?",
        "     (tiene contexto del stack y aplica patrones del catálogo).",
    ]
    if briefs:
        msg_lines.append("  2. ¿Aplicar brief de referencia? Briefs disponibles:")
        for b in briefs:
            msg_lines.append(f"       - {b}")
    else:
        msg_lines.append("  2. ¿Tenés un proyecto de referencia? (no hay briefs en ~/.helix/memory/frontend-briefs/ aún;")
        msg_lines.append("     se generan con bash ~/.helix/helpers/frontend-brief-gen.sh <path>).")
    msg_lines.append("")
    msg_lines.append("Si el creator no responde, seguí con el flujo normal.")
    msg_lines.append("Deshabilitar este gate: export HELIX_FRONTEND_GATE_ENABLED=0")

    print("\n".join(msg_lines), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

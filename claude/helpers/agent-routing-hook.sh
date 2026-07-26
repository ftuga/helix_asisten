#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# agent-routing-hook.sh — PostToolUse(Agent): captura routing automáticamente
# Recibe JSON por stdin: { tool_input, tool_response, tool_name, cwd, ... }
set -uo pipefail

FEEDBACK="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/routing-feedback.jsonl"
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory"

# Leer payload de stdin (bash lo consume aquí, se pasa a python via env)
PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" "${HELIX_PYTHON:-python3}" - "$FEEDBACK" <<'PYEOF'
import sys, json, os
from datetime import datetime
from pathlib import Path

payload_str = os.environ.get("HOOK_PAYLOAD", "")
if not payload_str:
    sys.exit(0)

try:
    data = json.loads(payload_str)
except:
    sys.exit(0)

tool_input = data.get("tool_input", {})
tool_response = data.get("tool_response", "")
cwd = data.get("cwd", "")

agent = tool_input.get("subagent_type", "general-purpose")
prompt = tool_input.get("prompt", tool_input.get("description", ""))[:80].replace("\n", " ").strip()

# Inferir dominio desde keywords del prompt
DOMAIN_KEYWORDS = {
    "frontend":     ["component", "componente", "react", "ui", "css", "tailwind", "página", "page", "form", "formulario", "tsx", "jsx"],
    "backend":      ["endpoint", "api", "fastapi", "route", "ruta", "handler", "service", "servicio"],
    "database":     ["schema", "migración", "migration", "tabla", "table", "index", "índice", "query", "sql", "model", "modelo"],
    "devops":       ["docker", "deploy", "ci/cd", "nginx", "pipeline", "contenedor", "container", "infra", "kubernetes"],
    "testing":      ["test", "cobertura", "coverage", "pytest", "jest", "e2e", "unitario", "unit"],
    "architecture": ["arquitectura", "architecture", "diseño", "solid", "capas", "layers", "dependencias"],
    "security":     ["auth", "jwt", "permisos", "permission", "rbac", "vulnerabilidad", "vulnerability"],
    "analysis":     ["métrica", "metric", "reporte", "report", "kpi", "dashboard", "tendencia", "trend", "datos"],
    "bug":          ["error", "bug", "excepción", "exception", "crash", "falla", "traceback", "no funciona"],
}
prompt_lower = prompt.lower()
dominio = "general"
for dom, kws in DOMAIN_KEYWORDS.items():
    if any(kw in prompt_lower for kw in kws):
        dominio = dom
        break

# Inferir resultado
resp_str = str(tool_response)
if not resp_str or len(resp_str) < 30:
    resultado = "failed"
elif any(w in resp_str.lower()[:200] for w in ["error", "exception", "failed", "traceback"]):
    resultado = "partial"
else:
    resultado = "success"

# Detectar proyecto desde cwd
project = ""
p = Path(cwd)
home = Path.home()
while p != p.parent and p != home:
    if (p / "CLAUDE.md").exists():
        project = p.name
        break
    p = p.parent

# session_id: sin esto el statusline no puede distinguir MI ventana de otra
# corriendo en paralelo — mostraba los agentes de cualquier sesión de la última hora.
session_id = data.get("session_id", "")

entry = {
    "ts": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "session": session_id,
    "agente": agent,
    "dominio": dominio,
    "tarea": prompt,
    "resultado": resultado,
    "proyecto": project,
}
with open(sys.argv[1], "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")

# Directorio de config activo — NUNCA hardcodear ~/.claude (rompe el árbol vivo tras migrar)
CONFIG_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude")))

# También registrar en skill-usage.jsonl para análisis de uso
usage_log = CONFIG_DIR / "memory/skill-usage.jsonl"
usage_entry = {
    "ts":      entry["ts"],
    "date":    entry["ts"][:10],
    "session": session_id,
    "name":    agent,
    "tipo":    "agent",
    "proyecto": project,
}
with open(usage_log, "a") as f:
    f.write(json.dumps(usage_entry, ensure_ascii=False) + "\n")

# Auto-score de calidad: success=3, partial=2, failed=1
quality_log = CONFIG_DIR / "memory/skill-quality.jsonl"
score_map = {"success": 3, "partial": 2, "failed": 1}
score = score_map.get(resultado, 2)
quality_entry = {
    "ts":      entry["ts"],
    "name":    agent,
    "score":   score,
    "dominio": dominio,
    "razon":   f"auto:{resultado}",
    "proyecto": project,
}
with open(quality_log, "a") as f:
    f.write(json.dumps(quality_entry, ensure_ascii=False) + "\n")
PYEOF

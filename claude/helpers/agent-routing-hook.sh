#!/usr/bin/env bash
# agent-routing-hook.sh — PostToolUse(Agent): captura routing automáticamente
# Recibe JSON por stdin: { tool_input, tool_response, tool_name, cwd, ... }
set -uo pipefail

FEEDBACK="$HOME/.claude/memory/routing-feedback.jsonl"
mkdir -p "$HOME/.claude/memory"

# Leer payload de stdin (bash lo consume aquí, se pasa a python via env)
PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" python3 - "$FEEDBACK" <<'PYEOF'
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

entry = {
    "ts": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "agente": agent,
    "tarea": prompt,
    "resultado": resultado,
    "proyecto": project,
}
with open(sys.argv[1], "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")

# También registrar en skill-usage.jsonl para análisis de uso
usage_log = Path.home() / ".claude/memory/skill-usage.jsonl"
usage_entry = {
    "ts":      entry["ts"],
    "date":    entry["ts"][:10],
    "name":    agent,
    "tipo":    "agent",
    "proyecto": project,
}
with open(usage_log, "a") as f:
    f.write(json.dumps(usage_entry, ensure_ascii=False) + "\n")
PYEOF

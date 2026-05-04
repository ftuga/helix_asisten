#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# mcp-tracker-hook.sh — PostToolUse(mcp__.*): registra uso real de MCPs
# Extrae el nombre del servicio MCP desde tool_name: mcp__context7__... → context7
set -uo pipefail

USAGE_LOG="$HOME/.claude/memory/skill-usage.jsonl"
mkdir -p "$HOME/.claude/memory"

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" "${HELIX_PYTHON:-python3}" - "$USAGE_LOG" <<'PYEOF'
import sys, json, os, re
from datetime import datetime
from pathlib import Path

payload_str = os.environ.get("HOOK_PAYLOAD", "")
if not payload_str:
    sys.exit(0)

try:
    data = json.loads(payload_str)
except:
    sys.exit(0)

tool_name = data.get("tool_name", "")
cwd       = data.get("cwd", "")

# Solo procesar herramientas MCP (mcp__servicio__accion)
if not tool_name.startswith("mcp__"):
    sys.exit(0)

# Extraer nombre del servicio: mcp__context7__get-library-docs → context7
parts = tool_name.split("__")
if len(parts) < 2:
    sys.exit(0)
mcp_service = parts[1]  # context7, claude-flow, sequential-thinking, etc.

# Detectar proyecto desde cwd
project = ""
p = Path(cwd)
home = Path.home()
while p != p.parent and p != home:
    if (p / "CLAUDE.md").exists() and p != Path.home() / ".claude":
        project = p.name
        break
    p = p.parent

entry = {
    "ts":       datetime.now().strftime("%Y-%m-%d %H:%M"),
    "date":     datetime.now().strftime("%Y-%m-%d"),
    "name":     mcp_service,
    "tipo":     "mcp",
    "tool":     tool_name,        # tool completo para debugging
    "proyecto": project,
}

with open(sys.argv[1], "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
PYEOF

#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# skill-tracker-hook.sh — PostToolUse(Skill): registra uso real de skills
# Recibe JSON por stdin: { tool_input: { skill, args }, tool_name, cwd, ... }
set -uo pipefail

USAGE_LOG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/skill-usage.jsonl"
mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory"

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" "${HELIX_PYTHON:-python3}" - "$USAGE_LOG" <<'PYEOF'
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
cwd        = data.get("cwd", "")

skill_name = tool_input.get("skill", "")
if not skill_name:
    sys.exit(0)

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
    "ts":      datetime.now().strftime("%Y-%m-%d %H:%M"),
    "date":    datetime.now().strftime("%Y-%m-%d"),
    "name":    skill_name,
    "tipo":    "skill",
    "proyecto": project,
}

with open(sys.argv[1], "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
PYEOF

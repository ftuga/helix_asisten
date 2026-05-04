#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-agents-audit.sh — Diff entre ~/.claude/agents/*.md y agents-index.md
# Detecta orphans en ambos lados.
# Output JSON. Útil al inicio de sesión o como hook.

set -euo pipefail

AGENTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"
INDEX_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/agents-index.md"

"${HELIX_PYTHON:-python3}" <<'PYEOF'
import json, os, re
from pathlib import Path

agents_dir = Path(os.path.expanduser("~/.claude/agents"))
index_file = Path(os.path.expanduser("~/.claude/memory/agents-index.md"))

# Lado A: archivos en filesystem (excluyendo INDEX, README, etc. que no son agentes)
EXCLUDE_NAMES = {"INDEX", "README", "CHANGELOG", "TODO"}
fs_agents = set()
if agents_dir.is_dir():
    for f in agents_dir.glob("*.md"):
        if f.stem in EXCLUDE_NAMES:
            continue
        fs_agents.add(f.stem)

# Lado B: entries en agents-index.md
# Format: | `agent-name` | trigger description |
indexed_agents = set()
indexed_with_context = {}  # agent → context file path
context_dir = Path(os.path.expanduser("~/.claude/memory/agents"))
fs_contexts = set()
if context_dir.is_dir():
    for f in context_dir.glob("*.md"):
        fs_contexts.add(f.stem)

if index_file.is_file():
    text = index_file.read_text()
    # Match: | `agent-name` | ... |
    for match in re.finditer(r"\|\s*`([a-zA-Z0-9_-]+)`\s*\|", text):
        indexed_agents.add(match.group(1))

# Detectar context files con frontmatter `status: preserved` — son intencionales
preserved_contexts = set()
for f in fs_contexts:
    cf = context_dir / f"{f}.md"
    try:
        # Solo lee primeras líneas (frontmatter)
        head = cf.read_text()[:500]
        if re.search(r"^status:\s*preserved\b", head, re.MULTILINE):
            preserved_contexts.add(f)
    except Exception:
        pass

# Comparaciones
in_fs_not_indexed = sorted(fs_agents - indexed_agents)  # agente sin entry en índice
indexed_not_in_fs = sorted(indexed_agents - fs_agents)  # entry sin archivo (huérfano)
indexed_without_context = sorted(indexed_agents - fs_contexts)  # sin context file
context_without_agent_all = fs_contexts - fs_agents  # context huérfano (raw)
context_without_agent = sorted(context_without_agent_all - preserved_contexts)  # solo accidentales
context_preserved = sorted(context_without_agent_all & preserved_contexts)  # intencionales

verdict_problems = []
if indexed_not_in_fs:
    verdict_problems.append(f"{len(indexed_not_in_fs)} agente(s) en índice sin archivo")
if in_fs_not_indexed:
    verdict_problems.append(f"{len(in_fs_not_indexed)} archivo(s) sin entry en índice")
if context_without_agent:
    verdict_problems.append(f"{len(context_without_agent)} context file(s) huérfano(s) accidental(es)")

result = {
    "agents_in_filesystem": len(fs_agents),
    "agents_in_index": len(indexed_agents),
    "context_files": len(fs_contexts),
    "orphans": {
        "indexed_without_file": indexed_not_in_fs,
        "file_without_index_entry": in_fs_not_indexed,
        "indexed_without_context": indexed_without_context,
        "context_without_agent": context_without_agent,
        "context_preserved": context_preserved,
    },
    "status": "OK" if not verdict_problems else "DRIFT",
    "problems": verdict_problems,
}
print(json.dumps(result, indent=2))
PYEOF

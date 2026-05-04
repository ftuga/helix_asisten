#!/usr/bin/env bash
[[ -f "$HOME/.claude/helix-python.conf" ]] && source "$HOME/.claude/helix-python.conf"
# helix-claude-md-prune.sh — Auto-archiva evoluciones >14d cuando CLAUDE.md > umbral
# Idempotente. Diseñado para correr en cron, session-start o post-evolve.
# Uso: bash helix-claude-md-prune.sh [--dry-run] [--threshold N]

set -euo pipefail

CLAUDE_MD="$HOME/.claude/CLAUDE.md"
HISTORY="$HOME/.claude/memory/topics/evolution-history.md"
THRESHOLD=340     # si >= esto, podar
DAYS_KEEP=14      # días a mantener en CLAUDE.md
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --days)      DAYS_KEEP="$2"; shift 2 ;;
        *)           shift ;;
    esac
done

[[ -f "$CLAUDE_MD" ]] || { echo "CLAUDE.md no existe"; exit 0; }

LINES=$(wc -l < "$CLAUDE_MD")

if (( LINES < THRESHOLD )); then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "{\"status\":\"ok\",\"lines\":$LINES,\"threshold\":$THRESHOLD,\"action\":\"none\"}"
    fi
    exit 0
fi

# Conversión bash→python para boolean
if [[ "$DRY_RUN" == "true" ]]; then DRY_RUN_PY="True"; else DRY_RUN_PY="False"; fi

# Archivar evoluciones con fecha >$DAYS_KEEP días
"${HELIX_PYTHON:-python3}" <<PYEOF
import re, sys, os, json
from datetime import datetime, timedelta
from pathlib import Path

claude_md = Path("$CLAUDE_MD")
history = Path("$HISTORY")
days_keep = $DAYS_KEEP
dry_run = $DRY_RUN_PY

content = claude_md.read_text()
cutoff = datetime.now() - timedelta(days=days_keep)

# Localizar bloque EVOLUTION_LOG
m = re.search(r"<!-- EVOLUTION_LOG_START -->(.*?)<!-- EVOLUTION_LOG_END -->", content, re.DOTALL)
if not m:
    print(json.dumps({"status": "no_log_block"}))
    sys.exit(0)

log_block = m.group(1)
header_lines = []
data_lines = []
for line in log_block.splitlines():
    if line.startswith("|") and re.search(r"\| (\d{4}-\d{2}-\d{2})", line):
        data_lines.append(line)
    else:
        header_lines.append(line)

# Separar viejas/nuevas
to_archive = []
to_keep = []
for line in data_lines:
    md = re.search(r"\| (\d{4}-\d{2}-\d{2}) \|", line)
    if md:
        try:
            d = datetime.strptime(md.group(1), "%Y-%m-%d")
            if d < cutoff:
                to_archive.append(line)
            else:
                to_keep.append(line)
        except Exception:
            to_keep.append(line)
    else:
        to_keep.append(line)

if not to_archive:
    print(json.dumps({"status": "nothing_to_archive", "lines": $LINES}))
    sys.exit(0)

if dry_run:
    print(json.dumps({
        "status": "would_archive",
        "lines_now": $LINES,
        "to_archive_count": len(to_archive),
        "would_save_lines": len(to_archive),
        "lines_after": $LINES - len(to_archive),
    }, indent=2))
    sys.exit(0)

# Append a history file
history.parent.mkdir(parents=True, exist_ok=True)
with history.open("a") as f:
    f.write(f"\n## Archivado {datetime.now().strftime('%Y-%m-%d %H:%M')} — Auto-prune (CLAUDE.md > {$THRESHOLD} líneas)\n")
    for line in to_archive:
        f.write(line + "\n")

# Reescribir CLAUDE.md sin las líneas archivadas
new_log_block = "\n".join(header_lines + to_keep)
new_content = content[:m.start(1)] + new_log_block + content[m.end(1):]
claude_md.write_text(new_content)

new_lines = len(new_content.splitlines())
print(json.dumps({
    "status": "archived",
    "lines_before": $LINES,
    "lines_after": new_lines,
    "lines_saved": $LINES - new_lines,
    "archived_count": len(to_archive),
    "archived_to": str(history),
}, indent=2))
PYEOF

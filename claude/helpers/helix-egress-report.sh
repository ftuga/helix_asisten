#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-egress-report.sh — SEC2 monthly report
# Aggregates ~/.claude/memory/egress-audit.jsonl into a markdown summary.
# Default scope: current calendar month (UTC). Overridable via --month YYYY-MM.
#
# Usage:
#   helix-egress-report.sh                       # current month, stdout
#   helix-egress-report.sh --month 2026-04       # specific month
#   helix-egress-report.sh --out FILE            # write to FILE instead of stdout
#   helix-egress-report.sh --month 2026-04 --out ~/.claude/memory/topics/egress-audit-2026-04.md
#
# Per D2.1 (META2/META3 on-demand only): NO cron, NO autoschedule.
# Invoked manually by creator.

set -uo pipefail

LOG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/egress-audit.jsonl"
[[ ! -s "$LOG" ]] && { echo "(no egress audit log: $LOG)"; exit 0; }

MONTH=$(date -u '+%Y-%m')
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --month) MONTH="$2"; shift 2 ;;
    --out)   OUT="$2";   shift 2 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1"; exit 2 ;;
  esac
done

# Validate month format
if ! [[ "$MONTH" =~ ^[0-9]{4}-[0-9]{2}$ ]]; then
  echo "invalid --month (expected YYYY-MM): $MONTH" >&2
  exit 2
fi

REPORT=$(MONTH="$MONTH" LOG="$LOG" "${HELIX_PYTHON:-python3}" <<'PYEOF'
import json, os, sys, collections, datetime as dt

month = os.environ['MONTH']
log = os.environ['LOG']

entries = []
with open(log, 'r', encoding='utf-8') as f:
    for ln in f:
        ln = ln.strip()
        if not ln: continue
        try:
            e = json.loads(ln)
        except Exception:
            continue
        if (e.get('ts','')[:7]) == month:
            entries.append(e)

n = len(entries)
days = collections.Counter()
domain_counts = collections.Counter()
tool_counts = collections.Counter()
new_domains = []
mcp_servers = collections.Counter()

for e in entries:
    ts = e.get('ts','')
    day = ts[:10]
    days[day] += 1
    domain_counts[e.get('domain','?')] += 1
    tool_counts[e.get('tool','?')] += 1
    if e.get('new_domain'):
        new_domains.append((ts, e.get('domain',''), e.get('tool','')))
    d = e.get('domain','')
    if d.startswith('mcp:'):
        mcp_servers[d[4:]] += 1

avg_per_day = (n / max(1, len(days))) if days else 0

print(f"# SEC2 helix-egress-audit — report {month}")
print()
print(f"- Total egress calls: **{n}**")
print(f"- Active days: {len(days)}")
print(f"- Avg per active day: **{avg_per_day:.1f}**  (criterio M2-style: <50/d normal use)")
print(f"- New domains first-seen: {len(new_domains)}")
print()

print("## Top 10 domains")
print()
print("| domain | calls |")
print("|---|---|")
for d, c in domain_counts.most_common(10):
    print(f"| `{d}` | {c} |")
print()

print("## Tool breakdown")
print()
print("| tool | calls |")
print("|---|---|")
for t, c in tool_counts.most_common():
    print(f"| `{t}` | {c} |")
print()

if mcp_servers:
    print("## MCP servers")
    print()
    print("| server | calls |")
    print("|---|---|")
    for s, c in mcp_servers.most_common():
        print(f"| `{s}` | {c} |")
    print()

print("## New domains first-seen this month")
print()
if not new_domains:
    print("(none)")
else:
    print("| ts | domain | tool |")
    print("|---|---|---|")
    for ts, d, t in new_domains[:50]:
        print(f"| {ts} | `{d}` | `{t}` |")
    if len(new_domains) > 50:
        print(f"\n... ({len(new_domains) - 50} more)")
print()

print("## Daily volume")
print()
if not days:
    print("(no data)")
else:
    print("| day | count |")
    print("|---|---|")
    for d in sorted(days.keys()):
        bar = "█" * min(40, days[d])
        print(f"| {d} | {days[d]} {bar} |")
print()

PYEOF
)

if [[ -n "$OUT" ]]; then
  mkdir -p "$(dirname "$OUT")"
  printf '%s\n' "$REPORT" > "$OUT"
  echo "report written → $OUT"
else
  printf '%s\n' "$REPORT"
fi

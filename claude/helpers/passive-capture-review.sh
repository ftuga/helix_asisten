#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# passive-capture-review.sh — M2 review tool
# Lists pending captures and lets the creator approve/reject explicitly.
# NEVER auto-classifies. Each entry requires explicit action.
#
# Usage:
#   passive-capture-review.sh list                     # show pending entries with indices
#   passive-capture-review.sh approve <idx|id>         # move to approved
#   passive-capture-review.sh reject <idx|id>          # move to rejected
#   passive-capture-review.sh approve-all              # bulk approve (explicit human action)
#   passive-capture-review.sh reject-all               # bulk reject (explicit human action)
#   passive-capture-review.sh stats                    # precision (≥40%) + noise (≤40%) rates
#   passive-capture-review.sh count                    # number pending
#   passive-capture-review.sh purge-approved-older N   # housekeeping: drop approved older than N days

set -uo pipefail

PENDING="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/passive-captures-pending.jsonl"
APPROVED="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/passive-captures-approved.jsonl"
REJECTED="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/passive-captures-rejected.jsonl"
LOCK="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/.passive-captures.lock"

mkdir -p "$(dirname "$PENDING")"
touch "$PENDING" "$APPROVED" "$REJECTED"

CMD="${1:-list}"
ARG="${2:-}"

case "$CMD" in
  count)
    wc -l < "$PENDING" | tr -d ' '
    ;;

  list)
    if [[ ! -s "$PENDING" ]]; then
      echo "(no pending captures)"
      exit 0
    fi
    "${HELIX_PYTHON:-python3}" - "$PENDING" <<'PYEOF'
import json, sys, os
HOME = os.path.expanduser('~/.claude/')
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    lines = [l.rstrip() for l in f if l.strip()]
print(f"{len(lines)} pending captures:\n")
for i, line in enumerate(lines, 1):
    try:
        e = json.loads(line)
    except Exception:
        continue
    short_file = e['file'].replace(HOME, '~/.claude/')
    hits = ','.join(e.get('matchers_hit', []))
    print(f"[{i}] {e.get('ts','?')[:19]} {e.get('tool','?')}")
    print(f"    file: {short_file}")
    print(f"    score: {e.get('score','?')} | hits: {hits}")
    print(f"    snippet: {(e.get('snippet','') or '')[:140]}")
    print(f"    id: {e.get('id','?')}")
    print()
PYEOF
    ;;

  approve|reject)
    [[ -z "$ARG" ]] && { echo "usage: $0 $CMD <idx|id>"; exit 2; }
    DEST="$APPROVED"
    [[ "$CMD" == "reject" ]] && DEST="$REJECTED"
    {
      command -v flock >/dev/null && flock -w 2 9
      "${HELIX_PYTHON:-python3}" - "$PENDING" "$DEST" "$ARG" <<'PYEOF'
import json, sys, os
pending_path, dest_path, key = sys.argv[1], sys.argv[2], sys.argv[3]
with open(pending_path, 'r', encoding='utf-8') as f:
    lines = [l for l in f if l.strip()]
matched_idx = None
if key.isdigit():
    i = int(key) - 1
    if 0 <= i < len(lines):
        matched_idx = i
else:
    for i, ln in enumerate(lines):
        try:
            if json.loads(ln).get('id') == key:
                matched_idx = i
                break
        except Exception:
            continue
if matched_idx is None:
    print(f"not found: {key}")
    sys.exit(3)
moved = lines[matched_idx]
remaining = lines[:matched_idx] + lines[matched_idx+1:]
with open(pending_path, 'w', encoding='utf-8') as f:
    f.writelines(remaining)
with open(dest_path, 'a', encoding='utf-8') as f:
    f.write(moved)
e = json.loads(moved)
verb = "APPROVED" if dest_path.endswith('approved.jsonl') else "REJECTED"
print(f"{verb}: {e.get('id','?')} → {e.get('file','?')}")
PYEOF
    } 9> "$LOCK"
    ;;

  approve-all|reject-all)
    DEST="$APPROVED"
    [[ "$CMD" == "reject-all" ]] && DEST="$REJECTED"
    {
      command -v flock >/dev/null && flock -w 2 9
      if [[ -s "$PENDING" ]]; then
        cat "$PENDING" >> "$DEST"
        N=$(wc -l < "$PENDING" | tr -d ' ')
        > "$PENDING"
        verb="APPROVED"
        [[ "$CMD" == "reject-all" ]] && verb="REJECTED"
        echo "$verb: $N entries"
      else
        echo "(no pending)"
      fi
    } 9> "$LOCK"
    ;;

  stats)
    A=$(wc -l < "$APPROVED" | tr -d ' ')
    R=$(wc -l < "$REJECTED" | tr -d ' ')
    P=$(wc -l < "$PENDING" | tr -d ' ')
    TOTAL_REVIEWED=$((A + R))
    if (( TOTAL_REVIEWED == 0 )); then
      echo "no reviewed entries yet (pending=$P)"
      exit 0
    fi
    "${HELIX_PYTHON:-python3}" - "$A" "$R" "$P" <<'PYEOF'
import sys
a, r, p = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
total = a + r
precision = 100.0 * a / total
noise = 100.0 * r / total
print(f"approved: {a}  rejected: {r}  pending: {p}")
print(f"precision (approved/reviewed):  {precision:5.1f}%   target ≥40%   {'PASS' if precision >= 40 else 'FAIL'}")
print(f"noise     (rejected/reviewed):  {noise:5.1f}%   target ≤40%   {'PASS' if noise <= 40 else 'FAIL'}")
PYEOF
    ;;

  purge-approved-older)
    [[ -z "$ARG" ]] && { echo "usage: $0 $CMD <days>"; exit 2; }
    {
      command -v flock >/dev/null && flock -w 2 9
      "${HELIX_PYTHON:-python3}" - "$APPROVED" "$ARG" <<'PYEOF'
import json, sys, time
path, days = sys.argv[1], int(sys.argv[2])
cutoff = time.time() - days * 86400
kept = []
dropped = 0
with open(path, 'r', encoding='utf-8') as f:
    for ln in f:
        if not ln.strip(): continue
        try:
            ts = time.mktime(time.strptime(json.loads(ln).get('ts',''), '%Y-%m-%dT%H:%M:%SZ'))
        except Exception:
            kept.append(ln); continue
        if ts >= cutoff:
            kept.append(ln)
        else:
            dropped += 1
with open(path, 'w', encoding='utf-8') as f:
    f.writelines(kept)
print(f"kept: {len(kept)}  dropped: {dropped}")
PYEOF
    } 9> "$LOCK"
    ;;

  *)
    cat <<EOF
M2 helix-passive-capture review

usage:
  $0 list                       # show pending entries with indices
  $0 count                      # number pending
  $0 approve <idx|id>           # approve one entry
  $0 reject <idx|id>            # reject one entry
  $0 approve-all                # bulk approve pending (explicit creator action)
  $0 reject-all                 # bulk reject pending
  $0 stats                      # precision/noise vs M2 thresholds
  $0 purge-approved-older <N>   # housekeeping
EOF
    exit 2
    ;;
esac

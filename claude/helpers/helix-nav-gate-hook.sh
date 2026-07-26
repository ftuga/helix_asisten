#!/usr/bin/env bash
# helix-nav-gate-hook.sh — PreToolUse(WebFetch|WebSearch)
# Routes risky navigation through helix-nav (the quarantine pipeline).
#
# HELIX_NAV_ENFORCE modes (env wins over ~/.helix/config/helix-nav.conf):
#   advisory (default) : WebFetch to a first-seen domain -> stderr suggestion, allow
#   strict             : WebFetch to a first-seen domain -> exit 2 (block, use helix-nav)
#   off                : inert
# WebSearch is never blocked (snippets are covered post-hoc by L1 injection-detector).
set -uo pipefail
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && \
  source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"

CONF="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/config/helix-nav.conf"
MODE="${HELIX_NAV_ENFORCE:-}"
if [[ -z "$MODE" && -f "$CONF" ]]; then
  # Strip inline comments + whitespace + quotes so `strict # note` parses as strict (L-4).
  MODE=$(grep -E '^HELIX_NAV_ENFORCE=' "$CONF" 2>/dev/null | tail -1 | cut -d= -f2 | sed 's/#.*//' | tr -d '[:space:]"')
fi
MODE="${MODE:-advisory}"
# Reject unrecognized modes -> fail SAFE to advisory (never silently to off).
case "$MODE" in
  advisory|strict|off) ;;
  *) echo "[HELIX-NAV] unrecognized HELIX_NAV_ENFORCE='$MODE' — using advisory" >&2; MODE="advisory" ;;
esac
[[ "$MODE" == "off" ]] && exit 0

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

# ACE lesson (evolution #7): payload goes through env, NEVER interpolated into -c source.
HOOK_PAYLOAD="$PAYLOAD" HOOK_MODE="$MODE" \
  "${HELIX_PYTHON:-python3}" - <<'PYEOF'
import json, os, sys
from pathlib import Path
from urllib.parse import urlparse

raw = os.environ.get("HOOK_PAYLOAD", "")
mode = os.environ.get("HOOK_MODE", "advisory")
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

if (data.get("tool_name") or "") != "WebFetch":
    sys.exit(0)
url = (data.get("tool_input") or {}).get("url") or ""
host = (urlparse(url).hostname or "").lower()
if not host:
    sys.exit(0)

known_file = Path(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude"))) / "memory/egress-known-domains.txt"
known = set()
try:
    for line in known_file.read_text(encoding="utf-8").splitlines():
        line = line.strip().lower()
        if line and not line.startswith("#"):
            known.add(line)
except OSError:
    pass

for k in known:
    if host == k or host.endswith("." + k):
        sys.exit(0)  # known domain -> silent allow

nav = os.path.expanduser("~/helix_asisten/scripts/helix-nav.sh")
if mode == "strict":
    print(
        f"[HELIX-NAV] BLOCKED: first-seen domain '{host}' (HELIX_NAV_ENFORCE=strict).\n"
        f"Fetch it through the quarantine pipeline instead:\n"
        f"  bash {nav} \"{url}\"\n"
        f"(raw content never enters context; injection patterns are redacted pre-context)",
        file=sys.stderr,
    )
    sys.exit(2)

print(
    f"[HELIX-NAV] first-seen domain '{host}' — consider the quarantine pipeline:\n"
    f"  bash {nav} \"{url}\"",
    file=sys.stderr,
)
sys.exit(0)
PYEOF

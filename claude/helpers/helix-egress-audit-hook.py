#!/usr/bin/env python3
"""helix-egress-audit-hook.py — SEC2 helix-egress-audit

PostToolUse(WebFetch|WebSearch|mcp__.*). Always exit 0. Never blocks.

Complementa (NO duplica):
  - network-egress-hook.sh   PreToolUse(Bash)  — blocks curl/ssh outside allowlist
  - injection-detector-hook.sh PostToolUse(WebFetch|WebSearch|Read) — alerts injection patterns

Cubre el gap: audit log estructurado de TODO egress nativo (WebFetch/WebSearch/MCP),
con alert solo sobre dominios NUEVOS (first-seen) y sanitización del payload.

Schema (JSONL en ~/.claude/memory/egress-audit.jsonl):
  {ts, tool, domain, path_short, source, query_sanitized, new_domain}

Sanitización:
  - drop query strings con tokens (regex: api_key, token, password, secret)
  - drop body/payload completo
  - path truncado a 50 chars
  - query truncada a 80 chars con tokens redacted

Threshold alerts:
  - first-seen domain → stderr alert + auto-add to known-domains.txt (cuenta una sola vez por sesión)
  - volume spike (≥20 egress mismo dominio en 5min) → stderr alert
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
LOG = HOME / ".claude/memory/egress-audit.jsonl"
KNOWN = HOME / ".claude/memory/egress-known-domains.txt"
LOCK = HOME / ".claude/memory/.egress-audit.lock"

SECRET_PARAM_RE = re.compile(
    r"(api[_-]?key|token|password|secret|auth|bearer|session|sid|jwt)=([^&\s]+)",
    re.IGNORECASE,
)
SPIKE_WINDOW_S = 300       # 5 min
SPIKE_THRESHOLD = 20

DEFAULT_KNOWN = """\
# Helix egress known-domains (SEC2). Each line is one domain (subdomain match exact).
# Lines starting with # are comments. Domains here do not raise first-seen alerts.
api.anthropic.com
docs.anthropic.com
console.anthropic.com
github.com
api.github.com
raw.githubusercontent.com
pypi.org
files.pythonhosted.org
registry.npmjs.org
context7.com
"""


def _ensure_known() -> set[str]:
    if not KNOWN.exists():
        KNOWN.parent.mkdir(parents=True, exist_ok=True)
        KNOWN.write_text(DEFAULT_KNOWN, encoding="utf-8")
    out: set[str] = set()
    for line in KNOWN.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line.lower())
    return out


def _domain_from(payload_input: dict, tool_name: str) -> tuple[str, str, str]:
    """Returns (domain, path_short, source_field). All best-effort."""
    url = payload_input.get("url") or ""
    if url:
        try:
            u = urlparse(url)
            host = (u.hostname or "").lower()
            path = (u.path or "")[:50]
            return host, path, "url"
        except Exception:
            return "", "", "url"
    query = payload_input.get("query") or ""
    if query:
        return "websearch", "", "query"
    if tool_name.startswith("mcp__"):
        # mcp__server__method — derive virtual domain
        parts = tool_name.split("__", 2)
        srv = parts[1] if len(parts) >= 2 else "unknown"
        method = parts[2] if len(parts) >= 3 else ""
        return f"mcp:{srv}", method[:50], "mcp"
    target = payload_input.get("target") or payload_input.get("file_path") or ""
    return "", str(target)[:50], "target"


def _sanitize_query(q: str) -> str:
    if not q:
        return ""
    q = SECRET_PARAM_RE.sub(r"\1=[REDACTED]", q)
    return q[:80]


def _is_new_domain(domain: str, known: set[str]) -> bool:
    if not domain:
        return False
    if domain.startswith("mcp:") or domain == "websearch":
        return False
    for k in known:
        if domain == k or domain.endswith("." + k):
            return False
    return True


def _tail_recent_for_domain(domain: str) -> int:
    if not LOG.exists() or not domain:
        return 0
    cutoff = time.time() - SPIKE_WINDOW_S
    count = 0
    try:
        with LOG.open("rb") as f:
            try:
                f.seek(0, os.SEEK_END)
                size = f.tell()
                f.seek(max(0, size - 64 * 1024))
                tail = f.read().decode("utf-8", errors="ignore")
            except Exception:
                return 0
        for ln in tail.splitlines():
            if not ln.strip():
                continue
            try:
                e = json.loads(ln)
            except Exception:
                continue
            if e.get("domain") != domain:
                continue
            ts_iso = e.get("ts", "")
            try:
                ts_epoch = time.mktime(time.strptime(ts_iso, "%Y-%m-%dT%H:%M:%SZ"))
            except Exception:
                continue
            if ts_epoch >= cutoff:
                count += 1
    except Exception:
        return 0
    return count


def _append_known(domain: str) -> None:
    if not domain or domain.startswith("mcp:") or domain == "websearch":
        return
    try:
        with KNOWN.open("a", encoding="utf-8") as f:
            f.write(f"{domain}\n")
    except Exception:
        pass


def main() -> int:
    try:
        raw = sys.stdin.read() or "{}"
        data = json.loads(raw)
    except Exception:
        return 0

    tool_name = data.get("tool_name") or data.get("tool") or ""
    if not tool_name:
        return 0
    if not (tool_name in ("WebFetch", "WebSearch") or tool_name.startswith("mcp__")):
        return 0

    payload_input = data.get("tool_input") or {}
    domain, path_short, source = _domain_from(payload_input, tool_name)

    raw_query = (
        payload_input.get("query")
        or (urlparse(payload_input.get("url") or "").query if payload_input.get("url") else "")
        or ""
    )
    query_sanitized = _sanitize_query(raw_query)

    known = _ensure_known()
    new_domain = _is_new_domain(domain, known)

    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tool": tool_name,
        "domain": domain,
        "path_short": path_short,
        "source": source,
        "query_sanitized": query_sanitized,
        "new_domain": new_domain,
    }

    LOG.parent.mkdir(parents=True, exist_ok=True)
    try:
        import fcntl
        with LOG.open("a", encoding="utf-8") as f:
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            except Exception:
                pass
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        try:
            with LOG.open("a", encoding="utf-8") as f:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception:
            return 0

    if new_domain:
        _append_known(domain)
        print(
            f"[SEC2] new egress domain: {domain}  ({tool_name})\n"
            f"       added to {KNOWN}",
            file=sys.stderr,
        )

    if domain and not new_domain:
        recent = _tail_recent_for_domain(domain)
        if recent >= SPIKE_THRESHOLD:
            print(
                f"[SEC2] egress volume spike: {recent} calls to {domain} in {SPIKE_WINDOW_S//60}min",
                file=sys.stderr,
            )

    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""passive-capture-hook.py — M2 helix-passive-capture

PostToolUse(Write|Edit|MultiEdit). Always exit 0. Never blocks.

Filter contract (≥THRESHOLD matches required to capture, default 2):

  Group A — Path matchers (peso 1)
    A1  ~/.claude/CLAUDE.md
    A2  ~/.claude/memory/topics/*.md
    A3  ~/.claude/memory/agents/*.md
    A4  ~/.claude/memory/agents-index.md
    A5  */.claude/memory/helix-*.md  (proyecto)
    A6  ~/.claude/council/*

  Group B — Content keyword matchers (peso 1)
    B1  decidimos/decisión:
    B2  cementado/cementing
    B3  razón:/motivo:/porque
    B4  vamos con/elegido/preferido
    B5  DEFER/BLOQUEADO/RECHAZADO/APROBADO/ESCALATED
    B6  TRANCH/FASE [0-9]
    B7  council/creator/gate B[0-9]
    B8  audit log/inmutable/chmod 400

  Group C — Tool matcher (peso 1)
    C1  tool == Edit|Write|MultiEdit (always present)

Skiplist (auto-skip):
  passive-captures-*.jsonl, helix-bitacora*.md,
  evolution-log.txt, session-log.txt, /dist/, /node_modules/, /__pycache__/, /.git/

Reads JSON payload from stdin, writes JSONL entry to passive-captures-pending.jsonl.
"""

import json
import os
import re
import sys
import time
import secrets

THRESHOLD = int(os.environ.get("HELIX_M2_THRESHOLD", "2"))
HOME = os.environ.get("HOME", os.path.expanduser("~"))
PENDING = os.path.join(HOME, ".claude/memory/passive-captures-pending.jsonl")
LOCK = os.path.join(HOME, ".claude/memory/.passive-captures.lock")

PATH_MATCHERS = [
    ("A1", lambda p: p == os.path.join(HOME, ".claude/CLAUDE.md")),
    ("A2", lambda p: p.startswith(os.path.join(HOME, ".claude/memory/topics/")) and p.endswith(".md")),
    ("A3", lambda p: p.startswith(os.path.join(HOME, ".claude/memory/agents/")) and p.endswith(".md")),
    ("A4", lambda p: p == os.path.join(HOME, ".claude/memory/agents-index.md")),
    ("A5", lambda p: "/.claude/memory/helix-" in p and p.endswith(".md")),
    ("A6", lambda p: p.startswith(os.path.join(HOME, ".claude/council/"))),
]

KW_PATTERNS = [
    ("B1", re.compile(r"decidim(os|o)|decidido|decisi[oó]n:|decision:", re.IGNORECASE)),
    ("B2", re.compile(r"cementad[ao]s?|cementing", re.IGNORECASE)),
    ("B3", re.compile(r"raz[oó]n:|motivo:|\bporque\b", re.IGNORECASE)),
    ("B4", re.compile(r"vamos con|elegido|preferido", re.IGNORECASE)),
    ("B5", re.compile(r"DEFER|BLOQUEADO|RECHAZADO|APROBADO|ESCALATED")),
    ("B6", re.compile(r"TRANCH|FASE [0-9]")),
    ("B7", re.compile(r"council|creator|gate B[0-9]", re.IGNORECASE)),
    ("B8", re.compile(r"audit log|inmutable|chmod 400", re.IGNORECASE)),
]

SKIP_SUBSTRINGS = (
    "passive-captures-",
    "helix-bitacora",
    "evolution-log.txt",
    "session-log.txt",
    "/dist/",
    "/node_modules/",
    "/__pycache__/",
    "/.git/",
)


def main() -> int:
    try:
        raw = sys.stdin.read() or "{}"
        payload = json.loads(raw)
    except Exception:
        return 0

    tool = payload.get("tool_name") or payload.get("tool") or ""
    ti = payload.get("tool_input") or {}
    file_path = ti.get("file_path") or ""
    if not file_path:
        return 0

    # Skiplist
    for s in SKIP_SUBSTRINGS:
        if s in file_path:
            return 0

    score = 0
    hits: list[str] = []

    # Group A
    for label, fn in PATH_MATCHERS:
        if fn(file_path):
            score += 1
            hits.append(label)
            break  # paths are mutually exclusive

    # Group C
    if tool in ("Edit", "Write", "MultiEdit"):
        score += 1
        hits.append("C1")

    # Group B (content) — bound to first 4KB to cap latency
    blob = ti.get("new_string") or ti.get("content") or ""
    if isinstance(blob, list):
        blob = " ".join(str(x) for x in blob)
    blob = blob[:4096] if blob else ""

    if blob:
        for label, pat in KW_PATTERNS:
            if pat.search(blob):
                score += 1
                hits.append(label)

    if score < THRESHOLD:
        return 0

    # Snippet: prefer first line containing a keyword, fallback to first non-empty
    snippet = ""
    if blob:
        for line in blob.splitlines():
            line = line.strip()
            if not line:
                continue
            if any(pat.search(line) for _, pat in KW_PATTERNS):
                snippet = line[:200]
                break
        if not snippet:
            for line in blob.splitlines():
                line = line.strip()
                if line:
                    snippet = line[:200]
                    break

    entry = {
        "id": f"{time.strftime('%Y%m%dT%H%M%SZ', time.gmtime())}-{secrets.token_hex(4)}",
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tool": tool,
        "file": file_path,
        "matchers_hit": hits,
        "score": score,
        "threshold": THRESHOLD,
        "snippet": snippet,
        "session": time.strftime("%Y%m%d-%H%M%S"),
    }

    os.makedirs(os.path.dirname(PENDING), exist_ok=True)
    line = json.dumps(entry, ensure_ascii=False) + "\n"

    # Append; flock if available
    try:
        import fcntl
        with open(PENDING, "a", encoding="utf-8") as f:
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            except Exception:
                pass
            f.write(line)
    except Exception:
        try:
            with open(PENDING, "a", encoding="utf-8") as f:
                f.write(line)
        except Exception:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())

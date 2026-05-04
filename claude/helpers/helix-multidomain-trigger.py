#!/usr/bin/env python3
"""helix-multidomain-trigger.py — D1' multi-domain advisory (TRANCH 1 closure)

PreToolUse(Agent). Always exit 0. NEVER blocks (advisory only).

Closes the TRANCH 1 caveat from plan v4 D1':
  "discontinuar Ruflo APROBADO con prerequisito:
   diseñar trigger Capa 2 propio antes de cementar uso"

Detects multi-domain intent in an `Agent` tool prompt. If ≥2 domains
match keyword groups, emits a stderr advisory suggesting Capa 2 propia
(swarm minimalista) instead of multiple parallel Agent tool calls
(antipattern from evolution #58: invisible in swarm panel).

Advisory mode in v1.0 — does NOT enforce. Future versions can escalate
to enforcement if metrics confirm low false-positive rate.

Reversibility:
  HELIX_D1_TRIGGER_ENABLED=0     disables hook entirely
  HELIX_D1_THRESHOLD=N           min domains to trigger (default 2)

Audit:
  ~/.claude/memory/d1-multidomain-detections.jsonl
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
LOG = HOME / ".claude/memory/d1-multidomain-detections.jsonl"

ENABLED = os.environ.get("HELIX_D1_TRIGGER_ENABLED", "1") != "0"
THRESHOLD = int(os.environ.get("HELIX_D1_THRESHOLD", "2"))

# ─────────────────────────────────────────────────────────────────────────────
# DOMAIN_KEYWORDS — static (anti-poisoning, parallel to M1 CS1 / R1)
# Each domain has a list of patterns. Match is case-insensitive whole-word.
# ─────────────────────────────────────────────────────────────────────────────
DOMAIN_KEYWORDS: dict[str, list[str]] = {
    "backend": [
        r"\bendpoint\b", r"\bapi\b", r"\bfastapi\b", r"\bflask\b", r"\bexpress\b",
        r"\brouter\b", r"\bmiddleware\b", r"\basync\b", r"\bawait\b", r"\bORM\b",
        r"\bsqlalchemy\b", r"\bpydantic\b",
    ],
    "frontend": [
        r"\bcomponente\b", r"\bcomponent\b", r"\breact\b", r"\bvue\b",
        r"\bsvelte\b", r"\btsx\b", r"\bjsx\b", r"\btailwind\b", r"\bnext\.?js\b",
        r"\buseState\b", r"\buseEffect\b",
    ],
    "db": [
        r"\bquery\b", r"\bsql\b", r"\bpostgres\b", r"\bmysql\b", r"\bschema\b",
        r"\bmigration\b", r"\btabla\b", r"\bíndice\b", r"\bindex\b", r"\bjoin\b",
        r"\bselect\b", r"\bcrear\s+tabla\b", r"\balter\s+table\b",
    ],
    "security": [
        r"\bauth(entication|orization|n|z)?\b", r"\bowasp\b", r"\bjwt\b",
        r"\boauth\b", r"\bvulnerab", r"\binjection\b", r"\bxss\b", r"\bcsrf\b",
        r"\brbac\b", r"\bcorrupcion\b", r"\bRCE\b", r"\bsanitiz",
    ],
    "infra": [
        r"\bdocker\b", r"\bci/cd\b", r"\bkubernetes\b", r"\bk8s\b",
        r"\bterraform\b", r"\bdeploy\b", r"\bcompose\b", r"\bnginx\b",
        r"\bgithub\s+actions\b", r"\bjenkins\b",
    ],
    "testing": [
        r"\btest\b", r"\bpytest\b", r"\bjest\b", r"\bspec\b", r"\bfixture\b",
        r"\bcoverage\b", r"\bmock\b", r"\bcasos\s+de\s+prueba\b",
        r"\bhappy\s+path\b",
    ],
    "debug": [
        r"\berror\b", r"\bbug\b", r"\bcrash\b", r"\bstacktrace\b",
        r"\bexception\b", r"\bfix\b", r"\barreglar\b", r"\btraceback\b",
        r"\broot\s+cause\b",
    ],
    "ui": [
        r"\bdiseño\b", r"\bdesign\b", r"\bUX\b", r"\baccesib", r"\baccessib",
        r"\bbreakpoint\b", r"\bresponsive\b", r"\bmobile\s*-?\s*first\b",
        r"\bfigma\b",
    ],
    "performance": [
        r"\boptimizar\b", r"\boptimize\b", r"\bperformance\b", r"\bp99\b",
        r"\blatency\b", r"\bbottleneck\b", r"\bprofil(e|ing)\b",
        r"\bcache\b", r"\bmemoiz",
    ],
    "data": [
        r"\bcsv\b", r"\bpandas\b", r"\betl\b", r"\bairflow\b", r"\bdag\b",
        r"\bfeature\s+engineering\b", r"\bdataset\b", r"\bjupyter\b",
    ],
    "mlops": [
        r"\bmlflow\b", r"\bmodel\s+registry\b", r"\bs3\b", r"\bminio\b",
        r"\bartifact\b", r"\btraining\s+pipeline\b",
    ],
}

COMPILED = {
    dom: [re.compile(p, re.IGNORECASE) for p in pats]
    for dom, pats in DOMAIN_KEYWORDS.items()
}


def detect_domains(text: str) -> list[str]:
    if not text:
        return []
    found: set[str] = set()
    for dom, pats in COMPILED.items():
        for p in pats:
            if p.search(text):
                found.add(dom)
                break
    return sorted(found)


def _log(entry: dict) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    try:
        with LOG.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        pass


def main() -> int:
    if not ENABLED:
        return 0

    try:
        raw = sys.stdin.read() or "{}"
        data = json.loads(raw)
    except Exception:
        return 0

    tool_name = data.get("tool_name") or data.get("tool") or ""
    if tool_name != "Agent":
        return 0

    ti = data.get("tool_input") or {}
    description = ti.get("description") or ""
    prompt = ti.get("prompt") or ""
    subagent = ti.get("subagent_type") or ""
    full_text = f"{description}\n{prompt}".strip()

    if not full_text:
        return 0

    # Truncate for performance — bound text size
    full_text = full_text[:4000]

    domains = detect_domains(full_text)
    if len(domains) < THRESHOLD:
        return 0

    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "subagent_type": subagent,
        "description": description[:120],
        "domains_detected": domains,
        "domain_count": len(domains),
        "advised": True,
    }
    _log(entry)

    domains_str = ", ".join(domains)
    print(
        f"[D1' multi-domain] Agent prompt touches {len(domains)} dominios: {domains_str}\n"
        f"   sub-agent: {subagent or '(unset)'}\n"
        f"   → Considera Capa 2 (swarm propio minimalista) en lugar de un solo Agent tool\n"
        f"     o múltiples Agent en paralelo (antipattern evolution #58 — invisible en swarm panel).\n"
        f"   → Override: HELIX_D1_TRIGGER_ENABLED=0",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

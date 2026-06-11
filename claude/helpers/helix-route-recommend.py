#!/usr/bin/env python3
"""helix-route-recommend.py — R1 model advisor (read-only)

Recommends a model per task domain based on the static `DOMAIN_RECOS` mapping
in `helix-route-cost-audit.py`. **Advisor only**: never modifies settings or
runtime state. Claude Code is single-model in current runtime; the creator
decides manually whether to switch.

Modes:
  recommend <domain>            print model + reason for a domain
  by-agent <agent>              same, looked up via AGENT_TO_DOMAIN
  list-domains                  show all known domains with reco
  current                       print current Claude Code model from settings.json
  compare <agent_a> <agent_b>   recommend per agent (useful when picking)

Override / kill switch:
  HELIX_FORCE_MODEL=<model>     overrides any recommendation (returns force)
  HELIX_R1_ENABLED=0            disables R1; returns conservative default
                                (claude-sonnet-4-6) and a clear notice

Audit:
  Each invocation logs to ~/.claude/memory/r1-recommend-log.jsonl with
  {ts, mode, input, output_model, reason, override_active}.

Reversibility:
  - Set HELIX_R1_ENABLED=0 → effectively disabled, no state to clean up.
  - The advisor never writes to settings.json. Removing this script removes R1.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
# Respect CLAUDE_CONFIG_DIR (Helix migration to ~/.helix/). Falls back to ~/.claude.
CONFIG_DIR = Path(os.environ.get("CLAUDE_CONFIG_DIR", str(HOME / ".claude")))
LOG = CONFIG_DIR / "memory/r1-recommend-log.jsonl"
SETTINGS_JSON = CONFIG_DIR / "settings.json"

# Import the static maps from the audit script (single source of truth)
sys.path.insert(0, str(CONFIG_DIR / "helpers"))
try:
    from importlib import import_module
    _audit = import_module("helix-route-cost-audit".replace("-", "_"))
except Exception:
    # File has hyphens — load via spec
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "helix_route_cost_audit",
        CONFIG_DIR / "helpers/helix-route-cost-audit.py",
    )
    _audit = importlib.util.module_from_spec(spec)  # type: ignore
    spec.loader.exec_module(_audit)  # type: ignore

AGENT_TO_DOMAIN = _audit.AGENT_TO_DOMAIN
DOMAIN_RECOS = _audit.DOMAIN_RECOS
_domain_of = _audit._domain_of

DEFAULT_FALLBACK = "claude-sonnet-4-6"


def _r1_enabled() -> bool:
    return os.environ.get("HELIX_R1_ENABLED", "1") != "0"


def _force_model() -> str | None:
    v = os.environ.get("HELIX_FORCE_MODEL", "").strip()
    return v or None


def _log(entry: dict) -> None:
    LOG.parent.mkdir(parents=True, exist_ok=True)
    try:
        with LOG.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception:
        pass


def _resolve(domain: str) -> tuple[str, str, str]:
    """Returns (model, reason, source) where source ∈ {force, disabled, recos, fallback}."""
    forced = _force_model()
    if forced:
        return forced, f"HELIX_FORCE_MODEL={forced} active", "force"
    if not _r1_enabled():
        return DEFAULT_FALLBACK, "R1 disabled (HELIX_R1_ENABLED=0) — fallback", "disabled"
    if domain in DOMAIN_RECOS:
        m, r = DOMAIN_RECOS[domain]
        return m, r, "recos"
    return DEFAULT_FALLBACK, f"domain '{domain}' not in DOMAIN_RECOS — fallback", "fallback"


def cmd_recommend(args: argparse.Namespace) -> int:
    model, reason, source = _resolve(args.domain)
    out = {"domain": args.domain, "model": model, "reason": reason, "source": source}
    print(json.dumps(out, ensure_ascii=False, indent=2))
    _log({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
          "mode": "recommend", "input": args.domain,
          "output_model": model, "reason": reason, "source": source})
    return 0


def cmd_by_agent(args: argparse.Namespace) -> int:
    domain = _domain_of(args.agent)
    model, reason, source = _resolve(domain)
    out = {"agent": args.agent, "domain": domain, "model": model, "reason": reason, "source": source}
    print(json.dumps(out, ensure_ascii=False, indent=2))
    _log({"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
          "mode": "by-agent", "input": args.agent,
          "output_model": model, "reason": reason, "source": source})
    return 0


def cmd_list_domains(_: argparse.Namespace) -> int:
    print(f"R1 enabled: {_r1_enabled()}  force_model: {_force_model() or '(none)'}\n")
    for dom in sorted(DOMAIN_RECOS.keys()):
        model, reason, source = _resolve(dom)
        print(f"  {dom:18s} → {model:22s} [{source}]")
    return 0


def cmd_current(_: argparse.Namespace) -> int:
    if not SETTINGS_JSON.exists():
        print("(no settings.json)")
        return 1
    try:
        s = json.loads(SETTINGS_JSON.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"(could not parse settings.json: {e})")
        return 1
    cur = s.get("model", "(unset — Claude Code default)")
    print(f"current Claude Code model: {cur}")
    return 0


def cmd_compare(args: argparse.Namespace) -> int:
    rows = []
    for agent in (args.agent_a, args.agent_b):
        domain = _domain_of(agent)
        model, reason, source = _resolve(domain)
        rows.append({"agent": agent, "domain": domain, "model": model,
                     "source": source, "reason": reason})
    print(json.dumps(rows, ensure_ascii=False, indent=2))
    if rows[0]["model"] != rows[1]["model"]:
        print(f"\n→ Diferent models recommended ({rows[0]['model']} vs {rows[1]['model']}). "
              f"Si la sesión los usa juntos, considerar OPUS para alcanzar ambos dominios.",
              file=sys.stderr)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="helix-route-recommend")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_r = sub.add_parser("recommend", help="recommend by domain")
    p_r.add_argument("domain")
    p_r.set_defaults(func=cmd_recommend)
    p_a = sub.add_parser("by-agent", help="recommend by agent name")
    p_a.add_argument("agent")
    p_a.set_defaults(func=cmd_by_agent)
    p_l = sub.add_parser("list-domains", help="list all known domains with recos")
    p_l.set_defaults(func=cmd_list_domains)
    p_c = sub.add_parser("current", help="current Claude Code model from settings")
    p_c.set_defaults(func=cmd_current)
    p_cmp = sub.add_parser("compare", help="recommend for two agents")
    p_cmp.add_argument("agent_a")
    p_cmp.add_argument("agent_b")
    p_cmp.set_defaults(func=cmd_compare)
    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

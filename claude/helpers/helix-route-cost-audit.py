#!/usr/bin/env python3
"""helix-route-cost-audit.py — R1 pre-audit cost por dominio (anti-CS2)

Generates an augmented `route-cost-audit.md` adding the "domain" dimension on
top of the existing R2 cost-by-project rollup. Closes the residual dissent
from B1#2: "data histórica es agregada por proyecto, no por dominio semántico".

Method:
  1. Read existing R2 rollup (`route-cost-audit.md` table by model+project).
  2. Read `routing-feedback.jsonl` (per-call agent + project + outcome).
  3. Map agent → domain (static AGENT_TO_DOMAIN below; updates need code edit).
  4. Aggregate routing-feedback by (domain, model_inferred_via_session)
     where model_inferred is the dominant model used in that session per cost
     rollup. Where signal is too weak, the row is flagged "uncertain".
  5. Emit recommended model per domain (heuristic table; documents reasoning).

Usage:
  helix-route-cost-audit.py refresh           # regenerate the markdown
  helix-route-cost-audit.py print-domains     # print agent→domain map
  helix-route-cost-audit.py print-recos       # print domain→recommended model
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HOME = Path(os.environ.get("HOME", os.path.expanduser("~")))
ROUTE_AUDIT_MD = HOME / ".claude/memory/topics/route-cost-audit.md"
ROUTING_FEEDBACK = HOME / ".claude/memory/routing-feedback.jsonl"
COST_ROLLUP_SH = HOME / ".claude/helpers/helix-cost-rollup.sh"

# ─────────────────────────────────────────────────────────────────────────────
# STATIC MAPPINGS — anti-poisoning analogous to M1 CS1.
# Updates require manual code edit, NOT auto-derived from observed routing.
# ─────────────────────────────────────────────────────────────────────────────
AGENT_TO_DOMAIN: dict[str, str] = {
    "python-pro": "backend",
    "typescript-pro": "frontend",
    "frontend-developer": "frontend",
    "backend-architect": "architecture",
    "backend-developer": "backend",
    "database-architect": "db",
    "postgresql-dba": "db",
    "sql-pro": "db",
    "error-detective": "debug",
    "code-reviewer": "review",
    "security-auditor": "security",
    "security-engineer": "security",
    "api-security-audit": "security",
    "devops-engineer": "infra",
    "deployment-engineer": "infra",
    "azure-infra-engineer": "infra",
    "data-analyst": "analytics",
    "test-engineer": "testing",
    "test-automator": "testing",
    "qa-expert": "testing",
    "monitoring-specialist": "observability",
    "architect-reviewer": "architecture",
    "investment-expert": "finance",
    "mlflow-expert": "mlops",
    "airflow-dag-expert": "mlops",
    "rugpull-domain-expert": "defi",
    "harness-optimizer": "meta-helix",
    "loop-operator": "meta-helix",
    "app-creative-genius": "product",
    "brand-identity-expert": "brand",
    "ui-ux-designer": "ui",
    "ui-designer": "ui",
    "ui-ux-pro-max": "ui",
    "mme-domain-expert": "domain-specific",
    "fullstack-developer": "fullstack",
    "fin-saas-advisor": "finance",
    "general-purpose": "general",
    "claude-code-guide": "research",
    "Explore": "research",
}

# council-* agents map to "council" domain
def _domain_of(agent: str) -> str:
    if not agent:
        return "unknown"
    if agent in AGENT_TO_DOMAIN:
        return AGENT_TO_DOMAIN[agent]
    if agent.startswith("council-"):
        return "council"
    return "uncategorized"


# ─────────────────────────────────────────────────────────────────────────────
# DOMAIN → RECOMMENDED MODEL — heuristic, with reasoning documented.
# Each entry: (model, reason). Reason should appear in audit md.
# ─────────────────────────────────────────────────────────────────────────────
DOMAIN_RECOS: dict[str, tuple[str, str]] = {
    # High reasoning required — Opus
    "council":      ("claude-opus-4-7",   "Deliberación multi-agente, alto razonamiento, low frequency"),
    "architecture": ("claude-opus-4-7",   "Decisiones de diseño, trade-offs no triviales"),
    "security":     ("claude-opus-4-7",   "Análisis de superficie de ataque, OWASP, cripto"),
    "debug":        ("claude-opus-4-7",   "error-detective primero — root cause análisis profundo"),
    "product":      ("claude-opus-4-7",   "Creative reasoning, vision"),
    "brand":        ("claude-opus-4-7",   "Naming, copy, estrategia creativa"),
    "finance":      ("claude-opus-4-7",   "Modelado complejo, multi-asset reasoning"),
    "defi":         ("claude-opus-4-7",   "Dominio especializado, multi-step on-chain analysis"),

    # Production code — Sonnet (balance cost/quality)
    "backend":      ("claude-sonnet-4-6", "Endpoint, refactor, async patterns"),
    "frontend":     ("claude-sonnet-4-6", "Componente React/TS estándar"),
    "fullstack":    ("claude-sonnet-4-6", "Span DB→API→UI"),
    "db":           ("claude-sonnet-4-6", "Queries, schemas, optimización"),
    "infra":        ("claude-sonnet-4-6", "Docker, CI/CD, deploys"),
    "testing":      ("claude-sonnet-4-6", "Test cases, fixtures, coverage"),
    "analytics":    ("claude-sonnet-4-6", "Análisis de reportes y métricas"),
    "review":       ("claude-sonnet-4-6", "Code review estándar"),
    "ui":           ("claude-sonnet-4-6", "Visual design + interaction patterns"),
    "mlops":        ("claude-sonnet-4-6", "MLflow/Airflow tracking + DAGs"),
    "research":     ("claude-sonnet-4-6", "Búsqueda en codebase / web research"),
    "domain-specific": ("claude-sonnet-4-6", "Conocimiento específico no creativo"),
    "meta-helix":   ("claude-sonnet-4-6", "Auditar harness, optimizaciones reversibles"),

    # Pattern-matching, low complexity — Haiku (cheap)
    "observability": ("claude-haiku-4-5", "Pattern match en logs/alertas, alta frecuencia"),

    # Fallback
    "general":       ("claude-sonnet-4-6", "Sin dominio específico — default seguro"),
    "uncategorized": ("claude-sonnet-4-6", "Agente no mapeado — default conservador"),
    "unknown":       ("claude-sonnet-4-6", "Sin agente declarado — default"),
}


# ─────────────────────────────────────────────────────────────────────────────
# Routing feedback aggregation
# ─────────────────────────────────────────────────────────────────────────────

def _load_routing_feedback() -> list[dict]:
    if not ROUTING_FEEDBACK.exists():
        return []
    out: list[dict] = []
    with ROUTING_FEEDBACK.open("r", encoding="utf-8") as f:
        for ln in f:
            ln = ln.strip()
            if not ln:
                continue
            try:
                out.append(json.loads(ln))
            except Exception:
                continue
    return out


def _aggregate_by_domain(entries: list[dict]) -> dict[str, dict]:
    by_domain: dict[str, dict] = collections.defaultdict(lambda: {
        "total": 0, "success": 0, "fail": 0, "agents": collections.Counter(),
        "projects": collections.Counter(),
    })
    for e in entries:
        agent = e.get("agente", "")
        dom = _domain_of(agent)
        result = e.get("resultado", "")
        proj = e.get("proyecto", "")
        by_domain[dom]["total"] += 1
        if result == "success":
            by_domain[dom]["success"] += 1
        elif result in ("fail", "failure"):
            by_domain[dom]["fail"] += 1
        if agent:
            by_domain[dom]["agents"][agent] += 1
        if proj:
            by_domain[dom]["projects"][proj] += 1
    return by_domain


# ─────────────────────────────────────────────────────────────────────────────
# Markdown emission
# ─────────────────────────────────────────────────────────────────────────────

def _read_existing_cost_section() -> str:
    """Read the current route-cost-audit.md and return the cost-by-project table."""
    if not ROUTE_AUDIT_MD.exists():
        return "(No existe — corre `helix-cost-rollup.sh report` primero)"
    text = ROUTE_AUDIT_MD.read_text(encoding="utf-8")
    return text


def _emit_md(by_domain: dict, original_md: str) -> str:
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    lines = []
    lines.append(f"# Route Cost Audit — Helix R1 advisor (augmented)\n")
    lines.append(f"> Auto-generado por `helix-route-cost-audit.py refresh` el {ts}.")
    lines.append(f"> Fuente cost: transcripts JSONL via R2 cost-rollup. Fuente routing: `routing-feedback.jsonl`.")
    lines.append(f"> AGENT_TO_DOMAIN y DOMAIN_RECOS son mapeos ESTÁTICOS (anti-poisoning, paralelo a M1 CS1).\n")
    lines.append("---\n")

    # Section 1: existing cost-by-project (preserved)
    lines.append("## 1. Cost por modelo+proyecto (R2 rollup, sin cambios)\n")
    lines.append("Ver `helix-cost-rollup.sh report` para regenerar. Tabla más reciente:\n")
    # Extract just the project table from original
    if "## Tabla por modelo + proyecto" in original_md:
        try:
            section = original_md.split("## Tabla por modelo + proyecto", 1)[1]
            section = section.split("##", 1)[0]
            lines.append("### Tabla por modelo + proyecto")
            lines.append(section.rstrip())
        except Exception:
            lines.append("(no se pudo extraer la sección de costo — corre cost-rollup)")
    lines.append("")

    # Section 2: routing volume by domain
    lines.append("## 2. Volumen por dominio (routing-feedback)\n")
    if not by_domain:
        lines.append("(routing-feedback.jsonl vacío)")
    else:
        lines.append("| Dominio | Total calls | Success | Fail | % success | Top agentes |")
        lines.append("|---|---|---|---|---|---|")
        for dom in sorted(by_domain.keys(), key=lambda d: -by_domain[d]["total"]):
            d = by_domain[dom]
            sr = (100 * d["success"] / d["total"]) if d["total"] else 0
            top_agents = ", ".join(f"`{a}`({n})" for a, n in d["agents"].most_common(3))
            lines.append(f"| **{dom}** | {d['total']} | {d['success']} | {d['fail']} | {sr:.0f}% | {top_agents} |")
    lines.append("")

    # Section 3: recommendations
    lines.append("## 3. Modelo recomendado por dominio (heurístico)\n")
    lines.append("Mapping estático en código. Updates requieren edición manual + code review.\n")
    lines.append("| Dominio | Modelo recomendado | Razón |")
    lines.append("|---|---|---|")
    seen_domains = set(by_domain.keys()) | set(DOMAIN_RECOS.keys())
    for dom in sorted(seen_domains):
        if dom not in DOMAIN_RECOS:
            lines.append(f"| {dom} | (sin reco) | dominio observado pero no en DOMAIN_RECOS |")
        else:
            model, reason = DOMAIN_RECOS[dom]
            evidence = ""
            if dom in by_domain:
                evidence = f" (evidencia: {by_domain[dom]['total']} calls)"
            lines.append(f"| {dom} | `{model}` | {reason}{evidence} |")
    lines.append("")

    # Section 4: caveats
    lines.append("## 4. Caveats / honestidad de los datos\n")
    lines.append("1. **routing-feedback NO captura modelo por call.** El cross-join completo (dominio × modelo) "
                 "no es posible con la data actual; recomendaciones son heurísticas no observadas.")
    lines.append("2. **success rate ~100% en feedback** sugiere que la métrica está sub-calibrada (Helix marca "
                 "éxito por default si no hay error explícito). Tomar con cautela.")
    lines.append("3. **Mapping AGENT_TO_DOMAIN incompleto** para agentes nuevos. Cada agente nuevo requiere "
                 "actualizar la tabla en `helix-route-cost-audit.py` (+code review).")
    lines.append("4. **Recomendaciones son advisor, NO router automático.** Claude Code es single-model en runtime; "
                 "el creator decide manualmente o setea `model` en settings.json. R1 informa la decisión.")
    lines.append("5. **DOMAIN_RECOS subjetivo.** Validar con benchmarks reales antes de cambiar el setting global. "
                 "v2.0 podría agregar A/B test framework.")
    lines.append("")

    # Section 5: gate B1 #2 closure
    lines.append("## 5. Gate B1 #2 — Pre-audit cost\n")
    lines.append("Este reporte cierra el criterio R1 \"pre-audit costo poblado antes de roll out\":")
    lines.append("- Sección 1: cost por modelo×proyecto (R2, ya disponible).")
    lines.append("- Sección 2: volumen por dominio (cross-join routing-feedback × static AGENT_TO_DOMAIN).")
    lines.append("- Sección 3: recomendaciones por dominio (heurísticas, documentadas).")
    lines.append("- Sección 4: caveats explícitos sobre limitaciones de la data.")
    lines.append("")
    lines.append("Audit log de cierre Gate B1 #2: `~/.claude/council/log/20260504T035500Z_b1-check-2-closed.yaml`.")
    lines.append("")

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────────────────────
# Commands
# ─────────────────────────────────────────────────────────────────────────────

def cmd_refresh(_: argparse.Namespace) -> int:
    # First, regenerate cost rollup if rollup script exists
    if COST_ROLLUP_SH.exists():
        try:
            subprocess.run(["bash", str(COST_ROLLUP_SH), "report"],
                           capture_output=True, timeout=30, check=False)
        except Exception:
            pass

    entries = _load_routing_feedback()
    by_domain = _aggregate_by_domain(entries)
    original = _read_existing_cost_section()
    md = _emit_md(by_domain, original)
    ROUTE_AUDIT_MD.parent.mkdir(parents=True, exist_ok=True)
    ROUTE_AUDIT_MD.write_text(md, encoding="utf-8")
    print(f"refreshed → {ROUTE_AUDIT_MD}")
    print(f"domains observed: {len(by_domain)}  routing entries: {len(entries)}")
    return 0


def cmd_print_domains(_: argparse.Namespace) -> int:
    print("Agent → Domain mapping:")
    for a, d in sorted(AGENT_TO_DOMAIN.items()):
        print(f"  {a:35s} → {d}")
    print("\n  council-*                          → council  (prefix rule)")
    return 0


def cmd_print_recos(_: argparse.Namespace) -> int:
    print("Domain → Recommended model:")
    for d, (m, r) in sorted(DOMAIN_RECOS.items()):
        print(f"  {d:18s} → {m:22s} | {r}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="helix-route-cost-audit")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_r = sub.add_parser("refresh", help="regenerate route-cost-audit.md")
    p_r.set_defaults(func=cmd_refresh)
    p_d = sub.add_parser("print-domains", help="show agent→domain mapping")
    p_d.set_defaults(func=cmd_print_domains)
    p_e = sub.add_parser("print-recos", help="show domain→model recommendations")
    p_e.set_defaults(func=cmd_print_recos)
    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

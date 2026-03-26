#!/usr/bin/env python3
"""
helix-agent-evolve.py — Sistema de evolución de agentes Helix
Audita, compara y evoluciona agentes locales contra fuentes remotas.

Uso:
  helix-agent-evolve.py audit [--agent NOMBRE]     → auditar todos o uno
  helix-agent-evolve.py compare <nombre>           → comparar local vs aitmpl/ruflo
  helix-agent-evolve.py evolve <nombre>            → guiar evolución interactiva
  helix-agent-evolve.py score <nombre>             → score de calidad del agente
  helix-agent-evolve.py report                     → reporte completo del ecosistema
"""

import sys
import os
import json
import re
import requests
import argparse
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional

AGENTS_DIR = Path.home() / ".claude/memory/agents"
META_DIR   = Path.home() / ".claude/memory/agents/.meta"
META_DIR.mkdir(exist_ok=True)

AITMPL_BASE = "https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/agents"
AITMPL_API  = "https://api.github.com/repos/davila7/claude-code-templates/contents/cli-tool/components/agents"

CATEGORIES = [
    "ai-specialists", "api-graphql", "business-marketing", "data-ai", "database",
    "deep-research-team", "development-team", "development-tools",
    "devops-infrastructure", "documentation", "expert-advisors",
    "performance-testing", "programming-languages", "security", "ui-analysis"
]


# ── Metadata de agente ────────────────────────────────────

def load_meta(agent: str) -> dict:
    meta_path = META_DIR / f"{agent}.json"
    if meta_path.exists():
        return json.loads(meta_path.read_text())
    return {
        "agent": agent,
        "version": "1.0",
        "source": "local",
        "created_at": None,
        "last_audit": None,
        "last_evolved": None,
        "aitmpl_category": None,
        "score": None,
        "evolution_log": []
    }


def save_meta(agent: str, meta: dict):
    meta_path = META_DIR / f"{agent}.json"
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False))


# ── Score de calidad de un agente ─────────────────────────

def score_agent(content: str) -> dict:
    """Evalúa la calidad de un agente (0-100)."""
    score = 0
    details = {}

    # 1. Tiene descripción rica (30 pts)
    has_frontmatter = content.startswith("---")
    has_description = "description:" in content
    desc_len = len(re.findall(r'description:\s*["\'](.+?)["\']', content, re.DOTALL))
    if has_frontmatter and has_description:
        score += 10
        details["frontmatter"] = "✓"
    if desc_len > 0 or len([l for l in content.split('\n') if 'description:' in l and len(l) > 100]):
        score += 20
        details["rich_description"] = "✓"
    else:
        details["rich_description"] = "✗ (muy corta)"

    # 2. Tiene ejemplos concretos (25 pts)
    examples = content.count("<example>") + content.count("## Ejemplo") + content.count("Context:")
    if examples >= 3:
        score += 25
        details["examples"] = f"✓ ({examples})"
    elif examples >= 1:
        score += 15
        details["examples"] = f"⚠ ({examples}, ideal ≥3)"
    else:
        details["examples"] = "✗ (sin ejemplos)"

    # 3. Tiene cuándo invocar / triggers (20 pts)
    has_triggers = bool(
        re.search(r"cuándo invocar|cuando invocar|when to use|trigger|use when", content, re.IGNORECASE)
    )
    if has_triggers:
        score += 20
        details["triggers"] = "✓"
    else:
        details["triggers"] = "✗"

    # 4. Tiene limitaciones definidas (10 pts)
    has_limits = bool(re.search(r"limitacion|limitation|no toca|does not|fuera de scope", content, re.IGNORECASE))
    if has_limits:
        score += 10
        details["limitations"] = "✓"
    else:
        details["limitations"] = "✗"

    # 5. Tiene vocabulario multilingüe o natural (10 pts)
    has_natural = bool(re.search(r"vocabulario|natural language|usuario dice|user says", content, re.IGNORECASE))
    if has_natural:
        score += 10
        details["natural_language"] = "✓"
    else:
        details["natural_language"] = "✗ (añadir frases de usuario)"

    # 6. Longitud mínima (5 pts)
    if len(content) > 500:
        score += 5
        details["length"] = f"✓ ({len(content)} chars)"
    else:
        details["length"] = f"✗ ({len(content)} chars, mínimo 500)"

    return {"score": min(score, 100), "details": details}


# ── Buscar agente en aitmpl ───────────────────────────────

def find_in_aitmpl(agent_name: str) -> Optional[tuple[str, str]]:
    """Busca un agente en aitmpl. Retorna (categoria, url) o None."""
    for cat in CATEGORIES:
        url = f"{AITMPL_BASE}/{cat}/{agent_name}.md"
        try:
            resp = requests.head(url, timeout=10)
            if resp.status_code == 200:
                return (cat, url)
        except:
            pass
    return None


def fetch_remote(url: str) -> Optional[str]:
    try:
        resp = requests.get(url, timeout=15)
        if resp.status_code == 200:
            return resp.text
    except:
        pass
    return None


# ── Comparar local vs remoto ──────────────────────────────

def compare_agents(local: str, remote: str) -> dict:
    """Compara dos versiones de un agente."""
    local_score = score_agent(local)["score"]
    remote_score = score_agent(remote)["score"]

    local_lines = set(local.split('\n'))
    remote_lines = set(remote.split('\n'))

    new_in_remote = [l for l in remote_lines - local_lines if l.strip() and len(l) > 20]
    only_in_local = [l for l in local_lines - remote_lines if l.strip() and len(l) > 20]

    return {
        "local_score": local_score,
        "remote_score": remote_score,
        "score_delta": remote_score - local_score,
        "new_in_remote": new_in_remote[:10],
        "only_in_local": only_in_local[:10],
        "recommendation": _recommend(local_score, remote_score, new_in_remote, only_in_local)
    }


def _recommend(ls: int, rs: int, new: list, local_only: list) -> str:
    if rs > ls + 30:
        return "REEMPLAZAR — remoto supera local en +30 pts"
    elif rs > ls + 10:
        return "MERGE — remoto tiene mejoras significativas, integrar manteniendo customizaciones locales"
    elif local_only and ls >= rs:
        return "MANTENER — local tiene customizaciones valiosas, no hay mejora significativa en remoto"
    elif rs < ls:
        return "MANTENER — local es superior"
    else:
        return "ENRIQUECER — ambos similares, combinar lo mejor de cada uno"


# ── Comandos ──────────────────────────────────────────────

def cmd_audit(args):
    agents = sorted(AGENTS_DIR.glob("*.md"))
    target = args.agent

    results = []
    for fpath in agents:
        name = fpath.stem
        if target and name != target:
            continue

        content = fpath.read_text(encoding="utf-8")
        scored = score_agent(content)
        meta = load_meta(name)

        # Actualizar metadata
        meta["last_audit"] = datetime.now(timezone.utc).isoformat()
        meta["score"] = scored["score"]
        save_meta(name, meta)

        results.append({
            "agent": name,
            "score": scored["score"],
            "details": scored["details"],
            "needs_attention": scored["score"] < 60,
            "last_evolved": meta.get("last_evolved"),
        })

    # Ordenar por score
    results.sort(key=lambda x: x["score"])

    print("\n" + "="*60)
    print("AUDITORÍA DE AGENTES HELIX")
    print("="*60)
    print(f"{'Agente':<30} {'Score':>6}  {'Estado'}")
    print("-"*60)
    for r in results:
        status = "🔴 ATENCIÓN" if r["score"] < 50 else ("🟡 MEJORABLE" if r["score"] < 75 else "✅ OK")
        print(f"{r['agent']:<30} {r['score']:>5}/100  {status}")
    print("-"*60)
    avg = sum(r["score"] for r in results) / len(results) if results else 0
    attn = sum(1 for r in results if r["needs_attention"])
    print(f"\nPromedio: {avg:.0f}/100 | Necesitan atención: {attn}/{len(results)}")
    print("\nPróximos pasos:")
    for r in sorted(results, key=lambda x: x["score"])[:3]:
        print(f"  helix-agent-evolve.py compare {r['agent']}")


def cmd_compare(args):
    name = args.agent
    local_path = AGENTS_DIR / f"{name}.md"

    if not local_path.exists():
        print(f"✗ Agente local no encontrado: {name}")
        sys.exit(1)

    local_content = local_path.read_text()
    local_score = score_agent(local_content)

    print(f"\n{'='*60}")
    print(f"COMPARACIÓN: {name}")
    print(f"{'='*60}")
    print(f"\nScore LOCAL: {local_score['score']}/100")
    for k, v in local_score["details"].items():
        print(f"  {k:<25} {v}")

    # Buscar en aitmpl
    print(f"\nBuscando en aitmpl...")
    found = find_in_aitmpl(name)
    if found:
        cat, url = found
        remote_content = fetch_remote(url)
        if remote_content:
            remote_score = score_agent(remote_content)
            comparison = compare_agents(local_content, remote_content)

            print(f"\nEncontrado en aitmpl: {cat}/{name}")
            print(f"Score REMOTO: {remote_score['score']}/100")
            print(f"Delta: {comparison['score_delta']:+d} pts")
            print(f"\n📋 RECOMENDACIÓN: {comparison['recommendation']}")

            if comparison["new_in_remote"]:
                print(f"\nContenido nuevo en remoto (muestra):")
                for line in comparison["new_in_remote"][:5]:
                    print(f"  + {line[:80]}")

            if comparison["only_in_local"]:
                print(f"\nContenido solo en local (proteger al mergear):")
                for line in comparison["only_in_local"][:5]:
                    print(f"  → {line[:80]}")

            # Guardar en meta
            meta = load_meta(name)
            meta["aitmpl_category"] = cat
            meta["last_audit"] = datetime.now(timezone.utc).isoformat()
            save_meta(name, meta)
        else:
            print("✗ No se pudo obtener contenido remoto")
    else:
        print(f"  No encontrado en aitmpl → considerar crear uno nuevo basado en local")
        print(f"  Sugerencia: helix-agent-evolve.py evolve {name}")


def cmd_evolve(args):
    name = args.agent
    local_path = AGENTS_DIR / f"{name}.md"

    if not local_path.exists():
        print(f"✗ Agente no encontrado: {name}")
        sys.exit(1)

    local_content = local_path.read_text()
    local_score = score_agent(local_content)
    meta = load_meta(name)

    print(f"\n{'='*60}")
    print(f"EVOLUCIÓN GUIADA: {name}")
    print(f"Score actual: {local_score['score']}/100")
    print(f"{'='*60}")

    improvements = []

    # Identificar qué mejorar
    details = local_score["details"]

    if "✗" in details.get("rich_description", ""):
        improvements.append({
            "area": "description",
            "issue": "Descripción muy corta o sin ejemplos concretos",
            "fix": "Añadir descripción con 2-3 ejemplos en formato:\n"
                   "  <example>\n  Context: ...\n  user: ...\n  assistant: ...\n  </example>"
        })

    if "✗" in details.get("examples", ""):
        improvements.append({
            "area": "examples",
            "issue": "Sin ejemplos concretos de uso",
            "fix": "Añadir al menos 2 ejemplos con Context, user query y assistant response"
        })

    if "✗" in details.get("natural_language", ""):
        improvements.append({
            "area": "vocabulary",
            "issue": "Sin vocabulario de usuario en lenguaje natural",
            "fix": "Añadir sección '## Vocabulario de usuario' con frases que disparan este agente"
        })

    if "✗" in details.get("limitations", ""):
        improvements.append({
            "area": "limitations",
            "issue": "Sin limitaciones definidas",
            "fix": "Añadir sección '## Limitaciones' con qué NO hace este agente"
        })

    if not improvements:
        print("\n✅ Este agente ya tiene buena calidad. Para mejorar más:")
        print("  - Comparar con aitmpl: helix-agent-evolve.py compare", name)
        print("  - Añadir más ejemplos de casos reales del proyecto")
    else:
        print(f"\nMejoras identificadas ({len(improvements)}):")
        for i, imp in enumerate(improvements, 1):
            print(f"\n{i}. [{imp['area'].upper()}] {imp['issue']}")
            print(f"   Fix: {imp['fix']}")

    # Buscar remoto para merge
    found = find_in_aitmpl(name)
    if found:
        cat, url = found
        print(f"\nRemoto disponible en aitmpl ({cat}/{name})")
        print(f"Para mergear: copiar secciones de {url}")

    # Registrar evolución
    meta["last_evolved"] = datetime.now(timezone.utc).isoformat()
    entry = {
        "date": meta["last_evolved"],
        "score_before": local_score["score"],
        "improvements": [i["area"] for i in improvements],
        "aitmpl_available": found is not None
    }
    meta["evolution_log"] = meta.get("evolution_log", []) + [entry]
    save_meta(name, meta)

    print(f"\n📝 Evolución registrada en .meta/{name}.json")


def cmd_score(args):
    name = args.agent
    local_path = AGENTS_DIR / f"{name}.md"
    if not local_path.exists():
        print(f"✗ Agente no encontrado: {name}")
        sys.exit(1)
    content = local_path.read_text()
    result = score_agent(content)
    print(json.dumps({"agent": name, **result}, indent=2, ensure_ascii=False))


def cmd_report(args):
    agents = sorted(AGENTS_DIR.glob("*.md"))
    print(f"\n{'='*60}")
    print(f"REPORTE DE ECOSISTEMA — {datetime.now().strftime('%Y-%m-%d')}")
    print(f"{'='*60}")
    print(f"Total agentes: {len(agents)}")

    scores = []
    no_meta = []
    needs_evolve = []

    for fpath in agents:
        name = fpath.stem
        content = fpath.read_text()
        s = score_agent(content)["score"]
        meta = load_meta(name)
        scores.append(s)

        if not meta.get("last_evolved"):
            no_meta.append(name)
        if s < 60:
            needs_evolve.append((name, s))

    avg = sum(scores) / len(scores) if scores else 0
    print(f"Score promedio: {avg:.0f}/100")
    print(f"Nunca evolucionados: {len(no_meta)}")
    print(f"Score crítico (<60): {len(needs_evolve)}")

    if needs_evolve:
        print(f"\n🔴 Agentes críticos:")
        for name, s in sorted(needs_evolve, key=lambda x: x[1]):
            print(f"  {name:<30} {s}/100")

    if no_meta:
        print(f"\n📋 Nunca auditados (priorizar):")
        for name in no_meta[:8]:
            print(f"  {name}")

    print(f"\n{'='*60}")
    print("Comandos sugeridos:")
    print("  helix-agent-evolve.py audit              → auditar todos")
    if needs_evolve:
        worst = min(needs_evolve, key=lambda x: x[1])
        print(f"  helix-agent-evolve.py compare {worst[0]}")
        print(f"  helix-agent-evolve.py evolve {worst[0]}")


def main():
    parser = argparse.ArgumentParser(description="Helix Agent Evolution System")
    sub = parser.add_subparsers(dest="command")

    p_audit = sub.add_parser("audit")
    p_audit.add_argument("--agent", default=None)

    p_compare = sub.add_parser("compare")
    p_compare.add_argument("agent")

    p_evolve = sub.add_parser("evolve")
    p_evolve.add_argument("agent")

    p_score = sub.add_parser("score")
    p_score.add_argument("agent")

    sub.add_parser("report")

    args = parser.parse_args()
    cmds = {
        "audit": cmd_audit,
        "compare": cmd_compare,
        "evolve": cmd_evolve,
        "score": cmd_score,
        "report": cmd_report
    }

    if not args.command or args.command not in cmds:
        parser.print_help()
        sys.exit(1)

    cmds[args.command](args)


if __name__ == "__main__":
    main()

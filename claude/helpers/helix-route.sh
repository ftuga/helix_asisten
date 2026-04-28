#!/usr/bin/env bash
# helix-route.sh - Routing con anti-bias y stack-aware
# Subcomandos: pick <domain> "<query>" [--epsilon N] | audit | weights
# Diseño: ~/.claude/memory/topics/routing-anti-bias.md

set -euo pipefail

PROJECT="${PROJECT_ROOT:-$PWD}"
STACK_FILE="$PROJECT/.claude/memory/helix-stack.md"
WEIGHTS_FILE="$HOME/.claude/config/routing-weights.yaml"
FEEDBACK="$HOME/.claude/memory/routing-feedback.jsonl"
QUALITY="$HOME/.claude/memory/skill-quality.jsonl"
AGENTS_DIR="$HOME/.claude/agents"

# Catalogo de dominios → agentes (subset; el catalogo completo en stack-catalogs.md)
declare -A DOMAIN_CATALOG=(
    [testing]="qa-expert test-engineer test-automator"
    [devops]="devops-engineer deployment-engineer azure-infra-engineer"
    [security]="security-auditor api-security-audit mcp-security-auditor"
    [database]="database-architect postgres-pro sql-pro postgresql-dba"
    [frontend]="frontend-developer nextjs-architecture-expert typescript-pro ui-designer ui-ux-designer"
    [backend]="backend-architect backend-developer python-pro typescript-pro fullstack-developer"
    [ml]="mlflow-expert airflow-dag-expert data-analyst"
    [api]="api-architect api-designer api-documenter"
    [error]="error-detective"
)

cmd_pick() {
    local domain="${1:?domain requerido (testing|devops|security|...|generic)}"
    local query="${2:?query requerido}"
    local epsilon="${3:-0.1}"
    local shadow="${4:-}"  # --shadow opcional: registra en log sin imprimir
    local shadow_log="$HOME/.claude/memory/routing-shadow.jsonl"

    # 1. Vector search (hv usa --top-k y retorna {results: [...]})
    # Output puede ser >30KB con \n y " — pasar por archivo temporal para evitar romper heredoc
    local raw_tmp
    raw_tmp=$(mktemp)
    hv search helix_agents "$query" --top-k 15 >"$raw_tmp" 2>/dev/null || echo '{"results":[]}' >"$raw_tmp"

    # 2. Stack del proyecto si existe
    local stack_core="" stack_extended="" stack_excluded=""
    if [[ -f "$STACK_FILE" ]]; then
        stack_core=$(awk '/^  core:/,/^  extended:/' "$STACK_FILE" | grep -E "^    - " | sed 's/^    - //' || true)
        stack_extended=$(awk '/^  extended:/,/^  excluded:/' "$STACK_FILE" | grep -E "^    - " | sed 's/^    - //' || true)
        stack_excluded=$(awk '/^  excluded:/,0' "$STACK_FILE" | grep -E "^    - " | sed 's/^    - //' || true)
    fi

    # 3. Catalogo del dominio
    local domain_catalog="${DOMAIN_CATALOG[$domain]:-}"

    # 4. Pesos
    local w_sim w_fresh w_quality w_stack
    if [[ -f "$WEIGHTS_FILE" ]]; then
        w_sim=$(grep -E "^w_sim:" "$WEIGHTS_FILE" | awk '{print $2}')
        w_fresh=$(grep -E "^w_fresh:" "$WEIGHTS_FILE" | awk '{print $2}')
        w_quality=$(grep -E "^w_quality:" "$WEIGHTS_FILE" | awk '{print $2}')
        w_stack=$(grep -E "^w_stack:" "$WEIGHTS_FILE" | awk '{print $2}')
    fi
    w_sim=${w_sim:-0.50}
    w_fresh=${w_fresh:-0.20}
    w_quality=${w_quality:-0.15}
    w_stack=${w_stack:-0.15}

    # 5. Re-rank en Python
    python3 <<PYEOF
import json, math, random, os, sys, time
from datetime import datetime, timedelta

try:
    with open("${raw_tmp}") as _f:
        raw_obj = json.load(_f)
except (json.JSONDecodeError, FileNotFoundError):
    raw_obj = {}

# hv search retorna {"results": [{"score", "id", "payload": {"agent","text",...}}]}
# Pero también aceptamos list directa por compatibilidad
if isinstance(raw_obj, dict):
    raw_list = raw_obj.get("results", [])
elif isinstance(raw_obj, list):
    raw_list = raw_obj
else:
    raw_list = []

def normalize(item):
    if not isinstance(item, dict):
        return None
    payload = item.get("payload") or {}
    agent = payload.get("agent") or item.get("agent") or payload.get("name")
    score = item.get("score", item.get("similarity", 0.0))
    return {"agent": agent, "similarity": float(score)} if agent else None

candidates = [c for c in (normalize(i) for i in raw_list) if c]

domain = "${domain}"
domain_catalog = "${domain_catalog}".split() if "${domain_catalog}" else []
stack_core = """${stack_core}""".split() if """${stack_core}""".strip() else []
stack_extended = """${stack_extended}""".split() if """${stack_extended}""".strip() else []
stack_excluded = """${stack_excluded}""".split() if """${stack_excluded}""".strip() else []

w_sim = float("${w_sim}")
w_fresh = float("${w_fresh}")
w_quality = float("${w_quality}")
w_stack = float("${w_stack}")
epsilon = float("${epsilon}")

# Filtro hard por catalogo del dominio
if domain != "generic" and domain_catalog:
    candidates = [c for c in candidates if c["agent"] in domain_catalog]
    # Si filtrado deja vacío → relajar: agregar todos los del catalogo con sim=0.5
    if not candidates:
        candidates = [{"agent": a, "similarity": 0.5} for a in domain_catalog]

# Filtro hard por excluded
candidates = [c for c in candidates if c["agent"] not in stack_excluded]

# Stack-vs-domain reconciliation
warnings = []
if (stack_core or stack_extended) and candidates:
    in_stack = [c for c in candidates if c["agent"] in stack_core or c["agent"] in stack_extended]
    if not in_stack:
        if domain != "generic" and domain_catalog:
            # Dominio específico: NO fallback a core (rompería el filtro de catálogo).
            # Avisar que el dominio no está cubierto por el stack y sugerir agregar.
            warnings.append(
                f"dominio '{domain}' no está cubierto por stack del proyecto; "
                f"considerar: helix-stack add <{'|'.join(domain_catalog[:3])}>"
            )
        else:
            # Generic: SÍ permitir fallback a core
            warnings.append("ningun candidato vector está en stack del proyecto; agregando core como fallback")
            candidates = candidates + [{"agent": a, "similarity": 0.4} for a in stack_core if a not in [c["agent"] for c in candidates]]

# Último fallback: sin candidatos pero hay stack → usar core
if not candidates and (stack_core or stack_extended):
    warnings.append("vector search vacío; usando stack del proyecto como universo de candidatos")
    candidates = [{"agent": a, "similarity": 0.5} for a in stack_core] + \
                 [{"agent": a, "similarity": 0.4} for a in stack_extended]

# Freshness: contar invocaciones en routing-feedback.jsonl últimos 30d
inv_count = {}
feedback_path = "${FEEDBACK}"
if os.path.isfile(feedback_path):
    cutoff = datetime.now() - timedelta(days=30)
    with open(feedback_path) as f:
        for line in f:
            try:
                e = json.loads(line)
                ts = e.get("ts") or e.get("timestamp") or e.get("date")
                if ts:
                    try:
                        d = datetime.fromisoformat(ts.split("T")[0])
                        if d < cutoff: continue
                    except Exception:
                        pass
                a = e.get("agent") or e.get("agente")
                if a:
                    inv_count[a] = inv_count.get(a, 0) + 1
            except Exception:
                continue

# Skill quality
quality = {}
quality_path = "${QUALITY}"
if os.path.isfile(quality_path):
    sums = {}
    counts = {}
    with open(quality_path) as f:
        for line in f:
            try:
                e = json.loads(line)
                a = e.get("agent") or e.get("agente")
                q = e.get("quality") or e.get("score")
                if a and q is not None:
                    sums[a] = sums.get(a, 0) + float(q)
                    counts[a] = counts.get(a, 0) + 1
            except Exception:
                continue
    for a in sums:
        quality[a] = sums[a] / counts[a]

# Scoring
def score_components(c):
    a = c["agent"]
    sim = c["similarity"]
    inv = inv_count.get(a, 0)
    fresh = 1.0 / (1.0 + math.log(inv + 1))
    sq_avg = quality.get(a, 2.0)
    sq = max(0.0, min(1.0, (sq_avg - 1.0) / 2.0))
    if a in stack_core:
        sm = 1.0
    elif a in stack_extended:
        sm = 0.6
    else:
        sm = 0.0
    final = w_sim * sim + w_fresh * fresh + w_quality * sq + w_stack * sm
    return {
        "agent": a,
        "score": round(final, 4),
        "similarity": round(sim, 4),
        "freshness": round(fresh, 4),
        "skill_quality": round(sq, 4),
        "stack_match": round(sm, 4),
        "invocations_30d": inv,
    }

ranked = sorted([score_components(c) for c in candidates], key=lambda x: x["score"], reverse=True)

if not ranked:
    print(json.dumps({"error": "sin candidatos despues de filtros", "warnings": warnings}, indent=2))
    sys.exit(0)

# Epsilon-greedy
epsilon_pick = False
best = ranked[0]
threshold = 0.7 * best["score"]
eligible = [r for r in ranked if r["score"] >= threshold]

if random.random() < epsilon and len(eligible) >= 3:
    best = random.choice(eligible)
    epsilon_pick = True

# Output
out = {
    "primary": {**best, "epsilon_pick": epsilon_pick},
    "alternatives": [r for r in ranked if r["agent"] != best["agent"]][:4],
    "warnings": warnings,
    "config": {
        "domain": domain,
        "epsilon": epsilon,
        "weights": {"w_sim": w_sim, "w_fresh": w_fresh, "w_quality": w_quality, "w_stack": w_stack},
        "stack_loaded": bool(stack_core or stack_extended),
    }
}

shadow_mode = "${shadow}" == "--shadow"
if shadow_mode:
    # Registrar recomendación en log sin imprimir (modo dry-run para validación 1 semana)
    import datetime as _dt
    log_entry = {
        "ts": _dt.datetime.now().isoformat(),
        "domain": "${domain}",
        "query": """${query}"""[:200],
        "primary": out["primary"]["agent"],
        "score": out["primary"]["score"],
        "epsilon_pick": epsilon_pick,
        "alternatives": [a["agent"] for a in out["alternatives"][:3]],
    }
    with open("${shadow_log}", "a") as f:
        f.write(json.dumps(log_entry) + "\n")
    print(json.dumps({"shadow": True, "logged": "${shadow_log}", "primary": out["primary"]["agent"]}))
else:
    print(json.dumps(out, indent=2))
PYEOF

    rm -f "$raw_tmp"
}

cmd_shadow_report() {
    local shadow_log="$HOME/.claude/memory/routing-shadow.jsonl"
    if [[ ! -f "$shadow_log" ]]; then
        echo "Sin shadow log. Ejecutar pick con --shadow primero."
        exit 0
    fi
    python3 <<PYEOF
import json
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

shadow = Path("${shadow_log}")
feedback = Path.home() / ".claude/memory/routing-feedback.jsonl"

shadow_picks = []
with shadow.open() as f:
    for line in f:
        try: shadow_picks.append(json.loads(line))
        except: continue

if not shadow_picks:
    print(json.dumps({"empty": True}))
    exit(0)

# Comparar con feedback real (si hay timestamps cercanos)
real_picks = []
if feedback.exists():
    with feedback.open() as f:
        for line in f:
            try: real_picks.append(json.loads(line))
            except: continue

# Ventana: últimos 7 días
cutoff = datetime.now() - timedelta(days=7)
recent_shadow = [s for s in shadow_picks if datetime.fromisoformat(s["ts"]) >= cutoff]

domain_dist = Counter(s["domain"] for s in recent_shadow)
primary_dist = Counter(s["primary"] for s in recent_shadow)
epsilon_count = sum(1 for s in recent_shadow if s.get("epsilon_pick"))

print(json.dumps({
    "window_days": 7,
    "total_shadow_picks": len(recent_shadow),
    "domain_distribution": dict(domain_dist),
    "primary_distribution": dict(primary_dist.most_common(10)),
    "epsilon_picks": epsilon_count,
    "epsilon_rate": round(epsilon_count / len(recent_shadow), 3) if recent_shadow else 0,
    "log_file": str(shadow),
    "next_step": "comparar primary_distribution vs invocaciones reales (routing-feedback.jsonl) — si convergen >90%, activar hook PreToolUse en producción"
}, indent=2))
PYEOF
}

cmd_audit() {
    python3 <<PYEOF
import json, os
from datetime import datetime, timedelta
from collections import Counter

feedback = "${FEEDBACK}"
agents_dir = "${AGENTS_DIR}"

if not os.path.isfile(feedback):
    print("No hay routing-feedback.jsonl — sin datos para auditar")
    exit(0)

cutoff = datetime.now() - timedelta(days=30)
counter = Counter()
total = 0
with open(feedback) as f:
    for line in f:
        try:
            e = json.loads(line)
            ts = e.get("ts") or e.get("timestamp") or e.get("date") or ""
            try:
                d = datetime.fromisoformat(ts.split("T")[0])
                if d < cutoff: continue
            except Exception:
                pass
            a = e.get("agent")
            if a:
                counter[a] += 1
                total += 1
        except Exception:
            continue

if total == 0:
    print("Sin invocaciones en últimos 30d")
    exit(0)

all_agents = [f[:-3] for f in os.listdir(agents_dir) if f.endswith('.md')]
unique_used = len(counter)
catalog_size = len(all_agents)
coverage = unique_used / catalog_size if catalog_size else 0

top3 = counter.most_common(3)
top3_share = sum(c for _, c in top3) / total

never_used = [a for a in all_agents if a not in counter]

out = {
    "window_days": 30,
    "total_invocations": total,
    "unique_agents_used": unique_used,
    "catalog_size": catalog_size,
    "coverage_ratio": round(coverage, 3),
    "top3_saturation": round(top3_share, 3),
    "top3": [{"agent": a, "count": c, "share": round(c/total, 3)} for a, c in top3],
    "never_used_count": len(never_used),
    "never_used_sample": never_used[:10],
    "verdict": (
        "BIASED — top3 acumula ≥50% invocaciones" if top3_share >= 0.5
        else "OK"
    ),
}
print(json.dumps(out, indent=2))
PYEOF
}

cmd_weights() {
    if [[ ! -f "$WEIGHTS_FILE" ]]; then
        mkdir -p "$(dirname "$WEIGHTS_FILE")"
        cat > "$WEIGHTS_FILE" <<EOF
# helix-route.sh — pesos del scoring
# Suma debe ser ~1.0
w_sim: 0.50
w_fresh: 0.20
w_quality: 0.15
w_stack: 0.15

# Epsilon-greedy
epsilon: 0.10
EOF
        echo "OK creado $WEIGHTS_FILE con defaults"
    fi
    cat "$WEIGHTS_FILE"
}

CMD="${1:-help}"
shift || true

case "$CMD" in
    pick)           cmd_pick "$@" ;;
    audit)          cmd_audit ;;
    weights)        cmd_weights ;;
    shadow-report)  cmd_shadow_report ;;
    help|*)
        cat <<EOF
helix-route.sh — Routing con anti-bias y stack-aware

Uso: bash $0 <comando> [args]

Comandos:
  pick <domain> "<query>" [epsilon] [--shadow]  Selecciona agente óptimo
                                                  domain: testing|devops|security|database|
                                                         frontend|backend|ml|api|error|generic
                                                  epsilon: prob exploración (default 0.1)
                                                  --shadow: registra en log sin imprimir (dry-run)
  audit                                          Reporta cobertura, top-3 saturation, never-used
  shadow-report                                  Resume picks en modo shadow (últimos 7d)
  weights                                        Muestra/inicializa pesos del scoring

Variables:
  PROJECT_ROOT        Directorio del proyecto (default: \$PWD)

Diseño:    ~/.claude/memory/topics/routing-anti-bias.md
Catálogos: ~/.claude/memory/topics/stack-catalogs.md
EOF
        ;;
esac

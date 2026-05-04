#!/usr/bin/env bash
[[ -f "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf" ]] && source "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helix-python.conf"
# helix-stack.sh - Stack manifest manager para proyectos Helix
# Subcomandos: detect | init [mode] | show | add <agent> | remove <agent> | promote <agent>
# Diseño: ~/.claude/memory/topics/stack-manifest.md

set -euo pipefail

PROJECT="${PROJECT_ROOT:-$PWD}"
STACK_FILE="$PROJECT/.claude/memory/helix-stack.md"
CATALOGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/memory/topics/stack-catalogs.md"
AGENTS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents"

ts() { date '+%Y-%m-%d'; }

agent_exists() {
    [[ -f "$AGENTS_DIR/$1.md" ]]
}

# ─────────────────────────────────────────────────────────────
# detect: imprime JSON con tier + stack base + agentes recomendados
# ─────────────────────────────────────────────────────────────
cmd_detect() {
    local files loc has_ci has_tests has_iac
    local stack_json

    # 1. Stack base via detector existente (lenguaje/framework)
    if [[ -x "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-detect-stack.sh" ]]; then
        stack_json=$(bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/helpers/helix-detect-stack.sh" "$PROJECT" 2>/dev/null || echo '{}')
    else
        stack_json='{}'
    fi

    # 2. Métricas de tier
    files=$(find "$PROJECT" -type f \
        \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
           -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.kt" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.venv/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -not -path "*/.next/*" \
        2>/dev/null | wc -l | tr -d ' ')

    loc=$(find "$PROJECT" -type f \
        \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.venv/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -not -path "*/.next/*" \
        2>/dev/null -exec cat {} + 2>/dev/null | wc -l | tr -d ' ')
    [[ -z "$loc" ]] && loc=0

    has_ci=false
    [[ -d "$PROJECT/.github/workflows" ]] && has_ci=true
    [[ -f "$PROJECT/.gitlab-ci.yml" ]] && has_ci=true
    [[ -f "$PROJECT/Jenkinsfile" ]] && has_ci=true

    has_tests=false
    [[ -d "$PROJECT/tests" ]] && has_tests=true
    [[ -d "$PROJECT/test" ]] && has_tests=true
    [[ -d "$PROJECT/__tests__" ]] && has_tests=true

    has_iac=false
    [[ -d "$PROJECT/k8s" ]] && has_iac=true
    [[ -d "$PROJECT/terraform" ]] && has_iac=true
    [[ -f "$PROJECT/main.tf" ]] && has_iac=true
    [[ -f "$PROJECT/main.bicep" ]] && has_iac=true

    # 3. Determinar tier
    local tier
    if (( files >= 100 )) || (( loc >= 10000 )) || { [[ "$has_ci" == "true" ]] && [[ "$has_iac" == "true" ]]; }; then
        tier="large"
    elif (( files >= 10 )) || (( loc >= 500 )) || [[ "$has_tests" == "true" ]]; then
        tier="medium"
    else
        tier="small"
    fi

    # 4. Recomendaciones de agentes (lookup en catálogos)
    "${HELIX_PYTHON:-python3}" <<PYEOF
import json, os, re

stack_base = json.loads('''${stack_json}''') if '''${stack_json}'''.strip() else {}
tier = "${tier}"
has_ci_b = "${has_ci}" == "true"
has_tests_b = "${has_tests}" == "true"
has_iac_b = "${has_iac}" == "true"

# Mapeo determinista — debe quedar sincronizado con stack-catalogs.md
LANG_AGENTS = {
    "python": ["python-pro"],
    "typescript": ["typescript-pro"],
    "javascript": ["frontend-developer"],
}
FRAMEWORK_AGENTS = {
    "react": ["frontend-developer"],
    "nextjs": ["frontend-developer", "nextjs-architecture-expert"],
    "vue": ["frontend-developer"],
    "fastapi": ["python-pro", "backend-architect"],
    "django": ["python-pro", "backend-architect"],
    "flask": ["python-pro", "backend-architect"],
}
DB_AGENTS = {
    "postgresql": ["postgres-pro", "sql-pro"],
    "mysql": ["sql-pro"],
}
INFRA_AGENTS_MEDIUM_PLUS = {
    "docker-compose": ["devops-engineer"],
    "kubernetes": ["devops-engineer"],
}

TIER_EXTENDED = {
    "small": [],
    "medium": ["code-reviewer", "security-auditor"],
    "large": [
        "code-reviewer", "security-auditor",
        "database-architect", "architect-reviewer",
        "qa-expert", "business-analyst",
        "devops-engineer", "monitoring-specialist", "performance-engineer"
    ],
}

# Stack universal: agentes de PROCESO (no dominio) que siempre van en core
# independiente del lenguaje/framework. Sin estos, el routing puede excluirlos.
UNIVERSAL_BASE = ["error-detective", "code-reviewer", "architect-reviewer"]

# Catálogo externo extensible: ~/.claude/memory/topics/specialized-agents-catalog.json
# Cubre: languages, frameworks, domains, infrastructure, blockchain, specialized, compliance
CATALOG_PATH = os.path.expanduser("~/.claude/memory/topics/specialized-agents-catalog.json")
SPECIALIZED_CATALOG = {}
try:
    with open(CATALOG_PATH) as _f:
        SPECIALIZED_CATALOG = json.load(_f)
except Exception:
    pass

# Construir core
core = []
backend_lang = stack_base.get("backend", {}).get("language") if isinstance(stack_base.get("backend"), dict) else None
frontend_lang = stack_base.get("frontend", {}).get("language") if isinstance(stack_base.get("frontend"), dict) else None
backend_fw = stack_base.get("backend", {}).get("framework") if isinstance(stack_base.get("backend"), dict) else None
frontend_fw = stack_base.get("frontend", {}).get("framework") if isinstance(stack_base.get("frontend"), dict) else None
db = stack_base.get("database", {}).get("engine") if isinstance(stack_base.get("database"), dict) else None
infra = stack_base.get("infrastructure", {}).get("type") if isinstance(stack_base.get("infrastructure"), dict) else None

# fallback: parsear top-level si el JSON no es nested
if not backend_lang and "backend_lang" in stack_base:
    backend_lang = stack_base.get("backend_lang")
if not frontend_lang and "frontend_lang" in stack_base:
    frontend_lang = stack_base.get("frontend_lang")
if not backend_fw and "backend" in stack_base and isinstance(stack_base["backend"], str):
    backend_fw = stack_base["backend"]
if not frontend_fw and "frontend" in stack_base and isinstance(stack_base["frontend"], str):
    frontend_fw = stack_base["frontend"]
if not db and "database" in stack_base and isinstance(stack_base["database"], str):
    db = stack_base["database"]
if not infra and "infra" in stack_base and isinstance(stack_base["infra"], str):
    infra = stack_base["infra"]

for lang in [backend_lang, frontend_lang]:
    if lang and lang in LANG_AGENTS:
        for a in LANG_AGENTS[lang]:
            if a not in core:
                core.append(a)

for fw in [backend_fw, frontend_fw]:
    if fw and fw in FRAMEWORK_AGENTS:
        for a in FRAMEWORK_AGENTS[fw]:
            if a not in core:
                core.append(a)

if db and db in DB_AGENTS:
    for a in DB_AGENTS[db]:
        if a not in core:
            core.append(a)

if infra and tier in ("medium", "large"):
    for key in INFRA_AGENTS_MEDIUM_PLUS:
        if key in str(infra):
            for a in INFRA_AGENTS_MEDIUM_PLUS[key]:
                if a not in core:
                    core.append(a)

# Inyectar UNIVERSAL_BASE en core (siempre, independiente del tier)
for a in UNIVERSAL_BASE:
    if a not in core:
        core.append(a)

extended = [a for a in TIER_EXTENDED[tier] if a not in core]

# Validar existencia
agents_dir = os.path.expanduser("~/.claude/agents")
def exists(a):
    return os.path.isfile(os.path.join(agents_dir, f"{a}.md"))

missing = [a for a in (core + extended) if not exists(a)]
core = [a for a in core if exists(a)]
extended = [a for a in extended if exists(a)]

# ────────────────────────────────────────────────────────────
# Detectar señales del proyecto contra el catálogo extensible
# Cada categoría (languages/frameworks/domains/infra/...) se evalúa por separado
# ────────────────────────────────────────────────────────────
import glob, fnmatch

PROJECT_PATH = "${PROJECT}"

def _read_text_safe(p, max_bytes=256_000):
    try:
        with open(p, "rb") as f:
            return f.read(max_bytes).decode("utf-8", errors="ignore")
    except Exception:
        return ""

def _has_files(patterns):
    for pat in patterns:
        # buscar en el árbol del proyecto, excluyendo node_modules y similares
        for root, dirs, files in os.walk(PROJECT_PATH):
            dirs[:] = [d for d in dirs if d not in ("node_modules", ".venv", "__pycache__", ".git", "dist", "build", ".next")]
            for f in files:
                if fnmatch.fnmatch(f, pat):
                    return True
            if root != PROJECT_PATH:
                continue  # ya checamos archivos del root
        # también check del manifest en root
        if os.path.isfile(os.path.join(PROJECT_PATH, pat)):
            return True
    return False

def _has_dirs(names):
    return any(os.path.isdir(os.path.join(PROJECT_PATH, n)) for n in names)

def _has_manifest(names):
    return any(os.path.isfile(os.path.join(PROJECT_PATH, n)) for n in names)

def _deps_python_match(deps):
    sources = [
        os.path.join(PROJECT_PATH, "requirements.txt"),
        os.path.join(PROJECT_PATH, "pyproject.toml"),
        os.path.join(PROJECT_PATH, "Pipfile"),
    ]
    text = " ".join(_read_text_safe(s).lower() for s in sources if os.path.isfile(s))
    return any(d.lower() in text for d in deps)

def _deps_node_match(deps):
    pj = os.path.join(PROJECT_PATH, "package.json")
    if not os.path.isfile(pj):
        return False
    try:
        with open(pj) as f:
            pkg = json.load(f)
        all_deps = {**pkg.get("dependencies", {}), **pkg.get("devDependencies", {})}
        return any(d in all_deps for d in deps)
    except Exception:
        text = _read_text_safe(pj).lower()
        return any(d.lower() in text for d in deps)

def _deps_generic_match(filename, deps):
    p = os.path.join(PROJECT_PATH, filename)
    if not os.path.isfile(p):
        return False
    text = _read_text_safe(p).lower()
    return any(d.lower() in text for d in deps)

def _readme_keywords(keywords):
    for name in ["README.md", "README.rst", "README.txt", "README"]:
        p = os.path.join(PROJECT_PATH, name)
        if os.path.isfile(p):
            text = _read_text_safe(p)
            return any(kw.lower() in text.lower() for kw in keywords)
    return False

def _signal_hits(signals):
    if not signals: return False
    if "files" in signals and _has_files(signals["files"]):
        return True
    if "dirs" in signals and _has_dirs(signals["dirs"]):
        return True
    if "manifest" in signals and _has_manifest(signals["manifest"]):
        return True
    if "deps_python" in signals and _deps_python_match(signals["deps_python"]):
        return True
    if "deps_node" in signals and _deps_node_match(signals["deps_node"]):
        return True
    if "deps_ruby" in signals and _deps_generic_match("Gemfile", signals["deps_ruby"]):
        return True
    if "deps_elixir" in signals and _deps_generic_match("mix.exs", signals["deps_elixir"]):
        return True
    if "deps_rust" in signals and _deps_generic_match("Cargo.toml", signals["deps_rust"]):
        return True
    if "deps_go" in signals and _deps_generic_match("go.mod", signals["deps_go"]):
        return True
    if "keywords_in_readme" in signals and _readme_keywords(signals["keywords_in_readme"]):
        return True
    return False

# Recorrer catálogo: para cada entry detectada, si agente no existe → unsupported
unsupported_fws = []
detected_signals = []

for category, entries in SPECIALIZED_CATALOG.items():
    if category.startswith("_"):
        continue
    if not isinstance(entries, dict):
        continue
    for key, entry in entries.items():
        if not isinstance(entry, dict):
            continue
        signals = entry.get("signals", {})
        if _signal_hits(signals):
            agent = entry.get("agent")
            detected_signals.append({"category": category, "key": key, "agent": agent})
            if agent and not exists(agent):
                unsupported_fws.append({
                    "category": category,
                    "detected": key,
                    "suggested_agent": agent,
                    "create_command": f"# 1. invocar skill agent-create con: {agent}\n# 2. tras crear: helix-stack.sh add {agent}"
                })

out = {
    "project": os.path.basename("${PROJECT}"),
    "tier": tier,
    "metrics": {
        "files": ${files},
        "loc": ${loc},
        "has_ci": has_ci_b,
        "has_tests": has_tests_b,
        "has_iac": has_iac_b
    },
    "base_stack": stack_base,
    "recommended": {
        "core": core,
        "extended": extended,
        "missing_in_catalog": missing,
        "universal_base_applied": [a for a in UNIVERSAL_BASE if a in core]
    },
    "unsupported_frameworks": unsupported_fws,
    "detected_signals": detected_signals
}
print(json.dumps(out, indent=2))
PYEOF
}

# ─────────────────────────────────────────────────────────────
# init: genera helix-stack.md con un mode dado
# ─────────────────────────────────────────────────────────────
cmd_init() {
    local mode="${1:-extended}"
    case "$mode" in
        technical|extended|custom) ;;
        *) echo "ERROR: mode debe ser technical|extended|custom (recibido: $mode)"; exit 1 ;;
    esac

    if [[ -f "$STACK_FILE" ]]; then
        echo "Manifest ya existe: $STACK_FILE"
        echo "Usar 'helix-stack show' para ver, o eliminar para re-init."
        exit 1
    fi

    mkdir -p "$(dirname "$STACK_FILE")"

    # Detectar (output a archivo temporal para evitar problemas de heredoc con JSON multilínea)
    local tmpfile
    tmpfile=$(mktemp)
    cmd_detect > "$tmpfile"

    # Generar manifest
    "${HELIX_PYTHON:-python3}" <<PYEOF
import json, os
with open("${tmpfile}") as f:
    d = json.load(f)
mode = "${mode}"

core = d["recommended"]["core"]
extended = d["recommended"]["extended"] if mode == "extended" else []
project_name = d["project"]
tier = d["tier"]
metrics = d["metrics"]
base = d.get("base_stack", {})

langs = []
fws = []
if isinstance(base.get("backend"), dict):
    if base["backend"].get("language"): langs.append(base["backend"]["language"])
    if base["backend"].get("framework"): fws.append(base["backend"]["framework"])
if isinstance(base.get("frontend"), dict):
    if base["frontend"].get("language"): langs.append(base["frontend"]["language"])
    if base["frontend"].get("framework"): fws.append(base["frontend"]["framework"])

# Fallback flat
for k in ["backend_lang", "frontend_lang"]:
    v = base.get(k)
    if v and v != "none" and v not in langs:
        langs.append(v)
for k in ["backend", "frontend"]:
    v = base.get(k)
    if isinstance(v, str) and v != "none" and v not in fws:
        fws.append(v)

content = f'''---
project: {project_name}
tier: {tier}
detected_at: {os.popen("date +%Y-%m-%d").read().strip()}
mode: {mode}
detected:
  files: {metrics['files']}
  loc: {metrics['loc']}
  has_ci: {str(metrics['has_ci']).lower()}
  has_tests: {str(metrics['has_tests']).lower()}
  has_iac: {str(metrics['has_iac']).lower()}
  languages: {json.dumps(langs)}
  frameworks: {json.dumps(fws)}
stack:
  core:
{chr(10).join(f"    - {a}" for a in core) if core else "    []"}
  extended:
{chr(10).join(f"    - {a}" for a in extended) if extended else "    []"}
  excluded: []
---

## Notas

Stack manifest generado automáticamente por \`helix-stack.sh init {mode}\`.

Para modificar:
- \`bash ~/.claude/helpers/helix-stack.sh add <agent>\` — agregar a core
- \`bash ~/.claude/helpers/helix-stack.sh remove <agent>\` — mover a excluded
- \`bash ~/.claude/helpers/helix-stack.sh promote <agent>\` — extended → core
- editar manualmente este archivo (modo custom)

Catálogos consultados: \`~/.claude/memory/topics/stack-catalogs.md\`
Diseño: \`~/.claude/memory/topics/stack-manifest.md\`
'''

with open("${STACK_FILE}", "w") as f:
    f.write(content)
print(f"OK manifest creado: ${STACK_FILE}")
print(f"   tier={tier} mode={mode} core={len(core)} extended={len(extended)}")
PYEOF

    rm -f "$tmpfile"
}

# ─────────────────────────────────────────────────────────────
# show: imprime el manifest actual
# ─────────────────────────────────────────────────────────────
cmd_show() {
    if [[ ! -f "$STACK_FILE" ]]; then
        echo "Sin manifest. Ejecutar: bash $0 init [technical|extended|custom]"
        exit 1
    fi
    cat "$STACK_FILE"
}

# ─────────────────────────────────────────────────────────────
# add/remove/promote: edita el manifest YAML
# ─────────────────────────────────────────────────────────────
cmd_modify() {
    local action="$1"
    local agent="${2:?agente requerido}"

    if [[ ! -f "$STACK_FILE" ]]; then
        echo "Sin manifest. Ejecutar: bash $0 init"
        exit 1
    fi
    if ! agent_exists "$agent"; then
        echo "WARN: agente '$agent' no existe en $AGENTS_DIR. Continuando de todos modos."
    fi

    "${HELIX_PYTHON:-python3}" <<PYEOF
import re, sys
agent = "${agent}"
action = "${action}"
path = "${STACK_FILE}"

with open(path) as f:
    content = f.read()

# Parser simple del bloque YAML stack:
def get_list(content, key):
    pattern = rf"({key}:\s*\n)((?:    - .*\n)*)"
    m = re.search(pattern, content)
    if not m: return [], None, None
    items = re.findall(r"    - (.+)", m.group(2))
    return items, m.start(2), m.end(2)

def replace_list(content, key, items):
    # Caso 1: lista inline `key: []`
    inline_pattern = rf"  {key}:\s*\[\]\s*\n"
    new = f"  {key}:\n"
    if items:
        new += "\n".join(f"    - {a}" for a in items) + "\n"
    else:
        new += "    []\n"
    if re.search(inline_pattern, content):
        return re.sub(inline_pattern, new, content, count=1)
    # Caso 2: lista multilinea (con items o sin)
    pattern = rf"  {key}:\s*\n(?:    - .*\n)*(?:    \[\]\s*\n)?"
    return re.sub(pattern, new, content, count=1)

core, _, _ = get_list(content, "core")
extended, _, _ = get_list(content, "extended")
excluded, _, _ = get_list(content, "excluded")

if action == "add":
    if agent not in core:
        core.append(agent)
    if agent in extended: extended.remove(agent)
    if agent in excluded: excluded.remove(agent)
elif action == "remove":
    if agent in core: core.remove(agent)
    if agent in extended: extended.remove(agent)
    if agent not in excluded:
        excluded.append(agent)
elif action == "promote":
    if agent in extended:
        extended.remove(agent)
    if agent not in core:
        core.append(agent)

content = replace_list(content, "core", core)
content = replace_list(content, "extended", extended)
content = replace_list(content, "excluded", excluded)

with open(path, "w") as f:
    f.write(content)

print(f"OK {action} {agent}")
print(f"   core={len(core)} extended={len(extended)} excluded={len(excluded)}")
PYEOF
}

# ─────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────
CMD="${1:-help}"
shift || true

# ─────────────────────────────────────────────────────────────
# auto-promote-check: detecta agentes extended con uso ≥3 que merecen ascenso
# ─────────────────────────────────────────────────────────────
cmd_auto_promote_check() {
    if [[ ! -f "$STACK_FILE" ]]; then
        echo "Sin manifest. Ejecutar: bash $0 init"
        exit 1
    fi

    "${HELIX_PYTHON:-python3}" <<PYEOF
import json, os, re
from datetime import datetime, timedelta
from collections import Counter
from pathlib import Path

stack_file = Path("${STACK_FILE}")
content = stack_file.read_text()

def get_list(key):
    m = re.search(rf"({key}:\s*\n)((?:    - .*\n)*)", content)
    return re.findall(r"    - (.+)", m.group(2)) if m else []

extended = set(get_list("extended"))
core = set(get_list("core"))

if not extended:
    print(json.dumps({"status": "no_extended", "message": "stack.extended está vacío — nada que evaluar"}))
    exit(0)

# Leer routing-feedback.jsonl últimos 30d, filtrar por proyecto
project_name = os.path.basename("${PROJECT}")
feedback = Path.home() / ".claude/memory/routing-feedback.jsonl"
if not feedback.exists():
    print(json.dumps({"status": "no_feedback", "message": "sin routing-feedback.jsonl"}))
    exit(0)

cutoff = datetime.now() - timedelta(days=30)
counter = Counter()
with feedback.open() as f:
    for line in f:
        try:
            e = json.loads(line)
            proj = e.get("proyecto") or e.get("project") or ""
            if proj and proj != project_name:
                continue
            ts = e.get("ts") or e.get("timestamp") or ""
            try:
                d = datetime.fromisoformat(ts.split(" ")[0]) if ts else None
                if d and d < cutoff:
                    continue
            except Exception:
                pass
            a = e.get("agente") or e.get("agent")
            if a:
                counter[a] += 1
        except Exception:
            continue

# Candidatos: en extended con ≥3 invocaciones
candidates = sorted(
    [(a, c) for a, c in counter.items() if a in extended and c >= 3],
    key=lambda x: -x[1]
)

result = {
    "status": "ok",
    "project": project_name,
    "extended_count": len(extended),
    "candidates_for_promotion": [
        {"agent": a, "invocations_30d": c, "command": f"helix-stack.sh promote {a}"}
        for a, c in candidates
    ],
    "total_extended_invocations": sum(c for a, c in counter.items() if a in extended),
}
print(json.dumps(result, indent=2))
PYEOF
}

# ─────────────────────────────────────────────────────────────
# suggest-agents: lista frameworks detectados sin agente especializado
# y sugiere comando para crearlos vía skill agent-create
# ─────────────────────────────────────────────────────────────
cmd_suggest_agents() {
    local tmpfile
    tmpfile=$(mktemp)
    cmd_detect > "$tmpfile"

    "${HELIX_PYTHON:-python3}" <<PYEOF
import json
with open("${tmpfile}") as f:
    d = json.load(f)
unsupported = d.get("unsupported_frameworks", [])
if not unsupported:
    print(json.dumps({
        "status": "ok",
        "message": "todos los frameworks detectados tienen agente especializado o usan fallback genérico aceptable"
    }, indent=2))
else:
    print(json.dumps({
        "status": "missing_agents",
        "count": len(unsupported),
        "suggestions": unsupported,
        "next_step": (
            "Para cada suggested_agent, invocar el skill 'agent-create' "
            "(pipeline research-first con allowlist + validación ≥80%). "
            "El usuario debe confirmar cada creación. NUNCA auto-crear sin OK."
        )
    }, indent=2))
PYEOF
    rm -f "$tmpfile"
}

# ─────────────────────────────────────────────────────────────
# create-suggested: prepara contexto para invocar skill agent-create
# El bash NO crea el agente directamente — imprime instrucciones estructuradas
# que Helix (Claude Code) lee y convierte en una invocación del skill agent-create.
# ─────────────────────────────────────────────────────────────
cmd_create_suggested() {
    local agent_name="${1:?agent name requerido}"

    local tmpfile
    tmpfile=$(mktemp)
    cmd_detect > "$tmpfile"

    "${HELIX_PYTHON:-python3}" <<PYEOF
import json, sys
with open("${tmpfile}") as f:
    d = json.load(f)

target = "${agent_name}"
unsupported = d.get("unsupported_frameworks", [])

# Buscar el contexto del agente solicitado
context = None
for entry in unsupported:
    if entry.get("suggested_agent") == target:
        context = entry
        break

if not context:
    print(json.dumps({
        "status": "not_in_suggestions",
        "message": f"'{target}' no aparece en suggest-agents. Verificar con: helix-stack suggest-agents",
        "available_suggestions": [e["suggested_agent"] for e in unsupported]
    }, indent=2))
    sys.exit(1)

# Enriquecer contexto con info del proyecto
project_name = d.get("project", "unknown")
tier = d.get("tier", "unknown")
detected_signals = [
    s for s in d.get("detected_signals", [])
    if s.get("agent") == target
]

# Output estructurado: instrucciones para Helix invocar skill agent-create
out = {
    "status": "ready_to_create",
    "target_agent": target,
    "category": context.get("category"),
    "detected_as": context.get("detected"),
    "project_context": {
        "project": project_name,
        "tier": tier,
        "languages": d.get("base_stack", {}).get("file_counts", {}),
    },
    "detection_evidence": detected_signals,
    "next_steps_for_helix": [
        f"1. Invocar el skill 'agent-create' con domain='{context.get('detected')}' y target='{target}'.",
        "2. El skill seguirá su pipeline research-first (allowlist + anti-injection + validación ≥80%).",
        "3. PEDIR OK del usuario antes de escribir el agente (regla CLAUDE.md).",
        f"4. Tras crear: ejecutar 'bash ~/.claude/helpers/helix-stack.sh add {target}' para sumarlo al stack del proyecto.",
        f"5. Opcional: 'hv index-agents' para indexar el nuevo agente en vector store.",
    ],
    "skill_invocation_hint": (
        f"Usar Skill tool con: skill='agent-create', "
        f"args='target={target} domain={context.get('detected')} "
        f"project={project_name} category={context.get('category')}'"
    )
}
print(json.dumps(out, indent=2))
PYEOF

    rm -f "$tmpfile"
}

case "$CMD" in
    detect)              cmd_detect ;;
    init)                cmd_init "${1:-extended}" ;;
    show)                cmd_show ;;
    add)                 cmd_modify "add" "${1:-}" ;;
    remove)              cmd_modify "remove" "${1:-}" ;;
    promote)             cmd_modify "promote" "${1:-}" ;;
    auto-promote-check)  cmd_auto_promote_check ;;
    suggest-agents)      cmd_suggest_agents ;;
    create-suggested)    cmd_create_suggested "${1:-}" ;;
    help|*)
        cat <<EOF
helix-stack.sh — Stack manifest manager

Uso: bash $0 <comando> [args]

Comandos:
  detect                  Detecta tier + stack base, imprime JSON
  init [mode]             Crea manifest (mode: technical|extended|custom, default: extended)
  show                    Imprime manifest actual
  add <agent>             Agrega agente a stack.core
  remove <agent>          Mueve agente a stack.excluded
  promote <agent>         Mueve agente de extended a core
  auto-promote-check      Lista agentes extended con ≥3 usos (candidatos a core)
  suggest-agents          Lista frameworks detectados sin agente especializado
  create-suggested <name> Prepara contexto para que Helix invoque skill agent-create

Variables:
  PROJECT_ROOT            Directorio del proyecto (default: \$PWD)

Documentación: ~/.claude/memory/topics/stack-manifest.md
Catálogos:     ~/.claude/memory/topics/stack-catalogs.md
EOF
        ;;
esac

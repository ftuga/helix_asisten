#!/usr/bin/env bash
# routing-check-hook.sh — PreToolUse(Agent): valida dominio↔agente antes de invocar.
# Bloquea mismatches de alta confianza (exit 2). Advierte en ambiguos (exit 0 + stderr).
# Payload stdin: { tool_input: { subagent_type, prompt, description }, ... }
set -uo pipefail

PAYLOAD=$(cat)
[[ -z "$PAYLOAD" ]] && exit 0

HOOK_PAYLOAD="$PAYLOAD" python3 <<'PYEOF'
import sys, json, os

payload_str = os.environ.get("HOOK_PAYLOAD", "")
if not payload_str:
    sys.exit(0)

try:
    data = json.loads(payload_str)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {}) or {}
agent = (tool_input.get("subagent_type") or "").strip()
if not agent:
    sys.exit(0)

prompt = (tool_input.get("prompt") or "") + " " + (tool_input.get("description") or "")
prompt = prompt.lower()[:1000]

# Dominio -> agentes aceptados (primer match gana)
DOMAIN_KEYWORDS = [
    ("devops",       ["docker", "ci/cd", "pipeline", "kubernetes", "k8s", "nginx", "deploy"],
                     {"devops-engineer", "deployment-engineer"}),
    ("database",     ["schema sql", "migración db", "migration db", "índice sql", "index sql",
                      "query lenta", "plan de ejecución", "postgres", "mysql"],
                     {"database-architect", "postgres-pro", "postgresql-dba", "sql-pro"}),
    ("testing",      ["pytest", "jest", "cobertura test", "coverage", "test unitario", "unit test", "e2e"],
                     {"test-engineer", "test-automator", "qa-expert"}),
    ("security",     ["jwt", "rbac", "auditoría seguridad", "vulnerabilidad", "owasp", "autenticación"],
                     {"security-auditor", "api-security-audit", "security-engineer", "mcp-security-auditor"}),
    ("analysis",     ["reporte métricas", "kpi", "dashboard analítico", "análisis datos"],
                     {"data-analyst"}),
    ("frontend",     ["componente react", "tsx", "jsx", "tailwind", "react query", "zustand"],
                     {"frontend-developer", "ui-designer", "ui-ux-designer", "typescript-pro", "nextjs-architecture-expert"}),
    ("backend",      ["endpoint fastapi", "sqlalchemy", "pydantic", "celery"],
                     {"python-pro", "backend-architect", "backend-developer"}),
    ("bug",          ["traceback", "stack trace", "excepción no manejada", "crash inesperado"],
                     {"error-detective"}),
]

dominio = None
permitidos = None
for dom, kws, allowed in DOMAIN_KEYWORDS:
    if any(kw in prompt for kw in kws):
        dominio = dom
        permitidos = allowed
        break

if not dominio:
    sys.exit(0)  # dominio no identificable — dejar pasar

# general-purpose siempre es señal de ruido (no está en catálogo)
if agent == "general-purpose":
    print(f"⚠️ ROUTING: 'general-purpose' no está en catálogo Helix para dominio [{dominio}]. "
          f"Usar: {sorted(permitidos)}", file=sys.stderr)
    sys.exit(2)

if agent not in permitidos:
    print(f"⚠️ ROUTING MISMATCH: dominio [{dominio}] detectado pero agente='{agent}' no está en "
          f"catálogo permitido {sorted(permitidos)}. Reconsiderar elección o justificar override.",
          file=sys.stderr)
    sys.exit(2)

sys.exit(0)
PYEOF

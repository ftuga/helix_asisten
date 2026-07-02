# Stack Catalogs — Default Mappings

Catálogos de agentes recomendados por *tier* del proyecto y por stack técnico detectado. Consumido por `helix-stack.sh` para generar el manifest inicial.

## Por tier

### `small` (≤10 archivos código, <500 LOC, sin tests/CI)
**core:** stack técnico detectado (lenguaje + framework principal)
**extended (opcional):** —
**rationale:** proyecto pequeño no justifica overhead de roles transversales.

### `medium` (10-100 archivos, 500-10K LOC, o tiene tests/)
**core:** small + DB si aplica
**extended (recomendado):** `code-reviewer`, `security-auditor`
**rationale:** code review pre-cierre + auditoría de seguridad básica son net-positive en este tamaño.

### `large` (100+ archivos, 10K+ LOC, o tiene CI + IaC)
**core:** medium + `database-architect`, `architect-reviewer`
**extended (fuerte recomendación):** `qa-expert`, `business-analyst`, `security-engineer`, `devops-engineer`, `monitoring-specialist`
**rationale:** proyecto grande sin estos roles acumula deuda técnica + de proceso. Sin BA → requirements ambiguos. Sin QA → cobertura ad-hoc. Sin DevOps → infra como afterthought. `security-engineer` (DevSecOps/infra/pipelines) complementa a `security-auditor` (auditoría de código/endpoints) — son dominios distintos.
**opcional con equipo Capa 3 activo:** `project-manager`, `scrum-master` — solo cuando hay coordinación multi-sesión real que gestionar.
> 2026-07-01: `performance-engineer` removido del roster (no existe archivo de agente; si el dominio aparece, crearlo con `agent-create`).

## Por lenguaje/framework detectado

| Detección | Agentes core |
|---|---|
| `python` | `python-pro` |
| `typescript` | `typescript-pro` |
| `javascript` (sin TS) | `frontend-developer` |
| `react` | `frontend-developer` |
| `nextjs` | + `nextjs-architecture-expert` |
| `vue` | `frontend-developer` |
| `fastapi` | + `backend-architect` |
| `django` | + `backend-architect` |
| `flask` | + `backend-architect` |
| `nestjs` | + `nestjs-expert` (skill) |
| `postgres` | + `sql-pro`, `database-architect` (postgres-pro no existe — removido 2026-04-27) |
| `mysql` | + `sql-pro` |
| `docker-compose` (tier ≥ medium) | + `devops-engineer` |
| `kubernetes/k8s` | + `devops-engineer`, `azure-infra-engineer` (si Azure) |

## Por dominio del proyecto

| Patrón | Agentes adicionales |
|---|---|
| ML pipeline (mlflow, airflow) | `mlflow-expert`, `airflow-dag-expert`, `data-analyst` |
| DeFi / blockchain | `rugpull-domain-expert` (si Uniswap V2) |
| SaaS | `fin-saas-advisor`, `app-creative-genius` |
| API pública (≥10 endpoints) | `api-architect`, `api-designer`, `api-documenter` |
| Auth/identity | `security-auditor`, `api-security-audit` |

## Reglas duras (siempre activas independiente del stack)

Estos NO entran al manifest pero se invocan por evento, no por dominio:
- `error-detective` — bug o error inesperado
- `code-reviewer` — pre-cierre obligatorio
- `api-security-audit` — endpoint nuevo o cambio auth
- `architect-reviewer` — decisión arquitectónica significativa

## Notas

- Un agente puede aparecer en múltiples categorías (ej: `security-auditor` está en medium-extended y también en patrón "auth").
- El usuario puede excluir cualquier agente del manifest con `helix-stack remove <agent>` aunque el catálogo lo recomiende.

## Activación por tier (2026-07-01 — fin del "ignorar silencioso")

Los roles transversales viven deshabilitados en `agents-disabled/` (economía de contexto: proyectos small/medium no pagan por QA/BA/security-engineer). El catálogo ya NO los descarta en silencio — tres estados:

| Estado | Qué significa | Qué hace helix-stack |
|---|---|---|
| activo | archivo en `agents/` global o `.claude/agents/` del proyecto | entra al manifest normal |
| **activable** | archivo en `agents-disabled/` | se conserva en la recomendación + WARN con comando `activate` |
| no existe | sin archivo en ninguna parte | se descarta CON warning ("crear con agent-create") |

- `helix-stack.sh activate <agent>` copia el agente al `.claude/agents/` del **proyecto** (scope local — otros proyectos no cargan su contexto). `deactivate` lo quita.
- `add`/`promote` auto-activan si el agente está en `agents-disabled/`.
- Regla dura: en tier `large`, si `pending_activation` no está vacío al cerrar `/helix-analiza`, Helix debe ofrecer la activación — no proceder como si los roles no existieran.

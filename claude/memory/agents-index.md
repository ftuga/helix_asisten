# Índice de Agentes — Carga Lazy
> Solo este índice se carga al inicio. Descripción completa en `~/.claude/memory/agents/<nombre>.md`.
> Actualizar cuando se habilita/deshabilita un agente.

## Agentes Activos

| Agente | Trigger |
|---|---|
| `python-pro` | Endpoint FastAPI, refactor, async |
| `typescript-pro` | Tipos TS complejos, generics |
| `frontend-developer` | Componente React, página nueva |
| `backend-architect` | Diseño de API, estructura de servicio |
| `database-architect` | Cambio de modelo o esquema |
| `postgresql-dba` | Query PostgreSQL, índices, plan de ejecución |
| `sql-pro` | Query lenta, window functions, optimización SQL |
| `error-detective` | Bug o error inesperado — SIEMPRE PRIMERO |
| `code-reviewer` | Pre-cierre — OBLIGATORIO antes de declarar completa |
| `security-auditor` | Auditoría de seguridad, compliance |
| `api-security-audit` | Endpoint nuevo, cambio auth |
| `devops-engineer` | Docker, CI/CD, infra (no frontend-developer) |
| `deployment-engineer` | Deploy, rollback, zero-downtime |
| `data-analyst` | Análisis de reportes, métricas |
| `test-engineer` | Tests, pytest, cobertura (no researcher) |
| `test-automator` | Implementación tests automatizados CI |
| `monitoring-specialist` | Logs, alertas, observabilidad |
| `architect-reviewer` | Decisión arquitectónica, SOLID |
| `investment-expert` | Bolsa, cripto, trading, portafolio |
| `mlflow-expert` | MLflow 2.x: runs, registry, artifacts S3/MinIO, reproducibilidad |
| `airflow-dag-expert` | Airflow 2.x CeleryExecutor: DAGs, TaskFlow, pools, connections |
| `rugpull-domain-expert` | DeFi forense Uniswap V2: SYNC/MINT/BURN, features rug pull |
| `harness-optimizer` | Auditar/modificar harness Helix: hooks, CLAUDE.md, scripts core de ~/.claude/. NO toca código de producto |
| `app-creative-genius` | Visionario producto/UX. Ideas bold para features, flujos, modelo de negocio, diferenciación |
| `brand-identity-expert` | Brand naming, identity, taglines, go-to-market, Google/Meta Ads |
| `loop-operator` | Operación de loops autónomos con safeguards: detecta stalls, retries, presupuesto |
| `linguista-computacional-tokens` | Auditar/diseñar protocolos inter-agente para reducir costo de tokens preservando contexto. tiktoken + cross-lingual. NO aplica a código/SQL/shell |

## Deshabilitados (no invocar)
`api-architect` · `api-designer` · `api-documenter` · `azure-infra-engineer` · `backend-developer` · `business-analyst` · `fullstack-developer` · `mcp-security-auditor` · `metadata-agent` · `nextjs-architecture-expert` · `product-manager` · `project-manager` · `qa-expert` · `scrum-master` · `security-engineer`

## Removidos del índice 2026-04-27 (no tenían archivo en `~/.claude/agents/`)
> Context files preservados en `~/.claude/memory/agents/` por si se restauran.
`postgres-pro` (HA enterprise) · `performance-engineer` (profiling) · `prompt-engineer` (audit system prompts) · `codebase-explorer` · `context-manager` · `task-decomposition-expert` · `research-coordinator` · `ui-designer` · `ui-ux-designer` · `fin-saas-advisor` · `mme-domain-expert` (project-local ent-tesis)

Para restaurar: instalar archivo con `helix-agent-manager` o crear con skill `agent-create`, luego mover de "Removidos" a "Activos".

## Notas ERL+ExpeL
- `researcher` y `general-purpose` son tipos internos de Claude Code, no agentes Helix. Para research → `backend-architect` o `general-purpose` según dominio.
- `postgresql-dba` cubre dominio Postgres mientras no exista `postgres-pro`.

## Agentes de dominio MLOps/DeFi (2026-04-19)
Promovidos desde `ent-tesis` — útiles para cualquier proyecto con Airflow + MLflow + MinIO o
analítica on-chain de Uniswap V2. Contexto completo en `memory/agents/<nombre>.md`.
- `mlflow-expert` — tracking + registry + artifacts
- `airflow-dag-expert` — DAGs idempotentes + CeleryExecutor
- `rugpull-domain-expert` — criterio de dominio DeFi (específico pero reutilizable)

> Última corrección: 2026-04-27 (drift cleanup: 11 entries huérfanos removidos, 3 archivos agregados, architect-review→architect-reviewer renombrado)

> Última corrección ERL+ExpeL: 2026-05-08
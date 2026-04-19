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
| `postgres-pro` | PostgreSQL HA, replicación, backup enterprise |
| `postgresql-dba` | Query PostgreSQL específica (legacy → migrar a postgres-pro) |
| `sql-pro` | Query lenta, window functions, plan de ejecución |
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
| `performance-engineer` | Bottleneck, profiling, load testing |
| `prompt-engineer` | Diseñar o auditar system prompt |
| `codebase-explorer` | Explorar codebase sin leer archivos |
| `context-manager` | Gestión contexto sesiones largas |
| `task-decomposition-expert` | Descomponer tarea compleja |
| `research-coordinator` | Investigación multi-agente |
| `ui-designer` | Componente visual, dirección estética |
| `ui-ux-designer` | Flujos, arquitectura info, UX |
| `fin-saas-advisor` | Precios, márgenes, modelo SaaS |
| `investment-expert` | Bolsa, cripto, trading, portafolio |

## Deshabilitados (no invocar)
`api-architect` · `api-designer` · `api-documenter` · `azure-infra-engineer` · `backend-developer` · `business-analyst` · `fullstack-developer` · `mcp-security-auditor` · `metadata-agent` · `nextjs-architecture-expert` · `product-manager` · `project-manager` · `qa-expert` · `scrum-master` · `security-engineer`

## Notas ERL+ExpeL
- `researcher` y `general-purpose` son tipos internos de Claude Code, no agentes Helix. Para research → `research-coordinator` o `backend-architect` según dominio.
- `postgresql-dba` → migrar a `postgres-pro`. Mantener temporalmente por compatibilidad.

> Última corrección: 2026-04-18

> Última corrección ERL+ExpeL: 2026-04-18
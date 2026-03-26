# Índice de Agentes — Carga Lazy
> Solo este índice se carga al inicio. Descripción completa en `~/.claude/memory/agents/<nombre>.md`.
> Actualizar cuando se habilita/deshabilita un agente.

## Agentes Activos (19)

| Agente | Trigger (5 palabras) | Detalle |
|---|---|---|
| `python-pro` | Nuevo endpoint FastAPI o refactor | [detalle](agents/python-pro.md) |
| `typescript-pro` | Tipos TS complejos o generics | [detalle](agents/typescript-pro.md) |
| `frontend-developer` | Componente React o página nueva | [detalle](agents/frontend-developer.md) |
| `backend-architect` | Diseño de API o estructura | [detalle](agents/backend-architect.md) |
| `database-architect` | Cambio de modelo o esquema | [detalle](agents/database-architect.md) |
| `postgresql-dba` | Optimizar query PostgreSQL específica | [detalle](agents/postgresql-dba.md) |
| `sql-pro` | Query lenta o window functions | [detalle](agents/sql-pro.md) |
| `error-detective` | Bug o error inesperado SIEMPRE | [detalle](agents/error-detective.md) |
| `code-reviewer` | Pre-cierre de tarea OBLIGATORIO | [detalle](agents/code-reviewer.md) |
| `security-auditor` | Auditoría de seguridad o compliance | [detalle](agents/security-auditor.md) |
| `api-security-audit` | Endpoint nuevo o cambio auth | [detalle](agents/api-security-audit.md) |
| `devops-engineer` | Docker, CI/CD o infra | [detalle](agents/devops-engineer.md) |
| `deployment-engineer` | Deploy, rollback o zero-downtime | [detalle](agents/deployment-engineer.md) |
| `data-analyst` | Análisis de reportes o métricas | [detalle](agents/data-analyst.md) |
| `test-engineer` | Estrategia de testing o cobertura | [detalle](agents/test-engineer.md) |
| `test-automator` | Implementar tests automatizados CI | [detalle](agents/test-automator.md) |
| `monitoring-specialist` | Logs, alertas o observabilidad | [detalle](agents/monitoring-specialist.md) |
| `architect-reviewer` | Decisión arquitectónica o SOLID | [detalle](agents/architect-reviewer.md) |
| `fin-saas-advisor` | Precios, márgenes o modelo SaaS | [detalle](agents/fin-saas-advisor.md) |

## Deshabilitados (17)
`api-architect` `api-designer` `api-documenter` `azure-infra-engineer`
`backend-developer` `business-analyst` `fullstack-developer` `mcp-security-auditor`
`metadata-agent` `nextjs-architecture-expert` `product-manager` `project-manager`
`qa-expert` `scrum-master` `security-engineer` `ui-designer` `ui-ux-designer`

## Agentes Nuevos (2026-03-26)

| Agente | Trigger (5 palabras) | Detalle |
|---|---|---|
| `postgres-pro` | PostgreSQL HA, replicación, backup enterprise | [detalle](agents/postgres-pro.md) |
| `codebase-explorer` | Explorar codebase sin leer archivos | [detalle](agents/codebase-explorer.md) |
| `context-manager` | Gestión de contexto sesiones largas | [detalle](agents/context-manager.md) |
| `performance-engineer` | Bottleneck, profiling, load testing | [detalle](agents/performance-engineer.md) |
| `task-decomposition-expert` | Descomponer tarea compleja en subtareas | [detalle](agents/task-decomposition-expert.md) |
| `research-coordinator` | Investigación multi-agente coordinada | [detalle](agents/research-coordinator.md) |

> `postgresql-dba` → migrar a `postgres-pro` (más completo). Mantener temporalmente por compatibilidad.

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
| `sql-pro` | Query lenta, window functions, índices, plan de ejecución, optimización SQL (cubre PostgreSQL) |
| `error-detective` | Bug o error inesperado — SIEMPRE PRIMERO |
| `code-reviewer` | Pre-cierre — OBLIGATORIO antes de declarar completa |
| `security-auditor` | Auditoría de seguridad, compliance |
| `api-security-audit` | Endpoint nuevo, cambio auth |
| `devops-engineer` | Docker, CI/CD, infra (no frontend-developer) |
| `deployment-engineer` | Deploy, rollback, zero-downtime |
| `data-analyst` | Análisis de reportes, métricas |
| `test-automator` | Tests: estrategia, pytest, cobertura, suites automatizadas, CI (absorbe a test-engineer 2026-07-01) |
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
| `n8n-workflow-expert` | Editar/depurar workflows n8n (JSON): nodos, expresiones `{{ }}`, Code node JS, sub-workflows. Preserva estructura importable. NO administra la instancia n8n |
| `conversational-comms-expert` | Redactar/revisar mensajes del bot WhatsApp con tono cálido, cortés, humano y tolerante. Pragmática + cortesía + NVC + tono UX. NO implementa lógica del workflow |
| `bot-architecture-expert` | Estructura del bot WhatsApp: flujos/subflujos modulares (extender sin romper), dialog management (no-linealidad, reparación, slots, contexto), componentes Meta (botones/listas/Flows). Diseño, NO implementación |

## Ecosistema UI (pipeline frontend — indexados 2026-07-01)

| Agente | Trigger |
|---|---|
| `ux-researcher` | Petición UI vaga/funcional → requerimientos UX (flujos, edge cases, criterios) ANTES de diseñar/codificar |
| `design-bridge` | Referencia visual (URL, screenshot, Figma, "como X") → brief de implementación para ui-architect |
| `ui-architect` | Construir/estructurar componentes React 19/Next 15: composición, types, tokens Tailwind 4 |
| `ui-designer` | Sistema de diseño completo, mockups, especificación visual (no código) |
| `tokens-manager` | Design tokens, dark mode/multi-theme, migración Tailwind 3→4, variables shadcn/ui |
| `motion-designer` | Animaciones/transiciones: Framer Motion, View Transitions, prefers-reduced-motion |
| `a11y-expert` | Accesibilidad profunda: ARIA, focus management, WCAG 2.2, componentes interactivos complejos |
| `performance-ui` | Core Web Vitals, bundle size, lazy loading, virtualización, re-renders |
| `ui-tester` | SIEMPRE tras ui-architect: breakpoints, estados, teclado, edge cases, regresión visual |
| `ui-debugger` | Bug UI con causa no obvia (tras ui-tester) → root cause y dirección de fix |
| `refactoring-specialist` | Componente/hook crecido: split, extraer hooks, CVA, sin cambiar comportamiento |
| `code-reviewer-frontend` | Review pre-merge frontend: TS, patrones React, seguridad forms, a11y básica |

## Roles del Council (NUNCA invocar fuera de un council)
`council-arbiter` · `council-researcher` · `council-skeptic` · `council-innovator` · `council-conservative` · `council-synthesizer` · `council-devils-advocate`
> Orquestados exclusivamente por `helix-council.sh` / skill `helix-council`.

## Deshabilitados (no invocar)
> Materializado 2026-07-01: los archivos viven en `~/.helix/agents-disabled/` (FUERA de `agents/` — Claude Code carga subdirectorios recursivamente, por lo que `agents/disabled/` NO deshabilitaba nada).
`api-architect` · `api-designer` · `api-documenter` · `azure-infra-engineer` · `backend-developer` · `business-analyst` · `fullstack-developer` · `mcp-security-auditor` · `metadata-agent` · `nextjs-architecture-expert` · `product-manager` · `project-manager` · `qa-expert` · `scrum-master` · `security-engineer` · `ui-ux-designer` · `postgresql-dba` (tools VS Code inexistentes en CLI; cubre sql-pro) · `test-engineer` (fusionado en test-automator) · `architect-review` (duplicado exacto de architect-reviewer)

## Removidos del índice 2026-04-27 (no tenían archivo en `~/.claude/agents/`)
> Context files preservados en `~/.claude/memory/agents/` por si se restauran.
> 2026-07-01: `ui-designer` restaurado (el archivo sí existe — está indexado arriba en Ecosistema UI).
`postgres-pro` (HA enterprise) · `performance-engineer` (profiling) · `prompt-engineer` (audit system prompts) · `codebase-explorer` · `context-manager` · `task-decomposition-expert` · `research-coordinator` · `ui-ux-designer` · `fin-saas-advisor` · `mme-domain-expert` (project-local ent-tesis)

Para restaurar: instalar archivo con `helix-agent-manager` o crear con skill `agent-create`, luego mover de "Removidos" a "Activos".

## Notas ERL+ExpeL
- `researcher` y `general-purpose` son tipos internos de Claude Code, no agentes Helix. Para research → `backend-architect` o `general-purpose` según dominio.
- Dominio Postgres → `sql-pro` (queries/tuning) o `database-architect` (diseño/esquema). `postgresql-dba` deshabilitado 2026-07-01.
- Drift índice↔disco: `bash ~/.helix/helpers/helix-agents-audit.sh` (corregido 2026-07-01 — antes auditaba `~/.claude/` hardcodeado y siempre reportaba limpio).

## Agentes de dominio MLOps/DeFi (2026-04-19)
Promovidos desde `ent-tesis` — útiles para cualquier proyecto con Airflow + MLflow + MinIO o
analítica on-chain de Uniswap V2. Contexto completo en `memory/agents/<nombre>.md`.
- `mlflow-expert` — tracking + registry + artifacts
- `airflow-dag-expert` — DAGs idempotentes + CeleryExecutor
- `rugpull-domain-expert` — criterio de dominio DeFi (específico pero reutilizable)

> Última corrección: 2026-04-27 (drift cleanup: 11 entries huérfanos removidos, 3 archivos agregados, architect-review→architect-reviewer renombrado)

> Última corrección ERL+ExpeL: 2026-07-26
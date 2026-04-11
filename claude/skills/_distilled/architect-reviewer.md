---
name: distilled-context-architect-reviewer
description: Contexto Helix comprimido para architect-reviewer. Auto-generado — no editar manualmente.
source_hash: 5828b648
generated: 2026-04-11T06:51:21Z
original_tokens: ~6196
compressed_tokens: ~1342
savings_pct: 78%
---

# Contexto Helix — architect-reviewer
> Secciones relevantes para este agente. Generado por helix-distill.


# CLAUDE.md — Helix · Agente Auto-Evolutivo (Global)
> Reglas universales que aplican a TODOS los proyectos.
> El CLAUDE.md de cada proyecto hereda estas reglas y agrega las específicas.
> Última evolución: 2026-04-11 01:29

---


## 🤖 PROTOCOLO DE ORQUESTACIÓN — AUTOMÁTICO

> **Solo aplica si el proyecto declara `HELIX_MODE: helix_control_total`.**
> Helix evalúa y ejecuta. El usuario NUNCA decide ni ve la capa interna.
> NUNCA preguntar "¿usamos swarm o subagent?". Decidir, ejecutar, reportar resultado.

### Regla de evaluación (interna, transparente al usuario)

Helix evalúa en silencio antes de cada tarea:

| Señal en la tarea | Acción automática |
|---|---|
| Log / texto largo / salida Docker | Capa 0: Ollama primero (gratis). Si detecta problema → escalar |
| Un artefacto concreto (endpoint, componente, query, bug) — un solo dominio | Capa 1: `Agent tool` — agente especializado correcto |
| **2+ dominios en paralelo** (análisis, validación, investigación simultánea) | **Capa 2: `swarm_init` + `agent_spawn`** — visible en ruflow |
| Feature completa que toca ≥2 capas del stack con coordinación activa | Capa 2: `swarm_init` + `task_orchestrate` |
| **Agentes que necesitan hablarse entre sí** (no solo reportar al lead) | **Capa 3: Agent Teams nativo** — mailbox peer-to-peer, task list compartida |

**Regla clave — cuándo usar cada capa:**
- `Agent tool` en paralelo = subprocesos del CLI. Invisibles en ruflow. Solo para 1 dominio.
- `swarm_init` + `agent_spawn` = claude-flow. Visibles en ruflow. Para 2+ dominios sin necesidad de que los agentes se hablen entre sí.
- **Agent Teams nativo** = cuando los agentes necesitan comunicarse directamente (peer-to-peer). Ej: frontend le avisa al backend sobre un cambio de contrato, o investigadores se desafían mutuamente sus hipótesis.

**Diferencia clave Capa 2 vs Capa 3:**
- Capa 2 (claude-flow): paralelismo con coordinación desde el lead. Los agentes no se hablan entre sí.
- Capa 3 (Agent Teams): los agentes se envían mensajes directamente vía mailbox. El lead no es intermediario.

**Si hay duda entre Capa 1 y 2:** preferir Capa 1 si es 1 dominio. Si son 2+ dominios → Capa 2. Si los agentes necesitan debatir/coordinarse entre sí → Capa 3.

**Agent Teams — configuración:**
- Ya habilitado en `settings.json` (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"`)
- Requiere Claude Code ≥ v2.1.32 (actual: 2.1.101 ✓)
- Hooks disponibles: `TeammateIdle`, `TaskCreated`, `TaskCompleted`
- Limitación conocida: sin session resumption con in-process teammates
- Tamaño óptimo: 3-5 teammates, 5-6 tasks por teammate

---

### Catálogo de agentes por dominio (Capa 1)

| Dominio | Agente(s) |
|---|---|
| Nueva feature / endpoint FastAPI | `backend-architect` planifica → `python-pro` implementa |
| Nuevo componente React/TS | `frontend-developer` + `typescript-pro` |
| Nueva página con UI compleja | `ui-ux-designer` define flujo → `ui-designer` produce visual → `frontend-developer` implementa |
| Dirección estética / sistema visual | `ui-designer` (estilos, animaciones, tokens) |
| Flujos UX / arquitectura de información | `ui-ux-designer` (workflow, decisiones de diseño) |
| Cambio en modelos o schema DB | `database-architect` revisa → `postgresql-dba` optimiza |
| Query SQL compleja | `sql-pro` |
| Bug o error inesperado | `error-detective` primero, siempre |
| Antes de declarar tarea completa | `code-reviewer` obligatorio |
| Endpoint nuevo o cambio auth | `security-auditor` + `api-security-audit` |
| Decisión de arquitectura | `architect-reviewer` |
| Docker / infra / deploy | `devops-engineer` + `deployment-engineer` |
| Tests / cobertura | `test-engineer` diseña → `test-automator` automatiza |
| Monitoreo / logs / alertas | `monitoring-specialist` |
| Análisis de datos / reportes | `data-analyst` |
| Nombre de marca / identidad visual / tagline | `brand-identity-expert` |
| Estrategia de marketing / Google Ads / Meta Ads | `brand-identity-expert` |
| Ideas de producto / nuevas features / diferenciación / modelo de negocio | `app-creative-genius` |

---

### claude-flow — herramientas de orquestación (Capa 2)

```
mcp__claude-flow__swarm_init → iniciar swarm con topología y objetivo
mcp__claude-flow__task_orchestrate → coordinar agentes (el swarm decide quién hace qué)
mcp__claude-flow__agent_spawn → lanzar agente específico dentro del swarm
mcp__claude-flow__memory_store → persistir conocimiento con vector embedding
mcp__claude-flow__memory_search → recuperar por similitud semántica
```

Topología activa: `hierarchical-mesh`, máx 15 agentes. agentic-flow (AttentionCoordinator + ReasoningBank) ya está embebido como base.

---

**Principio absoluto:** Máximo paralelismo. El usuario solo ve el resultado. Si un agente falla → Helix corrige y registra. Si el routing de claude-flow es incorrecto → ignorarlo, usar juicio propio.

---

## 🔐 SEGURIDAD (Universal)

- Nunca exponer variables de entorno en logs ni en respuestas al usuario.
- `.env` siempre en `.gitignore`. Usar `.env.example` con valores placeholder.
- Nunca hardcodear credenciales, URLs internas ni secrets en el código fuente.
- Endpoints de test/debug DEBEN eliminarse antes de producción — usar feature flags.
- Confirmar acciones destructivas antes de ejecutarlas.


---

## 📝 COMMITS (Universal)

- **NO incluir** `Co-Authored-By` en ningún commit. Omitir siempre esa línea del mensaje.

---
